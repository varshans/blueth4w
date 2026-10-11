#!/usr/bin/env bash
# Copy the wInd3x patch from the pinned nano7-untethered revision.
# Usage: bash release/copy-wind3x-patch.sh <destination>
set -euo pipefail

[[ $# == 1 ]] || { echo "usage: $0 <destination>" >&2; exit 2; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMMIT="7a0f097650f50cf2fbd244984e340db8c04827e3"
SOURCE="$REPO/.build/nano7-untethered"
PATCH_PATH="untether/patches/wind3x-nano7.patch"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/wind3x-patch.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Reuse build.sh's checkout when available. Otherwise fetch a temporary copy,
# so this also works on a host that has never built the firmware itself.
if ! git -C "$SOURCE" cat-file -e "$COMMIT:$PATCH_PATH" 2>/dev/null; then
  SOURCE="$WORK/nano7-untethered"
  git clone -q https://github.com/olievans123/nano7-untethered.git "$SOURCE"
fi

# Read the committed file, ignoring any local edits to the upstream checkout.
git -C "$SOURCE" show "$COMMIT:$PATCH_PATH" > "$WORK/wind3x-nano7.patch"
cp "$WORK/wind3x-nano7.patch" "$1"
