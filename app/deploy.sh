#!/bin/bash
# Usage:
#   ./deploy.sh              # beta (build + upload to testing)
#   ./deploy.sh beta         # same as above
#   ./deploy.sh submit       # submit latest testing build for production review
#   ./deploy.sh metadata     # sync METADATA.md and upload to both stores
#   ./deploy.sh [any lane]   # run any fastlane lane on both platforms

LANE="${1:-beta}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_OK=0
ANDROID_OK=0

echo "=== iOS: fastlane $LANE ==="
(cd "$SCRIPT_DIR/ios" && fastlane "$LANE") && IOS_OK=1

echo ""
echo "=== Android: fastlane $LANE ==="
(cd "$SCRIPT_DIR/android" && fastlane "$LANE") && ANDROID_OK=1

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

if [ $IOS_OK -eq 0 ] || [ $ANDROID_OK -eq 0 ]; then
  exit 1
fi
