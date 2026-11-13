#!/usr/bin/env bash
# The Android release, one command per step. The release-android workflow
# runs these on a runner; release.sh --local runs the same ones on a Mac.
#
#   android.sh prepare   version code, signing key
#   android.sh build     dependencies, pre-build command, the AAB, its signature
#   android.sh upload    What's new, then the AAB to Play (a dry run: validated only)
#   android.sh summary   the result, as a table
#   android.sh cleanup   key files gone
#
# Configuration: store.yml (android section). Run: VERSION, PLAY_TRACK,
# RELEASE_STATUS (completed | draft), NOTES, DRY_RUN, BUILD_NUMBER (set by
# prepare, or given). Credentials on a runner: ANDROID_KEYSTORE_B64,
# ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_PASSWORD and
# GOOGLE_PLAY_SERVICE_ACCOUNT_JSON. On a Mac: the app's own key.properties (or
# KEYSTORE_PATH and friends for a native Gradle project) and
# GOOGLE_PLAY_JSON_KEY_PATH. ANDROID_UPLOAD_KEY_SHA1 is checked when set.
#
# Deliberate choices, each one a release that stopped once:
#   * the version code comes from the clock, so it always rises and no two
#     builds (CI or laptop) can collide.
#   * the bundle's certificate is compared with the registered upload key
#     before the upload, because Play's rejection does not name the cause.
#   * What's new is fitted to Play's 500 characters before the upload.
#   * after a rejection Play takes changes only from the Console; the upload
#     then lands held, and says so, instead of claiming it was sent.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sr_config
[ "$SR_ANDROID" = true ] || sr_die "store.yml has no android section."
VERSION="${VERSION:?VERSION is not set}"
PLAY_TRACK="${PLAY_TRACK:-internal}"
RELEASE_STATUS="${RELEASE_STATUS:-draft}"
DRY_RUN="${DRY_RUN:-false}"
# No "/./" in the paths: actions/upload-artifact refuses them.
APP_DIR="$SR_ROOT"
[ "$SR_APP_DIR" = . ] || APP_DIR="$SR_ROOT/$SR_APP_DIR"
# prepare sets ANDROID_BUILD_NUMBER; a given BUILD_NUMBER overrides the scheme.
BUILD_NUMBER="${ANDROID_BUILD_NUMBER:-${BUILD_NUMBER:-}}"

