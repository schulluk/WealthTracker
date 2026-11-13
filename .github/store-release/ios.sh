#!/usr/bin/env bash
# The iOS release, one command per step. The release-ios workflow runs these
# on a runner; release.sh --local runs the same ones on a Mac.
#
#   ios.sh prepare            build number, App Store Connect key, signing identity
#   ios.sh archive            dependencies, pre-build command, the archive
#   ios.sh export             App Store profiles, signed IPA, entitlement repair
#   ios.sh upload             TestFlight (pilot) or the App Store version (deliver)
#   ios.sh testflight-notes   What to Test, once Apple lists the build
#   ios.sh appstore-notes     What's New, the review contact, released when approved
#   ios.sh submit             send the App Store version to review (waits for processing)
#   ios.sh summary            the result, as a table
#   ios.sh cleanup            keychain and key files gone
#
# Configuration: store.yml (ios section). Run: VERSION, TRACK (appstore |
# testflight), NOTES, DRY_RUN, BUILD_NUMBER (set by prepare, or given).
# Credentials: APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_ISSUER_ID and
# APP_STORE_CONNECT_API_KEY_P8_B64 (or ASC_KEY_PATH); on a runner also
# APPLE_DISTRIBUTION_P12_B64 / _PASSWORD, which go into a throwaway keychain.
# On a Mac the Apple Distribution identity is taken from the login keychain.
#
# Deliberate choices, each one a release that stopped once:
#   * `flutter build ipa --no-codesign` plus `xcodebuild -exportArchive` signs
#     with the bare minimum entitlements and silently drops aps-environment and
#     associated-domains, which kills push notifications. export compares the
#     IPA's entitlements with the project's, re-signs only what is missing, and
#     verifies the result.
#   * automatic signing with an App Manager key fails on cloud signing, so the
#     export signs manually with profiles from sigh.
#   * the upload never waits for Apple's processing: on a runner that wait is
#     billed macOS minutes. The notes steps do it, on Linux.
#   * every version is released as soon as Apple approves it. appstore-notes
#     sets that, because deliver applies automatic_release only in a call that
#     also uploads metadata; next to --skip_metadata it is silently ignored.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sr_config
[ "$SR_IOS" = true ] || sr_die "store.yml has no ios section."
VERSION="${VERSION:?VERSION is not set}"
TRACK="${TRACK:-appstore}"
DRY_RUN="${DRY_RUN:-false}"
# No "/./" in the paths: actions/upload-artifact refuses them.
APP_DIR="$SR_ROOT"
[ "$SR_APP_DIR" = . ] || APP_DIR="$SR_ROOT/$SR_APP_DIR"
# prepare sets IOS_BUILD_NUMBER; a given BUILD_NUMBER overrides the scheme.
BUILD_NUMBER="${IOS_BUILD_NUMBER:-${BUILD_NUMBER:-}}"

keychain_args() { # codesign/export use the run's keychain on a runner, the login keychain on a Mac
  if sr_ci; then
    security unlock-keychain -p "$SR_KEYCHAIN_PASSWORD" "$SR_KEYCHAIN"
    printf '%s\n' --keychain "$SR_KEYCHAIN"
  fi
}

