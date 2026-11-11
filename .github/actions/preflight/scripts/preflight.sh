#!/usr/bin/env bash
# Ask Apple and Google whether this release can happen at all — before a
# single build starts.
#
# Why it exists: every failure below otherwise surfaces 15 to 40 minutes into
# a release, after the build, and on macOS at roughly ten times the minutes.
# Worse, several of them (an outstanding agreement, a revoked key, a review in
# flight) are not about the code at all, so a retry burns the same time again.
#
# Two kinds of outcome, deliberately kept apart:
#   fatal  nothing can ship (the key is refused, Play is down, no platform is
#          left) -> exit 1 in seconds.
#   held   one platform cannot ship this time (Apple is reviewing the previous
#          version, Play refused this one app) -> that platform's *_ok output
#          is false with a reason, the other one still ships.
#
# Environment:
#   PLATFORMS               both | ios | android
#   VERSION                 X.Y.Z being released
#   IOS_BUNDLE_ID           required when iOS is in the run
#   ANDROID_PACKAGE         required when Android is in the run
#   IOS_TRACK               appstore | testflight (testflight touches no App Store version)
#   PLAY_TRACK              internal | alpha | beta | production
#   ASC_KEY_PATH            the .p8 file
#   APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_ISSUER_ID
#   GOOGLE_PLAY_JSON_KEY_PATH
#   PROBE_WRITE             true -> prove write access with a no-op write (catches agreements)
#   CERT_WARN_DAYS          warn this many days before the distribution certificate expires
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=asc_api.sh
source "$SCRIPT_DIR/asc_api.sh"

PLATFORMS="${PLATFORMS:-both}"
VERSION="${VERSION:?VERSION is required}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-}"
ANDROID_PACKAGE="${ANDROID_PACKAGE:-}"
IOS_TRACK="${IOS_TRACK:-appstore}"
PLAY_TRACK="${PLAY_TRACK:-internal}"
PROBE_WRITE="${PROBE_WRITE:-false}"
CERT_WARN_DAYS="${CERT_WARN_DAYS:-30}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

IOS_OK=true
ANDROID_OK=true
IOS_REASON=""
ANDROID_REASON=""
ROWS=""

want() { [ "$PLATFORMS" = both ] || [ "$PLATFORMS" = "$1" ]; }

row() { ROWS="$ROWS| $1 | $2 | $3 |"$'\n'; }

fatal() {
  echo "::error::$1"
  exit 1
}

hold() { # hold PLATFORM REASON
  echo "::warning::$1 held back: $2"
  if [ "$1" = ios ]; then
    IOS_OK=false
    IOS_REASON="$2"
  else
    ANDROID_OK=false
    ANDROID_REASON="$2"
  fi
}