cmd_prepare() {
  local missing=""
  if sr_ci; then
    [ -n "${ANDROID_KEYSTORE_B64:-}" ] || missing="$missing ANDROID_KEYSTORE_B64"
    [ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ] || missing="$missing ANDROID_KEYSTORE_PASSWORD"
    [ -n "${ANDROID_KEY_PASSWORD:-}" ] || missing="$missing ANDROID_KEY_PASSWORD"
    [ -n "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}" ] || [ "$DRY_RUN" = true ] || missing="$missing GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
    [ -z "$missing" ] || sr_die "Missing:$missing. The store-release skill sets them: skills/store-release/references/secrets.md"
  else
    [ -n "${GOOGLE_PLAY_JSON_KEY_PATH:-}" ] && [ -f "$GOOGLE_PLAY_JSON_KEY_PATH" ] \
      || sr_die "No Play service-account key: set GOOGLE_PLAY_JSON_KEY_PATH in .env to the JSON file."
  fi

  local number
  number=$(sr_build_number "$SR_ANDROID_BUILD_NUMBER" "${BUILD_NUMBER:-}")
  sr_out build_number "$number"
  sr_env ANDROID_BUILD_NUMBER "$number"
  BUILD_NUMBER="$number"
  echo "::notice title=Android::$VERSION (versionCode $number)"

  cd "$APP_DIR"
  if sr_ci; then
    local keystore
    if [ -n "$SR_ANDROID_KEYSTORE_PATH" ]; then
      mkdir -p "$(dirname "$SR_ANDROID_KEYSTORE_PATH")"
      keystore="$APP_DIR/$SR_ANDROID_KEYSTORE_PATH"
    else
      keystore="$RUNNER_TEMP/release.keystore"
    fi
    ( umask 077; printf '%s' "$ANDROID_KEYSTORE_B64" | base64 --decode > "$keystore" )
    if [ -n "$SR_ANDROID_KEY_PROPERTIES" ]; then
      mkdir -p "$(dirname "$SR_ANDROID_KEY_PROPERTIES")"
      ( umask 077
        printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=%s\n' \
          "$ANDROID_KEYSTORE_PASSWORD" "$ANDROID_KEY_PASSWORD" "$SR_ANDROID_KEY_ALIAS" "$keystore" > "$SR_ANDROID_KEY_PROPERTIES" )
    fi
    # Also in the environment, for a Gradle signingConfig that reads it there
    # (the native projects do).
    sr_env KEYSTORE_PATH "$keystore"
    sr_env KEYSTORE_PASSWORD "$ANDROID_KEYSTORE_PASSWORD"
    sr_env KEY_ALIAS "$SR_ANDROID_KEY_ALIAS"
    sr_env KEY_PASSWORD "$ANDROID_KEY_PASSWORD"
  elif [ -n "$SR_ANDROID_KEY_PROPERTIES" ]; then
    [ -f "$SR_ANDROID_KEY_PROPERTIES" ] \
      || sr_die "No $SR_ANDROID_KEY_PROPERTIES: the build signs with it (storeFile, storePassword, keyAlias, keyPassword)."
  else
    [ -n "${KEYSTORE_PATH:-}" ] && [ -f "$KEYSTORE_PATH" ] \
      || sr_die "No signing key: set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD in .env for the Gradle signingConfig."
  fi
}

cmd_build() {
  cd "$APP_DIR"
  if [ "$SR_ANDROID_STACK" = flutter ]; then
    flutter pub get
  fi
  if [ -n "$SR_ANDROID_PRE_BUILD_COMMAND" ]; then
    bash -c "$SR_ANDROID_PRE_BUILD_COMMAND"
  fi
  sr_dart_defines
  export VERSION BUILD_NUMBER DART_DEFINES_ARG
  local build
  if [ -n "$SR_ANDROID_BUILD_COMMAND" ]; then
    build="$SR_ANDROID_BUILD_COMMAND"
  else
    build="flutter build appbundle --release --build-name=$VERSION --build-number=$BUILD_NUMBER $SR_ANDROID_EXTRA_BUILD_ARGS $DART_DEFINES_ARG"
  fi
  # Two attempts: a runner lost mid-build or a flaky dependency fetch is the
  # most common Android failure and costs nothing to retry.
  local attempt ok=false
  for attempt in 1 2; do
    echo "::group::Build attempt $attempt"
    if sr_heavy bash -c "$build"; then
      echo "::endgroup::"
      ok=true
      break
    fi
    echo "::endgroup::"
    [ "$attempt" = 2 ] && break
    echo "::warning::Build attempt $attempt failed, retrying once."
    sleep 15
  done
  rm -f "$RUNNER_TEMP/dart-defines.json"
  [ "$ok" = true ] || exit 1

  local aab="$APP_DIR/$SR_ANDROID_ARTIFACT_PATH" sha1 actual expected
  [ -f "$aab" ] || sr_die "No bundle at $SR_ANDROID_ARTIFACT_PATH (store.yml android.artifact_path)."
  # Play rejects a bundle signed with the wrong key with a message that does
  # not name the cause, so compare here.
  sha1=$(keytool -printcert -jarfile "$aab" | grep -m1 'SHA1:' | tr -d ' ' | cut -d: -f2-)
  actual=$(printf '%s' "$sha1" | tr -d ':' | tr '[:lower:]' '[:upper:]')
  expected=$(printf '%s' "${ANDROID_UPLOAD_KEY_SHA1:-}" | tr -d ' :' | tr '[:lower:]' '[:upper:]')
  if [ -n "$expected" ] && [ "$expected" != "$actual" ]; then
    sr_die "The bundle is signed with $actual but Play expects the upload key $expected. The keystore or android.key_alias is wrong."
  fi
  [ -n "$expected" ] || echo "::notice::ANDROID_UPLOAD_KEY_SHA1 is not set, so the signing key was not checked against Play's."
  echo "::notice::Bundle $(du -h "$aab" | cut -f1), signed with $actual"
  sr_env AAB_PATH "$aab"
  sr_out aab "$aab"
}

cmd_upload() {
  : "${AAB_PATH:?AAB_PATH is not set: run android.sh build first}"
  local notes_dir="$RUNNER_TEMP/play-notes" log="$RUNNER_TEMP/supply.log" key store_json
  store_json=$(ruby "$SR_DIR/changelog.rb" store --store "$SR_ROOT/$SR_STORE")
  rm -rf "$notes_dir"
  # Fitted before the upload: Play refuses more than 500 characters per
  # language, and finding that out at the end wastes the whole build.
  STORE_JSON="$store_json" python3 - "$notes_dir" <<'PY'
import json, os, sys
root, limit = sys.argv[1], 500
notes = os.environ.get("NOTES", "").strip()
cfg = json.loads(os.environ["STORE_JSON"] or "{}").get("release_notes") or {}
locale = str(cfg.get("locale") or "").strip() or "en-US"

def fit(text):
    """Whole lines from the top, plus the last line, within limit."""
    if len(text) <= limit:
        return text, 0
    lines = [l for l in text.splitlines() if l.strip()]
    last, kept = lines[-1], []
    for line in lines[:-1]:
        if len("\n".join(kept + [line, last])) > limit:
            break
        kept.append(line)
    fitted = "\n".join(kept + [last])
    if len(fitted) > limit:  # not even one line fits: cut at a word
        return text[: limit - 3].rsplit(" ", 1)[0] + "...", len(lines)
    return fitted, len(lines) - len(kept) - 1

def write(loc, text):
    d = os.path.join(root, loc, "changelogs")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "default.txt"), "w", encoding="utf-8") as f:
        f.write(text)

