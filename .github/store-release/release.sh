#!/usr/bin/env bash
# Release this app. By default on GitHub: dispatches the release workflow and
# follows it to the end. With --local on this Mac, through the very same steps
# (ios.sh, android.sh, changelog.sh), for when GitHub's runners are not
# available or to try a pipeline change without a round trip.
#
#   ./release.sh [both|ios|android] [options]
#   ./release.sh listing [both|ios|android] [--screenshots] [--dry-run] [--local]
#   ./release.sh setup [--plan] [--only repo,store,env,listing,secrets]
#
# setup asks for whatever the app still lacks (store.yml, .env, the listing,
# the GitHub secrets), each with a default found in the project, the other
# apps on this Mac or the stores; see setup.rb. A release that finds
# something missing offers it too, when it runs in a terminal.
#
# listing sends the store listing from listing/<language>.md (and, with --screenshots,
# the screenshots store.yml names) instead of a build. Options:
#
#   --testflight           iOS to TestFlight only; default: the App Store version
#   --play-track TRACK     internal (default) | alpha | beta | production
#   --submit               send to review, and mark ## Next as released
#   --dry-run              build and sign everything, upload and commit nothing
#   --bump STEP            minor (default) | patch | major
#   --notes TEXT           instead of ## Next's ### Public
#   --ref REF              GitHub only: the branch or vX.Y.Z tag to run on (default main)
#   --local                on this Mac instead of GitHub
#   --env FILE             --local: the credentials file (default: store.yml's app.env, .env)
#   --yes                  --local: skip the confirmation before a real release
#   --screenshots          listing: replace the screenshots too
#                          (--play-track there: the track whose newest build the
#                          Play listing attaches to; default the first of
#                          production, beta, alpha, internal that has one)
#
# Both read store.yml, so they build the same thing. --local takes its
# credentials from the gitignored .env: ASC_KEY_ID, ASC_ISSUER_ID and
# ASC_KEY_PATH, GOOGLE_PLAY_JSON_KEY_PATH, the dart_defines store.yml names,
# and ASC_REVIEW_* for a review contact store.yml leaves empty. iOS signs with
# the Apple Distribution identity in the login keychain, Android with the
# app's key.properties.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Onboarding first: it works while store.yml does not exist yet.
if [ "${1:-}" = setup ]; then
  shift
  exec ruby "$SELF_DIR/setup.rb" "$@"
fi
ORIG_ARGS=("$@")

# Something a release needs is missing. In a terminal, ask for it now and
# start over; otherwise say how.
offer_setup() { # PART
  if [ -t 0 ] && [ -t 1 ]; then
    printf 'Fill in what is missing now (./release.sh setup --only %s)? [Y/n] ' "$1"
    read -r answer
    case "$answer" in n | N | no) return 1 ;; esac
    ruby "$SELF_DIR/setup.rb" --only "$1" || return 1
    # bash 3.2 calls an empty "${ORIG_ARGS[@]}" unbound under set -u.
    exec "$SELF_DIR/release.sh" ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}
  fi
  echo "./release.sh setup asks for each missing value, with a default where it finds one." >&2
  return 1
}

LISTING=false SCREENSHOTS=false PLAY_TRACK_SET=false
PLATFORMS=both IOS_TRACK=appstore PLAY_TRACK=internal SUBMIT=false DRY_RUN=false BUMP=minor
NOTES_GIVEN="" NOTES_SET=false REF="" LOCAL=false ENV_FILE="" YES=false
while [ $# -gt 0 ]; do
  case "$1" in
    listing) LISTING=true; shift ;;
    --screenshots) SCREENSHOTS=true; shift ;;
    both | ios | android) PLATFORMS="$1"; shift ;;
    --testflight) IOS_TRACK=testflight; shift ;;
    --play-track) PLAY_TRACK="${2:?}"; PLAY_TRACK_SET=true; shift 2 ;;
    --submit) SUBMIT=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --bump) BUMP="${2:?}"; shift 2 ;;
    --notes) NOTES_GIVEN="${2?}"; NOTES_SET=true; shift 2 ;;
    --ref) REF="${2:?}"; shift 2 ;;
    --local) LOCAL=true; shift ;;
    --env) ENV_FILE="${2:?}"; shift 2 ;;
    --yes) YES=true; shift ;;
    -h | --help) sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done
