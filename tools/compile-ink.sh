#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${INKLECATE:?Set INKLECATE to the pinned inklecate binary path}"
for source in "$ROOT"/content/ink/*.ink; do
  "$INKLECATE" -o "${source}.json" "$source"
done
echo "Compiled Ink source files with ${INKLECATE}"
