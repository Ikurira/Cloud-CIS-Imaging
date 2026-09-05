#!/usr/bin/env bash
# Packages hardening-content into the artifact shapes the pipeline expects
# (see CONTRACT.md and infra/terraform/modules/image-builder-*/component.yaml.tftpl,
# which extract these archives expecting the OS folder name at the top level).
#
# Usage: ./package.sh <version> [dest_dir]
#   ./package.sh 1.0.0
#
# Output:
#   dist/rhel9-cis-<version>.tar.gz        (top-level folder: rhel9-cis/)
#   dist/windows2025-cis-<version>.zip     (top-level folder: windows2025-cis/)
#
# Uploading + updating the pointer parameters is intentionally a separate,
# explicit step (not part of this script) — see the "Releasing" section in
# README.md. This script only produces the artifacts.

set -euo pipefail

VERSION="${1:?Usage: package.sh <version> [dest_dir]}"
DEST="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dist}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$DEST"

echo "Packaging rhel9-cis..."
tar -C "$ROOT" -czf "$DEST/rhel9-cis-${VERSION}.tar.gz" rhel9-cis

echo "Packaging windows-server-2025-cis..."
TMP_ZIP_ROOT="$(mktemp -d)"
cp -r "$ROOT/windows-server-2025-cis" "$TMP_ZIP_ROOT/windows2025-cis"
(cd "$TMP_ZIP_ROOT" && zip -qr "$DEST/windows2025-cis-${VERSION}.zip" windows2025-cis)
rm -rf "$TMP_ZIP_ROOT"

echo "Done:"
echo "  $DEST/rhel9-cis-${VERSION}.tar.gz"
echo "  $DEST/windows2025-cis-${VERSION}.zip"