case "$PLAY_TRACK" in internal | alpha | beta | production) ;; *) echo "--play-track is internal, alpha, beta or production" >&2; exit 2 ;; esac
case "$BUMP" in minor | patch | major) ;; *) echo "--bump is minor, patch or major" >&2; exit 2 ;; esac

if ! cfg=$(ruby "$SELF_DIR/config.rb" shell); then
  echo "$cfg" >&2
  offer_setup store
  exit 1
fi
eval "$cfg"
want_ios=false want_android=false
[ "$SR_IOS" = true ] && [ "$PLATFORMS" != android ] && want_ios=true
[ "$SR_ANDROID" = true ] && [ "$PLATFORMS" != ios ] && want_android=true
[ "$want_ios$want_android" != falsefalse ] || { echo "Nothing to release: $PLATFORMS is not in $SR_STORE." >&2; exit 1; }

# ─────────────────────────────── on GitHub ───────────────────────────────
if [ "$LOCAL" = false ]; then
  origin=$(git remote get-url origin)
  slug=$(printf '%s' "$origin" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')
  [[ "$slug" =~ ^[^/]+/[^/]+$ ]] || { echo "origin ($origin) is not a GitHub repository." >&2; exit 1; }
  # A secret the run needs and the repo lacks fails it minutes in; in a
  # terminal, catch that here.
  if [ -t 0 ] && [ -t 1 ]; then
    rc=0
    plan=$(ruby "$SELF_DIR/setup.rb" --plan --only secrets 2>&1) || rc=$?
    if [ "$rc" = 10 ]; then
      printf '%s\n' "$plan" | sed -n 's/^secrets: //p' >&2
      offer_setup secrets
      exit 1
    fi
  fi
  ref="${REF:-main}"
  if [ "$LISTING" = true ]; then
    workflow=listing.yml
    anchor=auto
    [ "$PLAY_TRACK_SET" = true ] && anchor="$PLAY_TRACK"
    args=(-f "platforms=$PLATFORMS" -f "screenshots=$SCREENSHOTS" -f "dry_run=$DRY_RUN" -f "play_track=$anchor")
    what="listing $PLATFORMS, screenshots $SCREENSHOTS, Play track $anchor, dry run $DRY_RUN"
  else
    workflow=release.yml
    args=(-f "platforms=$PLATFORMS" -f "ios_track=$IOS_TRACK" -f "play_track=$PLAY_TRACK"
          -f "submit=$SUBMIT" -f "dry_run=$DRY_RUN" -f "bump=$BUMP")
    [ "$NOTES_SET" = true ] && args+=(-f "release_notes=$NOTES_GIVEN")
    what="$PLATFORMS, iOS $IOS_TRACK, Play $PLAY_TRACK, submit $SUBMIT, dry run $DRY_RUN"
  fi
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "Dispatching $workflow on $slug@$ref: $what"
  new_run() {
    gh run list --repo "$slug" --workflow "$workflow" --event workflow_dispatch --limit 10 \
      --json databaseId,createdAt --jq "[.[] | select(.createdAt >= \"$started\")] | last | .databaseId // empty"
  }
  # GitHub sometimes answers a dispatch with a 5xx. Retry, but only after
  # making sure no run started anyway: a release must never go out twice.
  id=""
  for attempt in 1 2 3; do
    err=$(gh workflow run "$workflow" --repo "$slug" --ref "$ref" "${args[@]}" 2>&1 < /dev/null > /dev/null) && break
    echo "$err" >&2
    # Only GitHub's own trouble is worth another try; a wrong ref is not.
    case "$err" in *"HTTP 5"*) ;; *) exit 1 ;; esac
    [ "$attempt" = 3 ] && { echo "GitHub refused the dispatch three times; nothing started." >&2; exit 1; }
    sleep 15
    id=$(new_run)
    [ -n "$id" ] && break
    echo "No run started; dispatching again." >&2
  done
  for _ in $(seq 1 30); do
    [ -n "$id" ] && break
    id=$(new_run)
    [ -n "$id" ] && break
    sleep 4
  done
  [ -n "$id" ] || { echo "The run did not show up; look at https://github.com/$slug/actions" >&2; exit 1; }
  echo "https://github.com/$slug/actions/runs/$id"
  rc=0
  gh run watch "$id" --repo "$slug" --exit-status --interval 30 > /dev/null || rc=$?
  gh run view "$id" --repo "$slug" --json jobs \
    --jq '.jobs[] | "\(.conclusion // .status)\t\(.name)"' | column -t -s $'\t'
  exit "$rc"
