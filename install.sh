#!/bin/bash
# Linexin Launcher — Install / Uninstall script for Plasma 6
# Usage: ./install.sh [--uninstall]

set -euo pipefail

PLASMOID_ID="org.linexin.launcher"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "Uninstalling Linexin Launcher..."
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "Removed $INSTALL_DIR"
    else
        echo "Not installed."
    fi
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

echo "Installed to $INSTALL_DIR"
echo ""
echo "To apply changes, restart Plasma Shell:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
echo ""
echo "Then right-click your panel → Add Widgets → search 'Linexin Launcher'"
echo "Or replace your current Application Menu: right-click it → Show Alternatives → Linexin Launcher"
