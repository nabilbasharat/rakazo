#!/usr/bin/env bash
# Trusted copy from the starting commit; run only in the task worktree.
set -euo pipefail
status=$(git rev-parse --git-path cezar-upstream-check-status)
fail() { echo "$*" >&2; exit 1; }
case "${1:-}" in
  environment)
    for cmd in node npm python3 systemd-run taskset timeout; do
      command -v "$cmd" >/dev/null || fail "Required command missing: $cmd"
    done
    node - <<'NODE'
const { engines, packageManager } = require('./package.json');
const [major, minor] = process.versions.node.split('.').map(Number);
if (engines?.node !== '^24.15.0 || >=26.0.0') {
  console.error('Node engine requirement changed; update the upstream validation script.');
  process.exit(1);
}
if (!((major === 24 && minor >= 15) || major >= 26)) {
  console.error(`Unsupported Node ${process.versions.node}; required: ${engines.node}`);
  process.exit(1);
}
if (!/^pnpm@\d+\.\d+\.\d+$/.test(packageManager ?? '')) {
  console.error('packageManager must specify an exact pnpm version.');
  process.exit(1);
}
NODE
    timeout 20 systemd-run --user --quiet --wait --pipe --collect \
      -p MemoryMax=3000M -p MemorySwapMax=0 -p CPUQuota=200% true || fail 'Cannot create a resource-limited user service'
    python3 -c 'import os; assert len(os.sched_getaffinity(0)) >= 1' || fail 'CPU affinity unavailable'
    ;;
  prepare|checks)
    # CPU affinity and cgroup limits apply to the whole command and its descendants.
    cpus=$(python3 -c 'import os; print(",".join(map(str, sorted(os.sched_getaffinity(0))[:2])))')
    manager=$(node -p 'require("./package.json").packageManager')
    rm -f "$status"
    if [ "$1" = prepare ]; then
      command=(npm exec --yes --package="$manager" -- pnpm install --frozen-lockfile --child-concurrency=1 --network-concurrency=2)
    else
      command=(npm exec --yes --package="$manager" -- bash -c 'set -e; pnpm lint; pnpm exec turbo check --concurrency=1; pnpm exec node --test --test-concurrency=1 scripts/pnpm.test.mjs scripts/setup-worktree.test.mjs; pnpm exec vitest run --maxWorkers=1')
    fi
    # A service killed by its cgroup cannot write a completion marker.
    echo infrastructure-failure > "$status"
    set +e
    timeout --kill-after=30 1860 systemd-run --user --quiet --wait --pipe --collect \
      -p MemoryMax=3000M -p MemorySwapMax=0 -p CPUQuota=200% -p RuntimeMaxSec=1800 \
      taskset -c "$cpus" bash -c '
        status=$1; shift
        "$@"; result=$?
        case "$result" in 0) echo success > "$status" ;; 1) echo test-failure > "$status" ;; *) echo infrastructure-failure > "$status" ;; esac
        exit "$result"
      ' bash "$status" "${command[@]}"
    result=$?
    set -e
    exit "$result"
    ;;
  repairable)
    test -f "$status" && test "$(cat "$status")" = test-failure
    ;;
  *) fail 'Usage: upstream-validation.sh environment|prepare|checks|repairable' ;;
esac