cmd_prepare() {
  local missing=""
  [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] || missing="$missing APP_STORE_CONNECT_API_KEY_ID"
  [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ] || missing="$missing APP_STORE_CONNECT_ISSUER_ID"
  [ -n "${APP_STORE_CONNECT_API_KEY_P8_B64:-}${ASC_KEY_PATH:-}" ] || missing="$missing APP_STORE_CONNECT_API_KEY_P8_B64"
  if sr_ci; then
    [ -n "${APPLE_DISTRIBUTION_P12_B64:-}" ] || missing="$missing APPLE_DISTRIBUTION_P12_B64"
  fi
  # The export needs the key even for a dry run: Apple issues the profile then.
  [ -z "$missing" ] || sr_die "Missing:$missing. The store-release skill sets them: skills/store-release/references/secrets.md"

  local number
  number=$(sr_build_number "$SR_IOS_BUILD_NUMBER" "${BUILD_NUMBER:-}")
  sr_out build_number "$number"
  sr_env IOS_BUILD_NUMBER "$number"
  BUILD_NUMBER="$number"
  echo "::notice title=iOS::$VERSION ($number)"

  sr_asc_key

  local identity
  if sr_ci; then
    local keychain="$RUNNER_TEMP/build.keychain-db" password cert="$RUNNER_TEMP/cert.p12"
    password=$(openssl rand -hex 16)
    security create-keychain -p "$password" "$keychain"
    security set-keychain-settings -lut 21600 "$keychain"
    security unlock-keychain -p "$password" "$keychain"
    ( umask 077; printf '%s' "$APPLE_DISTRIBUTION_P12_B64" | base64 --decode > "$cert" )
    security import "$cert" -k "$keychain" -P "${APPLE_DISTRIBUTION_P12_PASSWORD:-}" \
      -T /usr/bin/codesign -T /usr/bin/security
    rm -f "$cert"
    security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" > /dev/null
    # Ours first, then the ones that were there (one word each, on purpose).
    # shellcheck disable=SC2046
    security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
    sr_env SR_KEYCHAIN "$keychain"
    sr_env SR_KEYCHAIN_PASSWORD "$password"
    identity=$(security find-identity -v -p codesigning "$keychain" \
      | grep -m1 "Apple Distribution" | sed -E 's/.*"([^"]+)".*/\1/' || true)
    [ -n "$identity" ] || sr_die "No Apple Distribution identity in the keychain. APPLE_DISTRIBUTION_P12_B64 is not a distribution certificate with its private key, or APPLE_DISTRIBUTION_P12_PASSWORD is wrong."
  else
    identity=$(security find-identity -v -p codesigning \
      | grep "Apple Distribution" | grep -m1 "($SR_IOS_TEAM_ID)" | sed -E 's/.*"([^"]+)".*/\1/' || true)
    [ -n "$identity" ] || sr_die "No Apple Distribution identity for team $SR_IOS_TEAM_ID in this Mac's keychain. Install the distribution certificate with its private key (the .p12 the CI secret came from)."
  fi
  sr_env SIGN_IDENTITY "$identity"
  echo "::notice::Signing as $identity"
}

cmd_archive() {
  cd "$APP_DIR"
  if [ "$SR_IOS_STACK" = flutter ]; then
    flutter pub get
  fi
  if [ -n "$SR_IOS_PRE_BUILD_COMMAND" ]; then
    bash -c "$SR_IOS_PRE_BUILD_COMMAND"
  fi
  sr_dart_defines
  # A build_command gets these, and passes DART_DEFINES_ARG on itself.
  export VERSION BUILD_NUMBER TRACK SIGN_IDENTITY DART_DEFINES_ARG
  local rc=0
  if [ -n "$SR_IOS_BUILD_COMMAND" ]; then
    sr_heavy bash -c "$SR_IOS_BUILD_COMMAND" || rc=$?
  else
    # Unsigned, then exported with distribution signing: archiving signed
    # needs a development certificate a runner does not have.
    # shellcheck disable=SC2086
    sr_heavy flutter build ipa --no-codesign \
      --build-name="$VERSION" --build-number="$BUILD_NUMBER" $SR_IOS_EXTRA_BUILD_ARGS $DART_DEFINES_ARG || rc=$?
  fi
  rm -f "$RUNNER_TEMP/dart-defines.json"
  [ "$rc" -eq 0 ] || exit "$rc"
  [ -d "$SR_IOS_ARCHIVE_PATH" ] || sr_die "No archive at $SR_IOS_ARCHIVE_PATH (store.yml ios.archive_path)."
}

