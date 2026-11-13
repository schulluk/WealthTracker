#!/usr/bin/env bash
# Release this app; see .github/store-release/release.sh --help.
exec "$(cd "$(dirname "$0")" && pwd)/.github/store-release/release.sh" "$@"
