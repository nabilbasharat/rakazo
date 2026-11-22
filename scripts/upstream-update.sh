#!/usr/bin/env bash
# Run inside a dedicated task worktree. Files under git-path are worktree-local.
set -euo pipefail
state=$(git rev-parse --git-path cezar-upstream-update)
snapshot=$(git rev-parse --git-path cezar-upstream-update.sh)
read_state() {
  test -f "$state" || { echo 'Missing preflight state' >&2; return 1; }
  mapfile -t tips < "$state"
  test "${#tips[@]}" = 2 || { echo 'Invalid preflight state' >&2; return 1; }
  git cat-file -e "${tips[0]}^{commit}"
  git cat-file -e "${tips[1]}^{commit}"
}
case "${1:-}" in
  preflight)
    rm -f "$state" "$snapshot" "$(git rev-parse --git-path cezar-upstream-validation.sh)"
    test -z "$(git status --porcelain)" || { echo 'Worktree is not clean' >&2; exit 1; }
    branch=$(git symbolic-ref --quiet --short HEAD) || { echo 'Detached HEAD' >&2; exit 1; }
    test "$branch" != main || { echo 'Refusing to update main directly' >&2; exit 1; }
    timeout 120 git fetch origin main
    timeout 120 git fetch upstream main
    base=$(git rev-parse --verify 'refs/remotes/origin/main^{commit}')
    target=$(git rev-parse --verify 'refs/remotes/upstream/main^{commit}')
    test "$(git rev-parse HEAD)" = "$base" || { echo 'Task must start at the freshly fetched origin/main' >&2; exit 1; }
    git merge-base "$base" "$target" >/dev/null || { echo 'Branches have no common ancestor' >&2; exit 1; }
    git show HEAD:scripts/upstream-update.sh > "$snapshot"
    git show HEAD:scripts/upstream-validation.sh > "$(git rev-parse --git-path cezar-upstream-validation.sh)"
    printf '%s\n%s\n' "$base" "$target" > "$state"
    printf 'Upstream commits to integrate: '
    git rev-list --count "$base..$target"
    ;;
  current)
    read_state
    git merge-base --is-ancestor "${tips[1]}" HEAD
    ;;
  needed)
    read_state
    if git merge-base --is-ancestor "${tips[1]}" HEAD; then
      echo 'Upstream already integrated' >&2
      exit 1
    else
      result=$?
      test "$result" = 1 || exit "$result"
    fi
    ;;
  merge)
    read_state
    git merge --no-edit --no-ff "${tips[1]}"
    ;;
  conflict)
    test -f "$(git rev-parse --git-path MERGE_HEAD)" && test -n "$(git ls-files -u)"
    ;;
  verify)
    read_state
    test ! -f "$(git rev-parse --git-path MERGE_HEAD)"
    test -z "$(git status --porcelain)"
    git merge-base --is-ancestor "${tips[0]}" HEAD
    git merge-base --is-ancestor "${tips[1]}" HEAD
    git diff --check "${tips[0]}" HEAD
    ;;
  fresh)
    read_state
    timeout 120 git fetch origin main
    test "$(git rev-parse 'refs/remotes/origin/main^{commit}')" = "${tips[0]}" || { echo 'origin/main changed; start a new run' >&2; exit 1; }
    ;;
  *) echo 'Usage: upstream-update.sh preflight|current|needed|merge|conflict|verify|fresh' >&2; exit 2 ;;
esac