fi

# ─────────────────────────────── on this Mac ─────────────────────────────
WORK=$(mktemp -d)
cleanup_all() {
  rm -f "$WORK/tmp/asc-key.p8" "$WORK/tmp/asc-key.json" "$WORK/tmp/play-service-account.json" 2> /dev/null || true
  [ "$LISTING" = true ] && { rm -rf "$WORK"; return 0; }
  [ "$want_ios" = true ] && step ios-cleanup "$SELF_DIR/ios.sh" cleanup > /dev/null 2>&1 || true
  [ "$want_android" = true ] && step android-cleanup "$SELF_DIR/android.sh" cleanup > /dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup_all EXIT
unset GITHUB_ACTIONS GITHUB_REF_TYPE GITHUB_REF_NAME
# fastlane wants a UTF-8 locale and misreads files without one.
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
export RUNNER_TEMP="$WORK/tmp" GITHUB_ENV="$WORK/env" GITHUB_STEP_SUMMARY="$WORK/summary.md"
mkdir -p "$RUNNER_TEMP"
: > "$GITHUB_ENV"
: > "$GITHUB_STEP_SUMMARY"

# KEY=VALUE files as GitHub writes them (NAME<<EOF blocks too) -> shell.
kv() { # FILE [NAME]: every pair as `export` lines, or one value
  python3 - "$@" <<'PY'
import shlex, sys
path, want = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else None)
pairs, lines, i = {}, open(path).read().split("\n"), 0
while i < len(lines):
    line = lines[i]
    if "<<" in line and ("=" not in line or line.index("<<") < line.index("=")):
        name, eof = line.split("<<", 1)
        value = []
        i += 1
        while i < len(lines) and lines[i] != eof:
            value.append(lines[i])
            i += 1
        pairs[name] = "\n".join(value)
    elif "=" in line:
        name, value = line.split("=", 1)
        pairs[name] = value
    i += 1
if want is not None:
    sys.stdout.write(pairs.get(want, ""))
else:
    for name, value in pairs.items():
        print(f"export {name}={shlex.quote(value)}")
PY
}

# One step, as a workflow runs it: its own GITHUB_OUTPUT, what it put in
# GITHUB_ENV carried on, annotations made readable.
step() { # NAME COMMAND...
  local name="$1" rc
  shift
  export GITHUB_OUTPUT="$WORK/out-$name"
  : > "$GITHUB_OUTPUT"
  printf '\n\033[1m==> %s\033[0m\n' "$name"
  set +e
  "$@" 2>&1 | while IFS= read -r line; do
    case "$line" in
      ::error*) printf '\033[31merror:\033[0m %s\n' "${line#*::*::}" ;;
      ::warning*) printf '\033[33mwarning:\033[0m %s\n' "${line#*::*::}" ;;
      ::notice*) printf 'note: %s\n' "${line#*::*::}" ;;
      ::group::*) printf '%s\n' "${line#::group::}" ;;
      ::endgroup::*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
  rc=${PIPESTATUS[0]}
  set -e
  eval "$(kv "$GITHUB_ENV")"
  return "$rc"
}
out() { kv "$WORK/out-$1" "$2"; } # STEP NAME

