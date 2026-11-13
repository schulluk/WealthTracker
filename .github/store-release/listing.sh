#!/usr/bin/env bash
# The store listing, one command per store. The listing workflow runs these on
# a runner; release.sh listing --local runs the same ones on a Mac.
#
#   listing.sh ios        App Store Connect: name, subtitle, keywords,
#                         promotional text, description, URLs, copyright
#   listing.sh android    Google Play: title, short and full description
#   listing.sh summary    the result, as a table (LISTING_IOS, LISTING_ANDROID:
#                         what the two steps output)
#
# The texts come from the app's listing/<language>.md (listing.py), screenshots from
# store.yml's listing.screenshots folders when SCREENSHOTS=true. Never What's
# New, the review contact or the release type: those belong to the release.
#
# Run: DRY_RUN (verify / validate only, nothing changes), SCREENSHOTS,
# VERSION (the App Store version to edit; empty takes the one ## Next counts
# to), PLAY_TRACK (a track that has a build: Play looks one up even for a
# listing; default internal). Credentials as in ios.sh and android.sh.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sr_config
DRY_RUN="${DRY_RUN:-false}"
SCREENSHOTS="${SCREENSHOTS:-false}"
PLAY_TRACK="${PLAY_TRACK:-internal}"
APP_DIR="$SR_ROOT"
[ "$SR_APP_DIR" = . ] || APP_DIR="$SR_ROOT/$SR_APP_DIR"
WORK="$RUNNER_TEMP/listing"

build_tree() { # STORE
  rm -rf "${WORK:?}/$1"
  ( cd "$APP_DIR" && python3 "$SR_DIR/listing.py" "$WORK" "$1" )
}

cmd_ios() {
  [ "$SR_IOS" = true ] || sr_die "store.yml has no ios section."
  mkdir -p "$WORK"
  build_tree ios
  local version="${VERSION:-}" shots=() log="$RUNNER_TEMP/listing-ios.log" rc count
  if [ -z "$version" ]; then
    # The version the next release ships as. deliver edits it, and creates it
    # when App Store Connect has no such version yet, as a release would.
    version=$(ruby "$SR_DIR/changelog.rb" version --changelog "$SR_ROOT/$SR_CHANGELOG" 2> /dev/null || true)
  fi
  if [ "$SCREENSHOTS" = true ]; then
    [ -n "$SR_LISTING_SCREENSHOTS_IOS" ] && [ -d "$APP_DIR/$SR_LISTING_SCREENSHOTS_IOS" ] \
      || sr_die "No App Store screenshots: store.yml listing.screenshots.ios names a folder in deliver's layout (<locale>/*.png)."
    count=$(find "$APP_DIR/$SR_LISTING_SCREENSHOTS_IOS" -name '*.png' | wc -l | tr -d ' ')
    echo "Screenshots: $count from $SR_LISTING_SCREENSHOTS_IOS"
    shots=(--skip_screenshots false --screenshots_path "$APP_DIR/$SR_LISTING_SCREENSHOTS_IOS" --overwrite_screenshots true)
  else
    shots=(--skip_screenshots true)
  fi
  if [ "$DRY_RUN" = true ]; then
    # deliver's --verify_only checks a binary, not metadata, so a dry run
    # stops at the local checks above and sends nothing to Apple.
    echo "::notice::Dry run: the App Store listing for ${version:-the version being edited} is checked here; nothing was sent to App Store Connect."
    sr_out ios verified
    return 0
  fi
  sr_asc_key
  echo "App Store version ${version:-(the one being edited)}"
  # In the tree: deliver without a binary asks whether to set itself up unless
  # it finds fastlane/metadata in the working directory.
  set +e
  ( cd "$WORK/ios" && fastlane deliver \
      --api_key_path "$RUNNER_TEMP/asc-key.json" \
      --app_identifier "$SR_IOS_BUNDLE_ID" \
      ${version:+--app_version "$version"} \
      --metadata_path fastlane/metadata \
      --skip_binary_upload true \
      "${shots[@]}" \
      --submit_for_review false \
      --run_precheck_before_submit false \
      --precheck_include_in_app_purchases false \
      --force true ) 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ]; then
    sr_explain ios "$log"
    exit "$rc"
  fi
  sr_out ios uploaded
}