days_until() { # days_until ISO8601 -> whole days, negative when past
  python3 - "$1" <<'PY'
import datetime, re, sys
raw = re.sub(r'\.\d+', '', sys.argv[1]).replace('Z', '+00:00')
if re.search(r'[+-]\d{4}$', raw):
    raw = raw[:-5] + raw[-5:-2] + ':' + raw[-2:]
when = datetime.datetime.fromisoformat(raw)
now = datetime.datetime.now(datetime.timezone.utc)
print(int((when - now).total_seconds() // 86400))
PY
}

# ─────────────────────────── App Store Connect ───────────────────────────
if want ios; then
  echo "=== App Store Connect ==="
  [ -n "$IOS_BUNDLE_ID" ] || fatal "iOS is in this run but IOS_BUNDLE_ID is empty."

  asc_api GET "/v1/apps?limit=1" > /dev/null || fatal \
    "App Store Connect refused the API key ($ASC_LAST_ERROR). Check that APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_ISSUER_ID and APP_STORE_CONNECT_API_KEY_P8_B64 come from the same, still-active key (App Store Connect, Users and Access, Integrations, Keys)."
  echo "  the API key is accepted"

  APP_ID=$(asc_api GET "/v1/apps?filter[bundleId]=$IOS_BUNDLE_ID" | jq -r '.data[0].id // empty') || APP_ID=""
  if [ -z "$APP_ID" ]; then
    hold ios "No app with bundle id $IOS_BUNDLE_ID is visible to this API key: wrong bundle id, wrong team, or the key is not allowed to see this app."
  else
    echo "  app $APP_ID ($IOS_BUNDLE_ID)"

    VERSIONS=$(asc_api GET "/v1/apps/$APP_ID/appStoreVersions?limit=10") || VERSIONS=""
    if [ -z "$VERSIONS" ]; then
      echo "::warning::Could not read the App Store version states, so a review in flight cannot be ruled out before the build."
    else
      # appVersionState is the current attribute, appStoreState the older one;
      # which of the two an app answers with has changed before, so read both.
      NORM=$(echo "$VERSIONS" | jq -c '[.data[] | {
        version: .attributes.versionString,
        state: (.attributes.appVersionState // .attributes.appStoreState // "UNKNOWN")
      }]')
      SAME=$(echo "$NORM" | jq -r --arg v "$VERSION" '[.[] | select(.version == $v)][0].state // empty')
      IN_REVIEW=$(echo "$NORM" | jq -r '[.[] | select(.state == "IN_REVIEW")][0].version // empty')
      WAITING=$(echo "$NORM" | jq -r '[.[] | select(.state == "WAITING_FOR_REVIEW")][0].version // empty')

      if [ "$IOS_TRACK" = testflight ]; then
        echo "  TestFlight upload: App Store version states do not apply"
      else
        case "$SAME" in
          IN_REVIEW | PENDING_APPLE_RELEASE | PENDING_DEVELOPER_RELEASE | PROCESSING_FOR_APP_STORE | READY_FOR_SALE | READY_FOR_DISTRIBUTION | REPLACED_WITH_NEW_VERSION)
            hold ios "Version $VERSION is already $SAME on App Store Connect, so its binary can no longer be replaced. Bump the version to ship new code."
            ;;
          REJECTED | DEVELOPER_REJECTED | METADATA_REJECTED | INVALID_BINARY)
            echo "::warning::Version $VERSION is $SAME. The upload will land, but submitting has to happen from App Store Connect once the reviewer is answered. Run with submit off."
            ;;
          WAITING_FOR_REVIEW)
            echo "::notice::Version $VERSION is already waiting for review; the upload withdraws that submission to put the new build in."
            ;;
        esac
        if [ "$IOS_OK" = true ] && [ -n "$IN_REVIEW" ] && [ "$IN_REVIEW" != "$VERSION" ]; then
          hold ios "Apple is reviewing version $IN_REVIEW, and no new App Store version can be created until that review ends. Release again afterwards, or run with track=testflight, which appends a build without touching any App Store version."
        fi
        if [ -n "$WAITING" ] && [ "$WAITING" != "$VERSION" ]; then
          echo "::warning::Version $WAITING is waiting for review; the upload withdraws it to make room for $VERSION."
        fi
      fi
    fi

    # Best effort from here on: a missing role must not fail a release.
    if CERTS=$(asc_api GET "/v1/certificates?limit=200" 2>/dev/null); then
      EXPIRY=$(echo "$CERTS" | jq -r '[.data[]
        | select((.attributes.certificateType // "") | test("DISTRIBUTION"))
        | .attributes.expirationDate] | sort | last // empty')
      if [ -n "$EXPIRY" ]; then
        DAYS=$(days_until "$EXPIRY")
        if [ "$DAYS" -lt 0 ]; then
          hold ios "Every Apple distribution certificate in this team expired (the last one on $EXPIRY). Create a new one and update APPLE_DISTRIBUTION_P12_B64."
        elif [ "$DAYS" -le "$CERT_WARN_DAYS" ]; then
          echo "::warning::The newest Apple distribution certificate expires in $DAYS days ($EXPIRY). Renew it and update APPLE_DISTRIBUTION_P12_B64 before then, or every iOS release stops on the same day."
        else
          echo "  distribution certificate valid for $DAYS more days"
        fi
      fi
    else
      echo "::notice::Could not list certificates with this key, so there is no expiry warning. Harmless: an expiry still fails the signing step with a clear message."
    fi

    if [ -n "$APP_ID" ] && BUILDS=$(asc_api GET "/v1/builds?filter[app]=$APP_ID&limit=1&sort=-uploadedDate" 2>/dev/null); then
      # Not `// "unanswered"`: jq's // also replaces false, and false ("uses
      # no non-exempt encryption") is the answer most apps give. Only null is
      # unanswered, and an app with no build yet has nothing to answer.
      NEC=$(echo "$BUILDS" | jq -r 'if (.data | length) == 0 then "none"
        else .data[0].attributes.usesNonExemptEncryption
          | if . == null then "unanswered" else tostring end end')
      if [ "$NEC" = unanswered ]; then
        echo "::warning::The most recent build has no export-compliance answer, which is what \"Missing Compliance\" in TestFlight means. Set ITSAppUsesNonExemptEncryption in Info.plist so no build ever waits for that question."
      fi
    fi

    # The agreements canary. Apple exposes no agreements endpoint, and an
    # outstanding one surfaces only as a 403 on a *write* — at upload or
    # submit time, after the build. So do a write that changes nothing: PATCH
    # the editable version's copyright to the value it already has.
    if [ "$PROBE_WRITE" = true ] && [ -n "${VERSIONS:-}" ]; then
      EDIT_ID=$(echo "$VERSIONS" | jq -r '[.data[]
        | select((.attributes.appVersionState // .attributes.appStoreState) == "PREPARE_FOR_SUBMISSION")][0].id // empty')
      COPYRIGHT=""
      [ -n "$EDIT_ID" ] && COPYRIGHT=$(echo "$VERSIONS" | jq -r --arg id "$EDIT_ID" \
        '[.data[] | select(.id == $id)][0].attributes.copyright // empty')
      if [ -n "$EDIT_ID" ] && [ -n "$COPYRIGHT" ]; then
        BODY=$(jq -n --arg id "$EDIT_ID" --arg c "$COPYRIGHT" \
          '{data: {type: "appStoreVersions", id: $id, attributes: {copyright: $c}}}')
        if asc_api PATCH "/v1/appStoreVersions/$EDIT_ID" "$BODY" > /dev/null; then
          echo "  write access proven (no-op copyright write accepted)"
        elif [ "${ASC_LAST_STATUS:-}" = 403 ]; then
          hold ios "App Store Connect refused a write with 403. The usual cause is an outstanding agreement: open https://appstoreconnect.apple.com/business (Business, then Agreements) and accept what is listed — only the Account Holder can. The other cause is an API key below App Manager. Raw: $ASC_LAST_ERROR"
        else
          echo "::warning::The no-op write probe failed ($ASC_LAST_ERROR), so write access is unproven. An upload may still stop on an agreement or a role."
        fi
      else
        echo "::notice::No editable version with a copyright to re-write, so write access was not proven this run."
      fi
    fi
  fi

  if [ "$IOS_OK" = true ]; then
    row iOS ready "track $IOS_TRACK"
  else
    row iOS "held back" "$IOS_REASON"
  fi
fi

# ───────────────────────────── Google Play ─────────────────────────────
if want android; then
  echo "=== Google Play ==="
  [ -n "$ANDROID_PACKAGE" ] || fatal "Android is in this run but ANDROID_PACKAGE is empty."
  [ -n "${GOOGLE_PLAY_JSON_KEY_PATH:-}" ] || fatal "GOOGLE_PLAY_JSON_KEY_PATH is not set."

  set +e
  PLAY_RESULT=$(ruby "$SCRIPT_DIR/play_check.rb" "$ANDROID_PACKAGE" 2>&1)
  PLAY_RC=$?
  set -e
  if [ "$PLAY_RC" -eq 2 ]; then
    fatal "Google Play would not issue an access token for the service account, so nothing can be uploaded: the key is malformed, disabled or deleted. Re-create it (skills/store-release/references/secrets.md, Google Play service account). Raw: $(echo "$PLAY_RESULT" | tr '\n' ' ')"
  fi
  LINE=$(echo "$PLAY_RESULT" | grep -E '^\{' | tail -1 || true)
  [ -n "$LINE" ] || fatal "play_check.rb printed no result: $(echo "$PLAY_RESULT" | tr '\n' ' ')"
  case "$(echo "$LINE" | jq -r .result)" in
    ok)
      TRACKS=$(echo "$LINE" | jq -r '(.tracks // []) | join(", ")')
      echo "  $ANDROID_PACKAGE: an edit opens; tracks with releases: ${TRACKS:-none}"
      if [ -n "$TRACKS" ] && ! echo "$LINE" | jq -e --arg t "$PLAY_TRACK" '(.tracks // []) | index($t)' > /dev/null; then
        echo "::notice::Track $PLAY_TRACK has no release yet on $ANDROID_PACKAGE. That is normal the first time it is used; the upload creates it."
      fi
      ;;
    blocked)
      hold android "$(echo "$LINE" | jq -r .reason)"
      ;;
    *)
      fatal "Google Play is not answering reliably, so the upload would fail after the build: $(echo "$LINE" | jq -r .reason)"
      ;;
  esac

  if [ "$ANDROID_OK" = true ]; then
    row Android ready "track $PLAY_TRACK"
  else
    row Android "held back" "$ANDROID_REASON"
  fi
fi

# ─────────────────────────────── Verdict ───────────────────────────────
{
  echo "### Release preflight for $VERSION"
  echo ""
  echo "| Platform | State | Detail |"
  echo "|---|---|---|"
  printf '%s' "$ROWS"
} >> "$GITHUB_STEP_SUMMARY"

{
  echo "ios_ok=$IOS_OK"
  echo "android_ok=$ANDROID_OK"
  echo "ios_reason=$(printf '%s' "$IOS_REASON" | tr '\n' ' ')"
  echo "android_reason=$(printf '%s' "$ANDROID_REASON" | tr '\n' ' ')"
} >> "$GITHUB_OUTPUT"

NOTHING=true
want ios && [ "$IOS_OK" = true ] && NOTHING=false
want android && [ "$ANDROID_OK" = true ] && NOTHING=false
if [ "$NOTHING" = true ]; then
  echo "blocked=true" >> "$GITHUB_OUTPUT"
  fatal "Every platform in this run is held back, so there is nothing to build. The warnings above say why."
fi
echo "blocked=false" >> "$GITHUB_OUTPUT"
