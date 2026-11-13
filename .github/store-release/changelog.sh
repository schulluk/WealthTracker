#!/usr/bin/env bash
# The changelog side of a release, around changelog.rb next to it.
#
#   changelog.sh plan      outputs version, mode and notes for this run
#   changelog.sh release   "## Next" becomes "## X.Y.Z (date)", the built commit
#                          is tagged vX.Y.Z, both are pushed
#
# plan: BUMP (minor | patch | major). On a runner dispatched on a vX.Y.Z tag
# it repeats that release: same version, same notes (mode repeat).
# release: VERSION, RELEASED_REF (the commit that was built). Only what that
# commit's "## Next" held moves into the version; lines added while the
# release ran stay under "## Next". Works in a throwaway worktree, so the
# checkout it runs from is never touched (on a Mac that is someone's working
# copy).
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sr_config
CHANGELOG="$SR_CHANGELOG"
cl() { ruby "$SR_DIR/changelog.rb" "$@"; }

cmd_plan() {
  local bump="${BUMP:-minor}" mode version notes
  if [ "${GITHUB_REF_TYPE:-}" = tag ] && [[ "${GITHUB_REF_NAME:-}" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    # The tag's commit still has the "## Next" that shipped as this version,
    # so its notes come out exactly as they did then.
    mode=repeat
    version="${BASH_REMATCH[1]}"
  else
    mode=new
    cl check --changelog "$SR_ROOT/$CHANGELOG"
    version=$(cl version --changelog "$SR_ROOT/$CHANGELOG" --bump "$bump")
    if git -C "$SR_ROOT" rev-parse -q --verify "refs/tags/v$version" > /dev/null; then
      sr_die "The tag v$version exists, but $CHANGELOG has no '## $version'. To repeat that release, dispatch the workflow on the tag; otherwise add the missing section."
    fi
  fi
  notes=$(cl notes --changelog "$SR_ROOT/$CHANGELOG" --store "$SR_ROOT/$SR_STORE")
  sr_out version "$version"
  sr_out mode "$mode"
  sr_out notes "$notes"
  if [ "$mode" = repeat ]; then
    echo "::notice::Repeating $version from $GITHUB_REF_NAME."
  else
    echo "::notice::## Next ships as $version ($bump)."
  fi
  {
    echo "### Release $version"
    echo ""
    if [ "$mode" = repeat ]; then
      echo "Repeat of \`$GITHUB_REF_NAME\`."
    else
      echo "\`## Next\` in \`$CHANGELOG\`, counted as a $bump step."
    fi
    echo ""
    echo "Release notes (${#notes} characters):"
    echo ""
    echo '```'
    echo "$notes"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
}

cmd_release() {
  : "${VERSION:?VERSION is not set}"
  : "${RELEASED_REF:?RELEASED_REF is not set}"
  local work="$RUNNER_TEMP/changelog-release" attempt
  local who=()
  sr_ci && who=(-c "user.name=github-actions[bot]" -c "user.email=41898282+github-actions[bot]@users.noreply.github.com")
  cd "$SR_ROOT"
  # main may have moved while the release ran; start over from it and try
  # again if someone pushes in between.
  for attempt in 1 2 3; do
    git fetch --quiet origin main
    git worktree remove --force "$work" 2> /dev/null || true
    git worktree add --quiet --detach "$work" origin/main
    ( cd "$work"
      cl release --changelog "$work/$CHANGELOG" --version "$VERSION" --released-ref "$RELEASED_REF"
      git add "$CHANGELOG"
      git ${who[@]+"${who[@]}"} commit --quiet -m "Changelog: $VERSION went to review"
      git tag -f "v$VERSION" "$RELEASED_REF" > /dev/null )
    if git -C "$work" push --atomic origin HEAD:refs/heads/main "refs/tags/v$VERSION"; then
      git worktree remove --force "$work"
      echo "::notice::$CHANGELOG: ## Next is now ## $VERSION, and $(git rev-parse --short "$RELEASED_REF") is tagged v$VERSION."
      return 0
    fi
    echo "Push refused (attempt $attempt of 3); main moved, starting over."
    sleep $((attempt * 5))
  done
  git worktree remove --force "$work" 2> /dev/null || true
  sr_die "Could not push the changelog update. The stores have $VERSION; turn '## Next' into '## $VERSION' by hand (changelog.rb release --version $VERSION) and tag $RELEASED_REF as v$VERSION."
}

case "${1:-}" in
  plan | release) "cmd_$1" ;;
  *) echo "usage: changelog.sh plan|release" >&2; exit 2 ;;
esac
