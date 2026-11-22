#!/usr/bin/env bash
set -euo pipefail
source_script=$(cd "$(dirname "$0")" && pwd)/upstream-update.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/fork"
cd "$tmp/fork"
git checkout -q -b main
mkdir scripts
cp "$source_script" scripts/upstream-update.sh
cp "$(dirname "$source_script")/upstream-validation.sh" scripts/upstream-validation.sh
echo base > file
git add .
git commit -qm base
git push -q origin main
git clone -q --bare "$tmp/origin.git" "$tmp/upstream.git"
git remote add upstream "$tmp/upstream.git"
git checkout -qb task
bash scripts/upstream-update.sh preflight >/dev/null
snapshot=$(git rev-parse --git-path cezar-upstream-update.sh)
validation=$(git rev-parse --git-path cezar-upstream-validation.sh)
check_status=$(git rev-parse --git-path cezar-upstream-check-status)
test -f "$validation"
if bash "$validation" repairable; then echo 'Missing status must not be repairable' >&2; exit 1; fi
echo infrastructure-failure > "$check_status"
if bash "$validation" repairable; then echo 'Infrastructure failure must not be repairable' >&2; exit 1; fi
echo test-failure > "$check_status"
bash "$validation" repairable
bash "$snapshot" current
if bash "$snapshot" needed 2>/dev/null; then echo 'Expected no update' >&2; exit 1; fi
git clone -q -b main "$tmp/upstream.git" "$tmp/upstream-work"
cd "$tmp/upstream-work"
echo update >> file
git commit -qam update
git push -q origin main
cd "$tmp/fork"
bash scripts/upstream-update.sh preflight >/dev/null
if bash "$snapshot" current; then echo 'Expected an update' >&2; exit 1; fi
bash "$snapshot" needed
bash "$snapshot" merge >/dev/null
bash "$snapshot" verify
bash "$snapshot" fresh
git push -q origin HEAD:main
if bash "$snapshot" fresh 2>/dev/null; then echo 'Expected stale base failure' >&2; exit 1; fi
rm "$(git rev-parse --git-path cezar-upstream-update)"
if bash "$snapshot" needed 2>/dev/null; then echo 'Expected missing state failure' >&2; exit 1; fi
echo 'upstream-update tests passed'
