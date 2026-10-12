#!/usr/bin/env bash
set -euo pipefail
REVISION=fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --no-checkout --filter=blob:none https://github.com/ephread/inkgd.git "$TMP/upstream"
git -C "$TMP/upstream" checkout "$REVISION"
mkdir -p "$ROOT/addons"
cp -R "$TMP/upstream/addons/inkgd" "$ROOT/addons/inkgd"
echo "Installed inkgd ${REVISION}"