cmd_android() {
  [ "$SR_ANDROID" = true ] || sr_die "store.yml has no android section."
  mkdir -p "$WORK"
  build_tree android
  local tree="$WORK/android/metadata" key log="$RUNNER_TEMP/listing-android.log" result=""
  local shots=(--skip_upload_screenshots true)
  if [ "$SCREENSHOTS" = true ]; then
    local src="$APP_DIR/$SR_LISTING_SCREENSHOTS_ANDROID" dir locale
    [ -n "$SR_LISTING_SCREENSHOTS_ANDROID" ] && [ -d "$src" ] \
      || sr_die "No Play screenshots: store.yml listing.screenshots.android names a folder in supply's layout (<locale>/images/phoneScreenshots/*.png)."
    for dir in "$src"/*/images; do
      [ -d "$dir" ] || continue
      locale=$(basename "$(dirname "$dir")")
      mkdir -p "$tree/$locale/images"
      cp -R "$dir"/*Screenshots "$tree/$locale/images/" 2> /dev/null || true
    done
    shots=(--skip_upload_screenshots false)
  fi
  if [ -n "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
    key="$RUNNER_TEMP/play-service-account.json"
    ( umask 077; printf '%s' "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" > "$key" )
  else
    key="${GOOGLE_PLAY_JSON_KEY_PATH:?No Play service-account key}"
  fi
  # Play looks up a release on the track even for a listing, and refuses to
  # guess when the track holds several, so name the newest build there.
  local code
  code=$(FASTLANE_DISABLE_COLORS=1 FASTLANE_SKIP_UPDATE_CHECK=1 fastlane run google_play_track_version_codes \
      package_name:"$SR_ANDROID_PACKAGE" track:"$PLAY_TRACK" json_key:"$key" 2>&1 \
    | sed -e 's/\x1b\[[0-9;]*m//g' -n -e 's/.*Result: \[\(.*\)\].*/\1/p' | tail -1 \
    | tr -s ', ' '\n\n' | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
  [ -n "$code" ] || sr_die "Play has no build on the $PLAY_TRACK track, and a listing upload needs one to attach to: upload a build there first, or set PLAY_TRACK to a track that has one."
  echo "Attaching to versionCode $code on the $PLAY_TRACK track."
  supply() {
    # Images (icon, feature graphic) are left alone.
    fastlane supply \
      --package_name "$SR_ANDROID_PACKAGE" \
      --json_key "$key" \
      --metadata_path "$tree" \
      --track "$PLAY_TRACK" \
      --version_code "$code" \
      --skip_upload_aab true \
      --skip_upload_apk true \
      --skip_upload_changelogs true \
      --skip_upload_images true \
      "${shots[@]}" \
      --rescue_changes_not_sent_for_review false \
      "$@" 2>&1 | tee -a "$log"
    return "${PIPESTATUS[0]}"
  }
  set +e
  if [ "$DRY_RUN" = true ]; then
    supply --validate_only true && result=validated
  elif supply; then
    result=uploaded
  elif grep -q 'changesNotSentForReview' "$log"; then
    # After a rejection Play takes changes for review only from the Console.
    supply --changes_not_sent_for_review true && result=held
  fi
  set -e
  rm -f "$RUNNER_TEMP/play-service-account.json"
  if [ -z "$result" ]; then
    sr_explain android "$log"
    exit 1
  fi
  sr_out android "$result"
}

cmd_summary() {
  local store text result
  {
    echo "### Store listing"
    echo ""
    echo "| | |"
    echo "|---|---|"
    for store in ios android; do
      [ "$store" = ios ] && result="${LISTING_IOS:-}" || result="${LISTING_ANDROID:-}"
      case "$store:$result" in
        *:verified) text="dry run: every field checked here, nothing sent" ;;
        *:validated) text="dry run: Play validated the listing, nothing was committed" ;;
        ios:uploaded) text="uploaded to the App Store version" ;;
        android:uploaded) text="uploaded and sent for review" ;;
        *:held) text="**uploaded but not sent**: Play takes this app's changes for review only from the Console" ;;
        *:) continue ;;
        *) text="did not finish" ;;
      esac
      echo "| $([ "$store" = ios ] && echo "App Store" || echo "Google Play") | $text |"
    done
  } >> "$GITHUB_STEP_SUMMARY"
}

case "${1:-}" in
  ios | android | summary) "cmd_$1" ;;
  *) echo "usage: listing.sh ios|android|summary" >&2; exit 2 ;;
esac