# Credentials from the .env, never sourced (it is data, not a script).
# Values already in the environment win.
env_file="${ENV_FILE:-$SR_APP_DIR/${SR_ENV:-.env}}"
if [ ! -f "$env_file" ]; then
  echo "No credentials file $env_file (--env FILE)." >&2
  offer_setup env
  exit 1
fi
env_dir=$(cd "$(dirname "$env_file")" && pwd)
dotenv() { # NAME: its value in the .env, empty when absent
  python3 - "$env_file" "$1" <<'PY'
import re, sys
path, want = sys.argv[1:]
for line in open(path, encoding="utf-8"):
    m = re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", line)
    if m and m.group(1) == want:
        v = m.group(2)
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        sys.stdout.write(v)
        break
PY
}
take() { # TARGET SOURCE...: the first non-empty of the environment and the .env
  local target="$1" src v
  shift
  [ -n "${!target:-}" ] && return 0
  for src in "$target" "$@"; do
    v=$(dotenv "$src")
    if [ -n "$v" ]; then
      export "$target=$v"
      return 0
    fi
  done
}
abs() { case "$1" in /*) printf '%s' "$1" ;; ~*) printf '%s' "${1/#\~/$HOME}" ;; *) printf '%s/%s' "$env_dir" "$1" ;; esac; }
if [ "$want_ios" = true ] || [ "$want_android" = true ]; then
  take APP_STORE_CONNECT_API_KEY_ID ASC_KEY_ID
  take APP_STORE_CONNECT_ISSUER_ID ASC_ISSUER_ID
  take ASC_KEY_PATH && [ -n "${ASC_KEY_PATH:-}" ] && ASC_KEY_PATH=$(abs "$ASC_KEY_PATH")
  for k in FIRST_NAME LAST_NAME EMAIL PHONE; do take "APP_REVIEW_$k" "ASC_REVIEW_$k"; done
fi
if [ "$want_android" = true ]; then
  take GOOGLE_PLAY_JSON_KEY_PATH PLAY_STORE_JSON_KEY
  if [ -n "${GOOGLE_PLAY_JSON_KEY_PATH:-}" ]; then
    GOOGLE_PLAY_JSON_KEY_PATH=$(abs "$GOOGLE_PLAY_JSON_KEY_PATH")
  elif [ -f "$SR_APP_DIR/android/fastlane/play-store-key.json" ]; then
    GOOGLE_PLAY_JSON_KEY_PATH="$ROOT/$SR_APP_DIR/android/fastlane/play-store-key.json"
  fi
  export GOOGLE_PLAY_JSON_KEY_PATH
  for k in ANDROID_UPLOAD_KEY_SHA1 KEYSTORE_PATH KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do take "$k"; done
fi
if [ "$LISTING" = false ] && [ -n "$SR_DART_DEFINES" ] && [ -z "${DART_DEFINES_JSON:-}" ]; then
  missing=""
  for k in $SR_DART_DEFINES; do take "$k"; [ -n "${!k:-}" ] || missing="$missing $k"; done
  if [ -n "$missing" ]; then
    echo "store.yml's dart_defines are missing from $env_file:$missing" >&2
    offer_setup env
    exit 1
  fi
  # shellcheck disable=SC2086
  DART_DEFINES_JSON=$(python3 -c 'import json, os, sys; print(json.dumps({k: os.environ[k] for k in sys.argv[1:]}))' $SR_DART_DEFINES)
  export DART_DEFINES_JSON
fi

# The listing: listing/<language>.md to both stores, nothing built.
if [ "$LISTING" = true ]; then
  command -v fastlane > /dev/null || { echo "fastlane is not installed." >&2; exit 1; }
  export DRY_RUN SCREENSHOTS
  # listing.sh picks the Play track itself unless one was asked for.
  if [ "$PLAY_TRACK_SET" = true ]; then export PLAY_TRACK; else unset PLAY_TRACK; fi
  stores=""
  [ "$want_ios" = true ] && stores="App Store"
  [ "$want_android" = true ] && stores="${stores:+$stores and }Google Play"
  if [ "$DRY_RUN" = true ]; then
    echo "Dry run of the listing for $stores."
  elif [ "$YES" = false ]; then
    printf 'Send the listing from %s/%s to %s? [y/N] ' "$SR_LISTING_DIR" "$([ "$SCREENSHOTS" = true ] && echo " and the screenshots")" "$stores"
    read -r answer
    [ "$answer" = y ] || [ "$answer" = Y ] || { echo "Nothing sent."; exit 1; }
  fi
  failed=false
  if [ "$want_ios" = true ]; then
    step listing-ios "$SELF_DIR/listing.sh" ios || failed=true
  fi
  if [ "$want_android" = true ]; then
    step listing-android "$SELF_DIR/listing.sh" android || failed=true
  fi
  LISTING_IOS=$(out listing-ios ios 2> /dev/null || true) LISTING_ANDROID=$(out listing-android android 2> /dev/null || true) \
    step listing-summary "$SELF_DIR/listing.sh" summary || true
  printf '\n'
  cat "$GITHUB_STEP_SUMMARY"
  [ "$failed" = false ]
  exit
fi

# What a runner gets from its pinned image, checked here instead.
problems=()
command -v fastlane > /dev/null || problems+=("fastlane is not installed")
if [ "${SR_IOS_STACK:-}" = flutter ] || [ "${SR_ANDROID_STACK:-}" = flutter ]; then
  have=$(flutter --version --machine 2> /dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])' || echo none)
  [ "$have" = "$SR_FLUTTER" ] || problems+=("Flutter is $have here, store.yml pins $SR_FLUTTER")
fi
if [ "$want_ios" = true ] && [ -n "$SR_IOS_XCODE" ]; then
  have=$(xcodebuild -version 2> /dev/null | sed -n 's/^Xcode //p')
  [ "$have" = "$SR_IOS_XCODE" ] || problems+=("Xcode is $have here, store.yml pins $SR_IOS_XCODE")
fi
if [ "$DRY_RUN" = false ]; then
  git fetch --quiet origin main
  [ "$(git rev-parse --abbrev-ref HEAD)" = main ] || problems+=("a release comes from main, this is $(git rev-parse --abbrev-ref HEAD)")
  [ -z "$(git status --porcelain --untracked-files=no)" ] || problems+=("the working tree has changes; a release builds exactly what is committed")
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || problems+=("main is not origin/main; pull or push first")
fi
if [ ${#problems[@]} -gt 0 ]; then
  printf '%s\n' "${problems[@]/#/- }" >&2
  if [ "$DRY_RUN" = false ]; then
    echo "Not releasing." >&2
    exit 1
  fi
  echo "(a dry run goes ahead anyway)" >&2
fi

export BUMP DRY_RUN
step plan "$SELF_DIR/changelog.sh" plan
VERSION=$(out plan version)
MODE=$(out plan mode)
NOTES=$(out plan notes)
[ "$NOTES_SET" = true ] && NOTES="$NOTES_GIVEN"
export VERSION NOTES

RELEASE_STATUS=draft
[ "$SUBMIT" = true ] && RELEASE_STATUS=completed
what="$VERSION from $(git rev-parse --short HEAD):"
[ "$want_ios" = true ] && what="$what iOS to $IOS_TRACK,"
[ "$want_android" = true ] && what="$what Android to Play $PLAY_TRACK ($RELEASE_STATUS),"
what="${what%,}"
[ "$SUBMIT" = true ] && what="$what, submitted for review"
if [ "$DRY_RUN" = true ]; then
  echo "Dry run of $what."
elif [ "$YES" = false ]; then
  printf 'Release %s? [y/N] ' "$what"
  read -r answer
  [ "$answer" = y ] || [ "$answer" = Y ] || { echo "Not releasing."; exit 1; }
fi

# Preflight asks both stores first, for both platforms at once.
if [ "$DRY_RUN" = false ]; then
  p=both
  [ "$want_ios" = false ] && p=android
  [ "$want_android" = false ] && p=ios
  PLATFORMS="$p" IOS_BUNDLE_ID="${SR_IOS_BUNDLE_ID:-}" ANDROID_PACKAGE="${SR_ANDROID_PACKAGE:-}" \
    IOS_TRACK="$IOS_TRACK" PLAY_TRACK="$PLAY_TRACK" PROBE_WRITE=true CERT_WARN_DAYS=30 \
    step preflight bash "$SELF_DIR/../actions/preflight/scripts/preflight.sh"
  if [ "$(out preflight ios_ok)" = false ]; then
    echo "iOS is held back: $(out preflight ios_reason)"
    want_ios=false
  fi
  if [ "$(out preflight android_ok)" = false ]; then
    echo "Android is held back: $(out preflight android_reason)"
    want_android=false
  fi
fi

ios_review="" android_review="" submitted=false failed=false
if [ "$want_ios" = true ]; then
  export TRACK="$IOS_TRACK"
  if step ios-prepare "$SELF_DIR/ios.sh" prepare \
    && step ios-archive "$SELF_DIR/ios.sh" archive \
    && step ios-export "$SELF_DIR/ios.sh" export \
    && step ios-upload "$SELF_DIR/ios.sh" upload; then
    ios_review=$(out ios-upload review)
  else
    failed=true
  fi
fi
if [ "$want_android" = true ]; then
  export PLAY_TRACK RELEASE_STATUS
  if step android-prepare "$SELF_DIR/android.sh" prepare \
    && step android-build "$SELF_DIR/android.sh" build \
    && step android-upload "$SELF_DIR/android.sh" upload; then
    android_review=$(out android-upload review)
  else
    failed=true
  fi
  REVIEW="$android_review" step android-summary "$SELF_DIR/android.sh" summary || true
fi
# The iOS steps that wait for Apple come last, after Android has been sent.
if [ "$ios_review" = uploaded ]; then
  export TRACK="$IOS_TRACK"
  if [ "$IOS_TRACK" = testflight ]; then
    step ios-testflight-notes "$SELF_DIR/ios.sh" testflight-notes || failed=true
  else
    if step ios-appstore-notes "$SELF_DIR/ios.sh" appstore-notes; then
      if [ "$SUBMIT" = true ]; then
        step ios-submit "$SELF_DIR/ios.sh" submit && submitted=true || failed=true
      fi
    else
      failed=true
    fi
  fi
fi
if [ "${SR_IOS:-}" = true ] && [ "$PLATFORMS" != android ]; then
  REVIEW="$ios_review" SUBMITTED="$submitted" TRACK="$IOS_TRACK" \
    step ios-summary "$SELF_DIR/ios.sh" summary || true
fi

# Once a store has this version for review, the changelog says so.
if [ "$SUBMIT" = true ] && [ "$DRY_RUN" = false ] && [ "$MODE" = new ]; then
  if [ "$submitted" = true ] || { [ "$PLAY_TRACK" = production ] && { [ "$android_review" = sent ] || [ "$android_review" = held ]; }; }; then
    RELEASED_REF=$(git rev-parse HEAD) step changelog "$SELF_DIR/changelog.sh" release || failed=true
  fi
fi

printf '\n'
awk '/^### / && NR > 1 { print "" } { print }' "$GITHUB_STEP_SUMMARY"
[ "$failed" = false ]
