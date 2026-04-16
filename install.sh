#!/bin/bash
# Linexin Launcher — Install / Uninstall script for Plasma 6
# Usage: ./install.sh [--uninstall]

set -euo pipefail

PLASMOID_ID="org.linexin.launcher"
TRANSLATION_DOMAIN="plasma_applet_${PLASMOID_ID}"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"
LOCALE_DIR="$HOME/.local/share/locale"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"
PO_DIR="$SCRIPT_DIR/po"

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling Linexin Launcher..."
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed $INSTALL_DIR"
    fi
    # Remove translation catalogs
    for mofile in "$LOCALE_DIR"/*/LC_MESSAGES/${TRANSLATION_DOMAIN}.mo; do
        if [[ -f "$mofile" ]]; then
            rm -f "$mofile"
            echo "Removed $mofile"
        fi
    done
    echo "Done. Restart Plasma to apply: kquitapp6 plasmashell && kstart plasmashell"
    exit 0
fi

echo "Installing Linexin Launcher..."

# Remove old installation
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Removing previous installation..."
    rm -rf "$INSTALL_DIR"
fi

# Copy package contents
mkdir -p "$INSTALL_DIR"
cp -r "$PACKAGE_DIR"/* "$INSTALL_DIR/"

# Compile and install translations
if [[ -d "$PO_DIR" ]] && command -v msgfmt &>/dev/null; then
    echo "Installing translations..."
    for pofile in "$PO_DIR"/*.po; do
        [[ -f "$pofile" ]] || continue
        lang="$(basename "$pofile" .po)"
        mo_dir="$LOCALE_DIR/$lang/LC_MESSAGES"
        mkdir -p "$mo_dir"
        msgfmt -o "$mo_dir/${TRANSLATION_DOMAIN}.mo" "$pofile"
        echo "  $lang"
    done
elif [[ -d "$PO_DIR" ]]; then
    echo "Warning: msgfmt not found. Install gettext to enable translations."
fi

echo "Installed to $INSTALL_DIR"
echo ""
echo "To apply changes, restart Plasma Shell:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
echo ""
echo "Then right-click your panel → Add Widgets → search 'Linexin Launcher'"
echo "Or replace your current Application Menu: right-click it → Show Alternatives → Linexin Launcher"
