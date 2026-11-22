#!/usr/bin/env bash
# Exercises the actual systemd service boundary without downloading dependencies.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/upstream-validation.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/work tree" "$tmp/bin"
git -C "$tmp/work tree" init -q
node_bin=${NVM_DIR:-$HOME/.nvm}/versions/node/v24.15.0/bin/node
test -x "$node_bin" || { echo 'Test requires Node 24.15.0' >&2; exit 1; }
ln -s "$node_bin" "$tmp/bin/node"
cat > "$tmp/bin/npm" <<'MOCK'
#!/usr/bin/env bash
pwd -P >> ".test-cwd"
case " $* " in
  *' install '*) echo install >> ".test-cwd" ;;
  *' bash -c '*) echo checks >> ".test-cwd" ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$tmp/bin/npm"
cat > "$tmp/work tree/package.json" <<'JSON'
{"packageManager":"pnpm@12.18.0","engines":{"node":"^24.15.0 || >=26.0.0"}}
JSON
export PATH="$tmp/bin:$PATH"
cd "$tmp/work tree"
bash "$script" environment
bash "$script" prepare
bash "$script" checks
expected=$(pwd -P)
test "$(sed -n '1p' ".test-cwd")" = "$expected"
test "$(sed -n '2p' ".test-cwd")" = install
test "$(sed -n '3p' ".test-cwd")" = "$expected"
test "$(sed -n '4p' ".test-cwd")" = checks
echo 'upstream validation systemd working directory test passed'
