#!/bin/bash
# Build a .plasmoid package for KDE Store distribution
# Compiles translations and bundles everything into a single installable file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"
PO_DIR="$SCRIPT_DIR/po"
TRANSLATION_DOMAIN="plasma_applet_org.linexin.launcher"

VERSION=$(grep -oP '"Version":\s*"\K[^"]+' "$PACKAGE_DIR/metadata.json")
OUTPUT="$SCRIPT_DIR/linexin-launcher-${VERSION}.plasmoid"

echo "Building Linexin Launcher v${VERSION}..."

# Create a temp staging directory
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

# Copy package contents
cp -r "$PACKAGE_DIR"/* "$STAGING/"

# Compile and embed translations
if [[ -d "$PO_DIR" ]] && command -v msgfmt &>/dev/null; then
    echo "Compiling translations..."
    for pofile in "$PO_DIR"/*.po; do
        [[ -f "$pofile" ]] || continue
        lang="$(basename "$pofile" .po)"
        mo_dir="$STAGING/contents/locale/$lang/LC_MESSAGES"
        mkdir -p "$mo_dir"
        msgfmt -o "$mo_dir/${TRANSLATION_DOMAIN}.mo" "$pofile"
        echo "  $lang"
    done
elif [[ -d "$PO_DIR" ]]; then
    echo "Warning: msgfmt not found. Install gettext to include translations."
fi

# Build the .plasmoid zip
rm -f "$OUTPUT"
(cd "$STAGING" && zip -r "$OUTPUT" .)

echo ""
echo "Built: $OUTPUT"
echo "Upload this file to store.kde.org"