cmd_export() {
  cd "$APP_DIR"
  local archive="$SR_IOS_ARCHIVE_PATH" app ids ext out="$RUNNER_TEMP/profiles" id uuid
  app="$archive/Products/Applications/$SR_IOS_APP_NAME"
  [ -d "$app" ] || sr_die "No $SR_IOS_APP_NAME in $archive (store.yml ios.archive_path / ios.app_name)."

  # Profiles. sigh finds or creates an App Store profile for the app and
  # every extension in the archive, for the distribution certificate.
  ids=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
  for ext in "$app"/PlugIns/*.appex; do
    [ -d "$ext" ] || continue
    ids="$ids $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ext/Info.plist")"
  done
  mkdir -p "$out" "$HOME/Library/MobileDevice/Provisioning Profiles" \
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  : > "$out/map.tsv"
  for id in $ids; do
    fastlane sigh \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$id" \
      --platform ios \
      --output_path "$out" \
      --filename "$id.mobileprovision" \
      --skip_install true
    security cms -D -i "$out/$id.mobileprovision" > "$out/$id.plist"
    uuid=$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$out/$id.plist")
    cp "$out/$id.mobileprovision" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
    cp "$out/$id.mobileprovision" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$uuid.mobileprovision"
    printf '%s\t%s\n' "$id" "$uuid" >> "$out/map.tsv"
    echo "::notice::App Store profile for $id: $(/usr/libexec/PlistBuddy -c 'Print :Name' "$out/$id.plist")"
  done

  # Export, signing manually with those profiles: no cloud signing, no Admin key.
  python3 - "$out/map.tsv" "$SR_IOS_TEAM_ID" "$SIGN_IDENTITY" "$RUNNER_TEMP/ExportOptions.plist" <<'PY'
import plistlib, sys
map_path, team, identity, out = sys.argv[1:]
with open(map_path) as f:
    profiles = dict(line.rstrip("\n").split("\t") for line in f if line.strip())
with open(out, "wb") as f:
    plistlib.dump({
        "method": "app-store-connect",
        "signingStyle": "manual",
        "teamID": team,
        "signingCertificate": identity,
        "provisioningProfiles": profiles,
    }, f)
PY
  rm -rf "$RUNNER_TEMP/ipa"
  xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportPath "$RUNNER_TEMP/ipa" \
    -exportOptionsPlist "$RUNNER_TEMP/ExportOptions.plist"
  local ipa
  ipa=$(find "$RUNNER_TEMP/ipa" -name '*.ipa' -print -quit)
  [ -n "$ipa" ] || sr_die "The export produced no IPA."
  sr_env IPA_PATH "$ipa"
  sr_out ipa "$ipa"

  repair_entitlements "$ipa"
}

# Which keys does the project declare that a signed bundle lacks?
# aps-environment (push) and associated-domains (universal links, password
# autofill) are the ones the unsigned-archive route drops, and nothing fails
# until a user notices push is dead; an app group missing from a widget
# extension is a widget that shows nothing. Extensions are re-signed inside
# out, never with --deep, which would give them the app's entitlements.
repair_entitlements() {
  local ipa="$1" work="$RUNNER_TEMP/ipa-work" app
  [ -n "$SR_IOS_ENTITLEMENTS$SR_IOS_EXTENSION_ENTITLEMENTS" ] || return 0
  rm -rf "$work" && mkdir -p "$work"
  unzip -q "$ipa" -d "$work"
  app="$work/Payload/$SR_IOS_APP_NAME"
  [ -d "$app" ] || sr_die "No $SR_IOS_APP_NAME in the IPA payload (store.yml ios.app_name)."

  # A merged file keeps everything the export put there (application-identifier,
  # team-identifier, beta-reports-active). Writes the bundles to re-sign,
  # inside out, to plan.tsv.
  python3 - "$work" "$app" "$SR_IOS_ENTITLEMENTS" "$SR_IOS_EXTENSION_ENTITLEMENTS" <<'PY'
import os, plistlib, subprocess, sys
work, app, app_source, extensions = sys.argv[1:]

def signed(bundle, out):
    subprocess.run(["codesign", "-d", "--entitlements", ":" + out, bundle],
                   check=True, capture_output=True)
    if not os.path.exists(out) or os.path.getsize(out) == 0:
        return {}
    with open(out, "rb") as f:
        return plistlib.load(f)

bundles = []
for raw in extensions.splitlines():
    line = raw.split("#", 1)[0].strip()
    if not line:
        continue
    name, _, source = (part.strip() for part in line.partition("="))
    path = os.path.join(app, "PlugIns", name)
    if not os.path.isdir(path):
        sys.exit(f"::error::ios.extension_entitlements names {name}, but the app has no PlugIns/{name}.")
    if not os.path.isfile(source):
        sys.exit(f"::error::ios.extension_entitlements points {name} at {source}, which does not exist.")
    bundles.append((name, path, source))
if app_source:
    if os.path.isfile(app_source):
        bundles.append((os.path.basename(app), app, app_source))
    else:
        print(f"::notice::No {app_source} in this project, so the app's own entitlements are not compared.")

plan = []
for i, (name, path, source) in enumerate(bundles):
    with open(source, "rb") as f:
        wanted = plistlib.load(f)
    merged = signed(path, os.path.join(work, f"current-{i}.plist"))
    missing = [k for k in wanted if k not in merged]
    if not missing:
        continue
    for key in missing:
        merged[key] = wanted[key]
    merged_path = os.path.join(work, f"merged-{i}.plist")
    with open(merged_path, "wb") as f:
        plistlib.dump(merged, f)
    plan.append("\t".join([path, merged_path, name, " ".join(missing)]))
with open(os.path.join(work, "plan.tsv"), "w") as f:
    f.write("".join(line + "\n" for line in plan))
PY

  if [ ! -s "$work/plan.tsv" ]; then
    echo "::notice::The exported IPA carries every entitlement the project declares; no re-signing needed."
    rm -rf "$work"
    return 0
  fi

  local kc=() bundle merged name missing app_signed=false
  while IFS= read -r line; do kc+=("$line"); done < <(keychain_args)
  sign() { # BUNDLE ENTITLEMENTS. Never --deep.
    codesign --force ${kc[@]+"${kc[@]}"} --sign "$SIGN_IDENTITY" --entitlements "$2" "$1"
  }
  while IFS=$'\t' read -r bundle merged name missing; do
    echo "::warning::The export dropped from $name: $missing. Re-signing it with them."
    sign "$bundle" "$merged"
    [ "$bundle" = "$app" ] && app_signed=true
  done < "$work/plan.tsv"
  if [ "$app_signed" = false ]; then
    # A re-signed extension changes the app's sealed contents, so the app is
    # signed again too, with exactly the entitlements it had.
    codesign -d --entitlements :"$work/app-unchanged.plist" "$app" 2> /dev/null
    sign "$app" "$work/app-unchanged.plist"
  fi
  codesign --verify --deep --strict "$app"

  # Verify, because a re-sign that silently drops something is exactly the
  # failure this exists to prevent.
  python3 - "$work" <<'PY'
import os, plistlib, subprocess, sys
work = sys.argv[1]
still = []
with open(os.path.join(work, "plan.tsv")) as f:
    rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
for i, (bundle, merged_path, name, _) in enumerate(rows):
    out = os.path.join(work, f"after-{i}.plist")
    subprocess.run(["codesign", "-d", "--entitlements", ":" + out, bundle],
                   check=True, capture_output=True)
    with open(merged_path, "rb") as f:
        wanted = plistlib.load(f)
    with open(out, "rb") as f:
        have = plistlib.load(f)
    missing = [k for k in wanted if k not in have]
    if missing:
        still.append(f"{name}: {' '.join(missing)}")
if still:
    sys.exit("::error::The re-signed IPA is still missing " + "; ".join(still))
PY
  rm -f "$ipa"
  (cd "$work" && zip -qry "$ipa" Payload)
  rm -rf "$work"
  echo "::notice::Re-signed and verified."
}

cmd_upload() {
  local log="$RUNNER_TEMP/asc-upload.log" rc
  : "${IPA_PATH:?IPA_PATH is not set: run ios.sh export first}"
  if [ "$DRY_RUN" = true ]; then
    echo "::notice::Dry run: archived, signed and exported $IPA_PATH, uploaded nothing."
    sr_out review dry-run
    return 0
  fi
  set +e
  if [ "$TRACK" = testflight ]; then
    # pilot appends the build and touches no App Store version, so it works
    # while an earlier version is in review. No --changelog and no waiting:
    # with either, pilot sits there until Apple has processed the build.
    fastlane pilot upload \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$SR_IOS_BUNDLE_ID" \
      --ipa "$IPA_PATH" \
      --skip_waiting_for_build_processing true 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
  else
    # deliver creates the App Store version. reject_if_possible withdraws a
    # submission that is only queued; one Apple has already started cannot be
    # undone, which preflight catches beforehand.
    fastlane deliver \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$SR_IOS_BUNDLE_ID" \
      --ipa "$IPA_PATH" \
      --skip_screenshots true \
      --skip_metadata true \
      --submit_for_review false \
      --reject_if_possible true \
      --precheck_include_in_app_purchases false \
      --run_precheck_before_submit false \
      --force true 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
  fi
  set -e
  if [ "$rc" -ne 0 ]; then
    sr_explain ios "$log"
    exit "$rc"
  fi
  sr_out review uploaded
}

# What to Test can be set once Apple lists the uploaded build, usually a few
# minutes after the upload and long before processing ends.
cmd_testflight_notes() {
  [ -n "${NOTES:-}" ] || { echo "::notice::No notes, so What to Test stays as it is."; return 0; }
  : "${BUILD_NUMBER:?BUILD_NUMBER is not set}"
  sr_asc_key
  local log="$RUNNER_TEMP/testflight-notes.log" attempt rc
  # Until Apple lists the build, pilot answers "No build to distribute!", the
  # one failure worth retrying. --app_platform because there is no IPA here.
  for attempt in $(seq 1 40); do
    set +e
    fastlane pilot distribute \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$SR_IOS_BUNDLE_ID" \
      --app_platform ios \
      --app_version "$VERSION" \
      --build_number "$BUILD_NUMBER" \
      --changelog "$NOTES" \
      --distribute_external false \
      --skip_waiting_for_build_processing true 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    set -e
    [ "$rc" -eq 0 ] && return 0
    grep -q "No build to distribute" "$log" || exit "$rc"
    echo "Build $BUILD_NUMBER is not listed yet (attempt $attempt of 40), trying again in a minute."
    sleep 60
  done
  sr_die "Apple did not list build $BUILD_NUMBER within 40 minutes. The build is uploaded; only What to Test is missing, and can be added in App Store Connect."
}

# What's New, the App Review contact and the release type for the App Store
# version the upload created or reused. Apple copies none of them from the
# previous version and refuses a submission without the first two.
cmd_appstore_notes() {
  sr_asc_key
  local work="$RUNNER_TEMP/appstore-notes" store_json
  store_json=$(ruby "$SR_DIR/changelog.rb" store --store "$SR_ROOT/$SR_STORE")
  rm -rf "$work"
  # A tree shaped like an app's fastlane/metadata, holding only what this sets.
  # deliver sends a field only when it has a file, so the description,
  # keywords and everything else stay as they are.
  STORE_JSON="$store_json" STORE_FILE="$SR_STORE" python3 - "$work" <<'PY'
import json, os, re, sys
work, limit = sys.argv[1], 4000
meta = os.path.join(work, "fastlane", "metadata")
os.makedirs(meta, exist_ok=True)
env = os.environ
store = json.loads(env["STORE_JSON"] or "{}")
notes_cfg = store.get("release_notes") or {}
locale = str(notes_cfg.get("locale") or "").strip() or "en-US"
wrote = []

def write(rel, text):
    path = os.path.join(meta, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

def clean(text):
    # Apple refuses emoji in What's New.
    text = re.sub("[\U0001F000-\U0001FFFF☀-➿️‍]", "", text)
    text = "\n".join(re.sub(r"[ \t]{2,}", " ", l).rstrip() for l in text.strip().splitlines())
    if len(text) <= limit:
        return text
    lines, kept = [l for l in text.splitlines() if l.strip()], []
    for line in lines[:-1]:
        if len("\n".join(kept + [line, lines[-1]])) > limit:
            break
        kept.append(line)
    print(f"::warning::What's New is {len(text)} characters; kept {len(kept) + 1} of {len(lines)} lines to fit {limit}.")
    return "\n".join(kept + [lines[-1]])

def for_app_store(text):
    # App Review rejects metadata that names other platforms, so a changelog
    # line about the Android build stays out of What's New.
    lines = text.strip().splitlines()
    kept = [l for l in lines if not re.search(r"\b(android|google play|play store)\b", l, re.I)]
    if len(kept) < len(lines):
        print(f"::notice::Left {len(lines) - len(kept)} line(s) naming Android or Google Play out of What's New.")
        if not "\n".join(kept).strip():
            return str(notes_cfg.get("default") or "Bug fixes and improvements.")
    return "\n".join(kept)

notes = clean(for_app_store(env.get("NOTES", "")))
if notes:
    write(f"{locale}/release_notes.txt", notes)
    wrote.append(f"What's New ({locale}, {len(notes)} characters)")
    # Every other localization gets store.yml's fixed line.
    for loc, text in (notes_cfg.get("app_store") or {}).items():
        if str(loc) == locale:
            continue
        write(f"{loc}/release_notes.txt", clean(str(text)))
        wrote.append(f"What's New ({loc})")
else:
    print("::notice::No release notes, so What's New stays as it is.")

# The App Review contact: store.yml, each empty value from APP_REVIEW_*.
review = store.get("app_review") or {}
contact = {}
for key in ("first_name", "last_name", "email", "phone"):
    contact[key] = str(review.get(key) or "").strip() or env.get(f"APP_REVIEW_{key.upper()}", "").strip()
if all(contact.values()):
    for key, name in (("first_name", "first_name"), ("last_name", "last_name"),
                      ("email", "email_address"), ("phone", "phone_number")):
        write(f"review_information/{name}.txt", contact[key])
    wrote.append("the App Review contact")
elif any(contact.values()):
    missing = ", ".join(k for k, v in contact.items() if not v)
    print(f"::error::The App Review contact lacks {missing}. Fill in app_review in {env['STORE_FILE']} (or the APP_REVIEW_* secret).")
    sys.exit(1)
else:
    print("::warning::No App Review contact in store.yml, so the version keeps whatever contact it has. Apple refuses a submission without one.")

with open(os.path.join(work, "wrote.txt"), "w") as f:
    f.write("\n".join(wrote + ["release when approved"]))
PY
  echo "Writing: $(paste -sd ',' "$work/wrote.txt" | sed 's/,/, /g')"
  # Inside the tree: deliver without a binary asks whether to set itself up
  # unless it finds fastlane/metadata in the working directory, and --force
  # does not skip that question. --automatic_release: only a call that
  # uploads metadata applies it.
  ( cd "$work" && fastlane deliver \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$SR_IOS_BUNDLE_ID" \
      --app_version "$VERSION" \
      --skip_binary_upload true \
      --skip_screenshots true \
      --automatic_release true \
      --submit_for_review false \
      --run_precheck_before_submit false \
      --force true )
}

# Attaches the uploaded build to the version and sends it to review. deliver
# waits until Apple has processed the build (up to two hours), which is why
# the workflow runs this on Linux.
cmd_submit() {
  : "${BUILD_NUMBER:?BUILD_NUMBER is not set}"
  sr_asc_key
  local work="$RUNNER_TEMP/submit" log="$RUNNER_TEMP/submit.log" rc
  # An empty fastlane/metadata keeps deliver from asking its setup question;
  # with --skip_metadata nothing in it is sent.
  mkdir -p "$work/fastlane/metadata"
  set +e
  ( cd "$work" && fastlane deliver \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$SR_IOS_BUNDLE_ID" \
      --app_version "$VERSION" \
      --build_number "$BUILD_NUMBER" \
      --skip_binary_upload true \
      --skip_screenshots true \
      --skip_metadata true \
      --submit_for_review true \
      --run_precheck_before_submit false \
      --force true ) 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ]; then
    sr_explain ios "$log"
    exit "$rc"
  fi
}

cmd_summary() {
  local text
  case "${REVIEW:-}" in
    dry-run) text="dry run: archived, signed and exported, uploaded nothing" ;;
    uploaded) [ "$TRACK" = testflight ] && text="in TestFlight" || text="uploaded to the App Store version" ;;
    *) text="the upload did not finish" ;;
  esac
  [ "${SUBMITTED:-}" = true ] && text="$text, sent to review, released when Apple approves it"
  {
    echo "### iOS $VERSION"
    echo ""
    echo "| | |"
    echo "|---|---|"
    echo "| build | \`${BUILD_NUMBER:-n/a}\` |"
    echo "| track | \`$TRACK\` |"
    echo "| result | $text |"
  } >> "$GITHUB_STEP_SUMMARY"
}

cmd_cleanup() {
  if sr_ci && [ -n "${SR_KEYCHAIN:-}" ]; then
    security delete-keychain "$SR_KEYCHAIN" 2> /dev/null || true
  fi
  rm -f "$RUNNER_TEMP/asc-key.p8" "$RUNNER_TEMP/asc-key.json" "$RUNNER_TEMP/dart-defines.json"
}

case "${1:-}" in
  prepare | archive | export | upload | submit | summary | cleanup) "cmd_$1" ;;
  testflight-notes) cmd_testflight_notes ;;
  appstore-notes) cmd_appstore_notes ;;
  *) echo "usage: ios.sh prepare|archive|export|upload|testflight-notes|appstore-notes|submit|summary|cleanup" >&2; exit 2 ;;
esac
