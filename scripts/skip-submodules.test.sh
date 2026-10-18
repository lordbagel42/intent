#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_ALLOW_PROTOCOL=file
git init -q "$tmp/child"
git -C "$tmp/child" -c user.name=Test -c user.email=test@example.com commit -qm initial --allow-empty
mkdir -p "$tmp/repo"
cp "$root/Makefile" "$tmp/repo/Makefile"
git init -q "$tmp/repo"
for name in intentd cloudlands-fe ios; do
  git -C "$tmp/repo" submodule add -q "$tmp/child" "packages/$name"
done
git -C "$tmp/repo" -c user.name=Test -c user.email=test@example.com commit -qm modules
git -C "$tmp/repo" submodule --quiet deinit --force --all

make -s -C "$tmp/repo" SKIP_SUBMODULES=1 ensure-submodules ensure-intentd-submodule ensure-fe-submodule ensure-ios-submodule
for name in intentd cloudlands-fe ios; do
  if [[ -e "$tmp/repo/packages/$name/.git" ]]; then
    echo "FAIL: opt-out initialized $name" >&2
    exit 1
  fi
done

make -s -C "$tmp/repo" ensure-submodules
for name in intentd cloudlands-fe ios; do
  test -e "$tmp/repo/packages/$name/.git"
done

# Explicit manual Git initialization is unaffected by the environment option.
git -C "$tmp/repo" submodule --quiet deinit --force --all
SKIP_SUBMODULES=1 git -C "$tmp/repo" submodule update --init --recursive
test -e "$tmp/repo/packages/intentd/.git"
echo 'skip-submodules tests passed'
