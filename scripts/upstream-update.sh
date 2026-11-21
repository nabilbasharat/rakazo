#!/usr/bin/env bash
# Run only inside the Cezar task worktree. State is private to this worktree.
set -euo pipefail
state=$(git rev-parse --git-path cezar-upstream-update)
case "${1:-}" in
  preflight)
    test -z "$(git status --porcelain)" || { echo 'Worktree is not clean' >&2; exit 1; }
    test -z "$(git ls-files -u)" || exit 1
    test "$(git branch --show-current)" != main || { echo 'Refusing to update main directly' >&2; exit 1; }
    timeout 120 git fetch origin main
    timeout 120 git fetch upstream main
    base=$(git rev-parse refs/remotes/origin/main)
    target=$(git rev-parse refs/remotes/upstream/main)
    test "$(git rev-parse HEAD)" = "$base" || { echo 'Task must start at the freshly fetched origin/main' >&2; exit 1; }
    printf '%s\n%s\n' "$base" "$target" > "$state"
    git log --oneline "$base..$target"
    ;;
  needed)
    test -f "$state"
    target=$(sed -n '2p' "$state")
    ! git merge-base --is-ancestor "$target" HEAD
    ;;
  merge)
    test -f "$state"
    target=$(sed -n '2p' "$state")
    git merge --no-edit --no-ff "$target"
    ;;
  conflict)
    test -f "$(git rev-parse --git-path MERGE_HEAD)" && test -n "$(git ls-files -u)"
    ;;
  verify)
    test -f "$state"
    base=$(sed -n '1p' "$state")
    target=$(sed -n '2p' "$state")
    test ! -f "$(git rev-parse --git-path MERGE_HEAD)"
    test -z "$(git status --porcelain)"
    git merge-base --is-ancestor "$base" HEAD
    git merge-base --is-ancestor "$target" HEAD
    git diff --check "$base" HEAD
    ;;
  *) echo 'Usage: upstream-update.sh preflight|needed|merge|conflict|verify' >&2; exit 2 ;;
esac
