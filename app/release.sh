#!/bin/bash

# Wealth Tracker Release Script
# Usage: ./release.sh [platform] [lane]
#
# Platforms: ios, android, all
# Lanes: beta, release, build
#
# Examples:
#   ./release.sh ios beta      # Upload iOS to TestFlight
#   ./release.sh android beta  # Upload Android to internal testing
#   ./release.sh all beta      # Upload both to beta channels
#   ./release.sh ios build     # Build iOS IPA locally
#   ./release.sh android build # Build Android APK/AAB locally
#
# Version is read from CHANGELOG.md (## Next: X.Y.Z heading).
# Build numbers are auto-generated:
#   Android: seconds since 2026-03-01 UTC
#   iOS: latest TestFlight build number + 1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_dependencies() {
    print_header "Checking Dependencies"

    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed"
        exit 1
    fi
    print_success "Flutter found: $(flutter --version | head -1)"

    # Check Fastlane
    if ! command -v fastlane &> /dev/null; then
        print_warning "Fastlane not found. Installing via gem..."
        gem install fastlane
    fi
    print_success "Fastlane found: $(fastlane --version | head -1)"

}

prepare_flutter() {
    print_header "Preparing Flutter"

    # Get dependencies
    flutter pub get
    print_success "Dependencies ready"
}

release_ios() {
    local LANE=$1
    print_header "Releasing iOS ($LANE)"

    cd ios
    fastlane "$LANE"
    cd ..
    print_success "iOS $LANE complete"
}

release_android() {
    local LANE=$1
    print_header "Releasing Android ($LANE)"

    cd android
    fastlane "$LANE"
    cd ..
    print_success "Android $LANE complete"
}

show_usage() {
    echo "Wealth Tracker Release Script"
    echo ""
    echo "Usage: $0 [platform] [lane]"
    echo ""
    echo "Platforms:"
    echo "  ios       Release for iOS only"
    echo "  android   Release for Android only"
    echo "  all       Release for both platforms"
    echo ""
    echo "Lanes:"
    echo "  beta      Upload to TestFlight (iOS) / Internal Testing (Android)"
    echo "  release   Upload to App Store / Play Store production"
    echo "  build     Build locally without uploading"
    echo ""
    echo "Examples:"
    echo "  $0 ios beta"
    echo "  $0 android release"
    echo "  $0 all beta"
    echo ""
    echo "Environment Variables:"
    echo "  APPLE_ID              Apple ID email for iOS releases"
    echo "  TEAM_ID               Apple Developer Team ID"
    echo "  ITC_TEAM_ID           App Store Connect Team ID"
    echo "  PLAY_STORE_JSON_KEY   Path to Google Play service account JSON"
    echo ""
}

# Main script
PLATFORM=${1:-}
LANE=${2:-beta}

if [ -z "$PLATFORM" ]; then
    show_usage
    exit 1
fi

case $PLATFORM in
    ios|android|all)
        ;;
    -h|--help|help)
        show_usage
        exit 0
        ;;
    *)
        print_error "Unknown platform: $PLATFORM"
        show_usage
        exit 1
        ;;
esac

case $LANE in
    beta|release|build)
        ;;
    *)
        print_error "Unknown lane: $LANE"
        show_usage
        exit 1
        ;;
esac

# Start release process
print_header "Wealth Tracker Release"
echo "Platform: $PLATFORM"
echo "Lane: $LANE"
echo ""

check_dependencies
prepare_flutter

case $PLATFORM in
    ios)
        release_ios "$LANE"
        ;;
    android)
        release_android "$LANE"
        ;;
    all)
        release_ios "$LANE"
        release_android "$LANE"
        ;;
esac

print_header "Release Complete"
print_success "All tasks completed successfully!"
echo ""
