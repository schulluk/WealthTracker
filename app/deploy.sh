#!/bin/bash
# Usage:
#   ./deploy.sh              # beta (build + upload to testing)
#   ./deploy.sh beta         # same as above
#   ./deploy.sh submit       # submit latest testing build for production review
#   ./deploy.sh metadata     # sync METADATA.md and upload to both stores
#   ./deploy.sh [any lane]   # run any fastlane lane on both platforms

LANE="${1:-beta}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Deliberately no Gemfile: Homebrew's fastlane bottle ships its own vendored
# Ruby, which is isolation enough for a solo local setup. This silences the
# "Get started using a Gemfile" hint.
export SKIP_SLOW_FASTLANE_WARNING=1
IOS_OK=0
ANDROID_OK=0

# The same script the CI release uses: "## Next" in CHANGELOG.md ships as the
# newest "## X.Y.Z" plus one minor. Read before the lanes run, because a
# successful submit turns "## Next" into that version at the end.
CHANGELOG_RB="$SCRIPT_DIR/../.github/actions/changelog/changelog.rb"
VERSION=$(ruby "$CHANGELOG_RB" version --changelog "$SCRIPT_DIR/CHANGELOG.md") || exit 1
echo "=== CHANGELOG: ## Next ships as $VERSION ==="

echo "=== iOS: fastlane $LANE ==="
(cd "$SCRIPT_DIR/ios" && fastlane "$LANE") && IOS_OK=1

echo ""
echo "=== Android: fastlane $LANE ==="
(cd "$SCRIPT_DIR/android" && fastlane "$LANE") && ANDROID_OK=1

# Always sync metadata after beta builds so store listings stay current.
if [ "$LANE" = "beta" ]; then
  echo ""
  echo "=== Syncing metadata ==="
  (cd "$SCRIPT_DIR/ios" && fastlane metadata) || true
  (cd "$SCRIPT_DIR/android" && fastlane metadata) || true
fi

echo ""
echo "==============================="
echo "  SUMMARY: deploy $LANE"
echo "==============================="
if [ $IOS_OK -eq 1 ]; then
  echo "  iOS:     OK"
else
  echo "  iOS:     FAILED"
fi
if [ $ANDROID_OK -eq 1 ]; then
  echo "  Android: OK"
else
  echo "  Android: FAILED"
fi
echo "==============================="

# After a fully successful submit, "## Next" becomes "## $VERSION (date)" and
# a fresh, empty "## Next" opens above it. Commit and tag (v$VERSION) by hand.
if [ "$LANE" = "submit" ] && [ $IOS_OK -eq 1 ] && [ $ANDROID_OK -eq 1 ]; then
  echo ""
  echo "=== CHANGELOG.md: ## Next released as $VERSION ==="
  ruby "$CHANGELOG_RB" release --changelog "$SCRIPT_DIR/CHANGELOG.md" --version "$VERSION"
fi

if [ $IOS_OK -eq 0 ] || [ $ANDROID_OK -eq 0 ]; then
  exit 1
fi
