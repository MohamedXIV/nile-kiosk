#!/usr/bin/env bash
set -euo pipefail
# Dialogue Manager v3.10.4, pinned to Godot 4.6-compatible commit.
REVISION=5487c524b9eac303b059e5859e2980b134c59d79
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --no-checkout --filter=blob:none https://github.com/nathanhoad/godot_dialogue_manager.git "$TMP/upstream"
git -C "$TMP/upstream" checkout "$REVISION"
mkdir -p "$ROOT/addons"
cp -R "$TMP/upstream/addons/dialogue_manager" "$ROOT/addons/dialogue_manager"
echo "Installed Dialogue Manager ${REVISION}; now open/import the Godot project."
