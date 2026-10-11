#!/usr/bin/env bash
# Build patched wInd3x for this host, without accessing or flashing an iPod.
#
# Usage: release/build-wind3x.sh [--out ./wInd3x-nano7]
# Requires git, Go >= 1.23.3, a C compiler, pkg-config, and libusb development files.
# Set GO=/path/to/go to choose a toolchain.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="https://github.com/freemyipod/wInd3x.git"
# The bundled nano7 patch applies against this exact upstream revision.
COMMIT="7c7c4d83c8b923f29e7559585b2cdbbf4e028045"
OUT="$REPO/wInd3x-nano7"

fail() {
  echo "$*" >&2
  exit 1
}

# Only the output location is configurable; always build the pinned, patched source.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      if [[ $# -lt 2 ]]; then
        echo "--out needs a path" >&2
        exit 2
      fi
      OUT=$2
      shift 2
      ;;
    *)
      echo "usage: $0 [--out <binary>]" >&2
      exit 2
      ;;
  esac
done

# Honor an explicit GO override. Otherwise prefer the project-local toolchain
# installed on the host, falling back to the Go executable on PATH.
if [[ -z ${GO:-} ]]; then
  LOCAL_GO="$REPO/go-toolchain-1.23.3/go/bin/go"
  if [[ -x $LOCAL_GO ]]; then
    GO="$LOCAL_GO"
  else
    GO=go
  fi
fi

command -v git >/dev/null || fail "need git"
command -v "$GO" >/dev/null || fail "need Go >= 1.23.3; set GO=/path/to/go"

# Compare version components numerically, so 1.24 and later also pass.
# Older Go versions cannot parse this project's go.mod and toolchain directive.
version_is_supported() {
  local version=$1
  [[ $version =~ ^go([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || return 1

  local major=${BASH_REMATCH[1]}
  local minor=${BASH_REMATCH[2]}
  local patch=${BASH_REMATCH[3]}

  if (( major != 1 )); then
    (( major > 1 ))
  elif (( minor != 23 )); then
    (( minor > 23 ))
  else
    (( patch >= 3 ))
  fi
}

VERSION=$("$GO" env GOVERSION)
version_is_supported "$VERSION" ||
  fail "need Go >= 1.23.3; found $VERSION. Set GO=/path/to/newer/go"

# Resolve the output path before changing directories during the build.
mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

# Use a fresh temporary checkout to avoid touching the installer's build cache.
# Clean up the checkout on both successful builds and failures.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/wind3x-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

echo ">> building patched wInd3x @ ${COMMIT:0:12} ($VERSION)"
git clone -q "$UPSTREAM" "$WORK/src"
git -C "$WORK/src" checkout -q "$COMMIT"
# Copy the patch from nano7-untethered instead of maintaining a duplicate here.
bash "$REPO/release/copy-wind3x-patch.sh" "$WORK/wind3x-nano7.patch"
git -C "$WORK/src" apply "$WORK/wind3x-nano7.patch"

# Compile for the current host's architecture (ARM64 on the Pi).
(
  cd "$WORK/src"
  "$GO" build -trimpath -o "$WORK/wInd3x" ./cmd/wInd3x
)

# Inspect help only: this does not connect to an iPod or run a restore.
# Publish the binary only after confirming the patch added --firmware.
HELP=$("$WORK/wInd3x" restore --help)
[[ $HELP == *--firmware* ]] || fail "built binary lacks --firmware"
cp "$WORK/wInd3x" "$OUT"
chmod +x "$OUT"
echo ">> built $OUT"
