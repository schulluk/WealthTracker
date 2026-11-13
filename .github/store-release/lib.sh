# shellcheck shell=bash
# Shared by ios.sh, android.sh, changelog.sh and release.sh. Sourced, not run.
#
# Every release step is written once, here, and runs in two places: as a step
# of the GitHub workflows, and on a Mac through release.sh --local. The steps
# speak GitHub's file protocol (GITHUB_OUTPUT, GITHUB_ENV,
# GITHUB_STEP_SUMMARY, RUNNER_TEMP, ::error:: lines); release.sh provides the
# same files outside GitHub and reads them back, so a step cannot tell the
# difference except through sr_ci, which only the credential and keychain
# handling asks.
#
# Configuration comes from the app's store.yml (config.rb), never from
# arguments: the workflow and release.sh read the same file.

SR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SR_ROOT="$(git rev-parse --show-toplevel)"

: "${RUNNER_TEMP:?RUNNER_TEMP is not set; outside GitHub Actions, run the steps through release.sh --local}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"
: "${GITHUB_ENV:?GITHUB_ENV is not set}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is not set}"

sr_ci() { [ "${GITHUB_ACTIONS:-}" = true ]; }

# NAME VALUE as a step output; several lines are fine.
sr_out() {
  local eof
  eof="EOF_$(openssl rand -hex 8)"
  printf '%s<<%s\n%s\n%s\n' "$1" "$eof" "$2" "$eof" >> "$GITHUB_OUTPUT"
}

# NAME VALUE for this step and every later one.
sr_env() {
  local eof
  eof="EOF_$(openssl rand -hex 8)"
  printf '%s<<%s\n%s\n%s\n' "$1" "$eof" "$2" "$eof" >> "$GITHUB_ENV"
  export "$1=$2"
}

sr_die() { echo "::error::$*"; exit 1; }

# The app's store.yml as SR_* variables (see config.rb).
sr_config() {
  local cfg
  cfg=$(cd "$SR_ROOT" && ruby "$SR_DIR/config.rb" shell) || { echo "$cfg"; exit 1; }
  eval "$cfg"
}

# The build number for SCHEME (clock | commits), or GIVEN when set.
# clock: seconds since 2026-01-01 UTC, not the Unix epoch: Play caps the
# versionCode at 2100000000, raw epoch seconds reach that in 2036, and a
# versionCode can never be lowered again. ~65 years of headroom; never move the
# constant forward. A laptop build and a CI build can never collide.
# commits: the commit count, which needs the full history in the checkout.
sr_build_number() {
  local n
  if [ -n "${2:-}" ]; then
    n="$2"
  elif [ "$1" = commits ]; then
    [ "$(git -C "$SR_ROOT" rev-parse --is-shallow-repository)" = false ] \
      || sr_die "build_number: commits needs the whole history, and this checkout is shallow."
    n=$(git -C "$SR_ROOT" rev-list --count HEAD)
  else
    n=$(( $(date -u +%s) - 1767225600 ))
  fi
  [[ "$n" =~ ^[1-9][0-9]*$ ]] && [ "$n" -lt 2100000000 ] \
    || sr_die "Build number $n is outside the stores' range (1..2099999999)."
  echo "$n"
}

# A heavy build. On a Mac at most SR_HEAVY_MAX (2) Xcode or Gradle builds run
# at once across every project, so this waits for a slot and runs niced. A
# runner has the machine to itself.
sr_heavy() {
  if sr_ci; then
    "$@"
    return
  fi
  local max="${SR_HEAVY_MAX:-2}" n
  while :; do
    n=$(( $(pgrep -x xcodebuild | wc -l) + $(pgrep -f GradleWrapperMain | wc -l) ))
    [ "$n" -lt "$max" ] && break
    echo "Waiting: $n Xcode or Gradle builds are running on this Mac, at most $max at a time."
    sleep 20
  done
  nice -n 10 "$@"
}

# $RUNNER_TEMP/asc-key.json, the App Store Connect key as fastlane takes it,
# and ASC_KEY_PATH pointing at the .p8. From the secret on a runner, from the
# .env's ASC_KEY_PATH on a Mac.
sr_asc_key() {
  local json="$RUNNER_TEMP/asc-key.json" p8="$RUNNER_TEMP/asc-key.p8"
  [ -s "$json" ] && { export ASC_KEY_PATH="$p8"; return 0; }
  [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] && [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ] \
    || sr_die "No App Store Connect key id and issuer id (APP_STORE_CONNECT_API_KEY_ID / _ISSUER_ID, or ASC_KEY_ID / ASC_ISSUER_ID in .env)."
  ( umask 077
    if [ -n "${APP_STORE_CONNECT_API_KEY_P8_B64:-}" ]; then
      printf '%s' "$APP_STORE_CONNECT_API_KEY_P8_B64" | base64 --decode > "$p8"
    elif [ -n "${ASC_KEY_PATH:-}" ] && [ -f "$ASC_KEY_PATH" ]; then
      cp "$ASC_KEY_PATH" "$p8"
    else
      sr_die "No App Store Connect key: APP_STORE_CONNECT_API_KEY_P8_B64, or ASC_KEY_PATH in .env naming the .p8."
    fi
    python3 - "$APP_STORE_CONNECT_API_KEY_ID" "$APP_STORE_CONNECT_ISSUER_ID" "$p8" "$json" <<'PY'
import json, sys
key_id, issuer, p8, out = sys.argv[1:]
with open(p8) as f:
    key = f.read()
with open(out, "w") as f:
    json.dump({"key_id": key_id, "issuer_id": issuer, "key": key, "duration": 1200, "in_house": False}, f)
PY
  ) || exit 1
  export ASC_KEY_PATH="$p8"
}

# DART_DEFINES_ARG for a Flutter build, from DART_DEFINES_JSON (the secret on
# a runner; release.sh builds it from the .env names store.yml lists). As a
# file: a --dart-define argument would be in every process listing.
sr_dart_defines() {
  DART_DEFINES_ARG=""
  if [ -n "${DART_DEFINES_JSON:-}" ]; then
    local f="$RUNNER_TEMP/dart-defines.json"
    ( umask 077; printf '%s' "$DART_DEFINES_JSON" > "$f" )
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d, dict) and d; print("::notice::Build defines: " + ", ".join(sorted(d)))' "$f" \
      || sr_die "DART_DEFINES_JSON is not a non-empty JSON object."
    DART_DEFINES_ARG="--dart-define-from-file=$f"
  fi
  export DART_DEFINES_ARG
}

# Explain a failed store call: the cause and the fix, from the log.
sr_explain() { # PLATFORM LOG
  python3 "$SR_DIR/classify.py" --platform "$1" --log "$2" || true
}