if not notes:
    print("::notice::No release notes, so Play keeps the previous text.")
    sys.exit(0)
fitted, dropped = fit(notes)
write(locale, fitted)
left = f", {dropped} line(s) left out to fit {limit}" if dropped else ""
print(f"::notice::What's new ({locale}, {len(fitted)} characters{left}) ready.")
# Every other listing language gets store.yml's fixed line.
for loc, text in (cfg.get("play") or {}).items():
    if str(loc) != locale:
        write(str(loc), fit(str(text).strip())[0])
PY
  [ -d "$notes_dir" ] || notes_dir=""

  if [ -n "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
    key="$RUNNER_TEMP/play-service-account.json"
    ( umask 077; printf '%s' "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" > "$key" )
  else
    key="${GOOGLE_PLAY_JSON_KEY_PATH:?No Play service-account key}"
  fi

  supply() {
    # skip_upload_* keeps it to the binary and What's new: the store listing
    # is a different job with a different blast radius.
    fastlane supply \
      --package_name "$SR_ANDROID_PACKAGE" \
      --aab "$AAB_PATH" \
      --track "$PLAY_TRACK" \
      --release_status "$RELEASE_STATUS" \
      --json_key "$key" \
      ${notes_dir:+--metadata_path "$notes_dir"} \
      --skip_upload_metadata true \
      --skip_upload_images true \
      --skip_upload_screenshots true \
      --rescue_changes_not_sent_for_review false \
      "$@" 2>&1 | tee -a "$log"
    return "${PIPESTATUS[0]}"
  }

  local review
  set +e
  if [ "$DRY_RUN" = true ]; then
    # Play validates the whole upload and commits nothing.
    supply --validate_only true && review=dry-run
  elif supply; then
    [ "$RELEASE_STATUS" = completed ] && review=sent || review=draft
  elif grep -q 'changesNotSentForReview' "$log"; then
    # After a rejection Play takes changes for review only from the Console.
    # The refused edit was never committed, so upload again, held for it.
    supply --changes_not_sent_for_review true && review=held
  fi
  set -e
  rm -f "$RUNNER_TEMP/play-service-account.json"
  if [ -z "${review:-}" ]; then
    sr_explain android "$log"
    exit 1
  fi
  sr_out review "$review"
}

cmd_summary() {
  local text
  case "${REVIEW:-}" in
    sent) text="sent for review; with managed publishing on, Publish in Play Console ships it" ;;
    draft) text="uploaded as a draft: press Send for review in Play Console" ;;
    held) text="**uploaded but not sent**: Play takes this app's changes for review only from the Console. Publishing overview, Send for review. Running it again would upload a second build" ;;
    dry-run) text="dry run: Play validated the upload, nothing was committed" ;;
    *) text="${HELD_REASON:+held back: $HELD_REASON}"; text="${text:-the upload did not finish}" ;;
  esac
  {
    echo "### Android $VERSION"
    echo ""
    echo "| | |"
    echo "|---|---|"
    echo "| versionCode | \`${BUILD_NUMBER:-n/a}\` |"
    echo "| track | \`$PLAY_TRACK\` |"
    echo "| status | \`$RELEASE_STATUS\` |"
    echo "| result | $text |"
  } >> "$GITHUB_STEP_SUMMARY"
}

cmd_cleanup() {
  rm -f "$RUNNER_TEMP/play-service-account.json" "$RUNNER_TEMP/dart-defines.json"
  if sr_ci; then
    rm -f "$RUNNER_TEMP/release.keystore"
  fi
}

case "${1:-}" in
  prepare | build | upload | summary | cleanup) "cmd_$1" ;;
  *) echo "usage: android.sh prepare|build|upload|summary|cleanup" >&2; exit 2 ;;
esac
