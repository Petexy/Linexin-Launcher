# Linexin Launcher

A macOS Launchpad-inspired fullscreen application launcher for **KDE Plasma 6**, combining the best of macOS Launchpad aesthetics with the full functionality of Plasma's Application Dashboard.

## Features

- **Fullscreen overlay** — Takes over the screen like macOS Launchpad
- **Butter-smooth animations** — Scale + fade open/close, staggered grid entrance, hover scale effects, press bounce feedback
- **Application grid** — Browse all installed applications in a paginated grid
- **Category filtering** — Filter by application categories with animated pill buttons
- **Search** — Instant search with KRunner integration (apps, settings, bookmarks, files, calculator)
- **Favorites dock** — macOS-style dock at the bottom with drag & drop reordering
- **System actions** — Quick access to shutdown, reboot, logout, lock screen
- **Right-click menus** — Full context menus with "Add to Favorites", pin to activities, etc.
- **Keyboard navigation** — Full Tab/Arrow/Enter/Escape support
- **Configurable** — Animation speed, background opacity, icon sizes, and more

## Requirements

- KDE Plasma 6.0+
- Qt 6 / Qt Quick

## Installation

```bash
git clone https://github.com/petexy/LinexinLauncherPlasma.git
cd LinexinLauncherPlasma
./install.sh
```

Then restart Plasma Shell:
```bash
kquitapp6 plasmashell && kstart plasmashell
```

### Adding to your panel

1. Right-click your panel → **Add Widgets** → search "Linexin Launcher"
2. **Or** right-click your existing Application Menu → **Show Alternatives** → select **Linexin Launcher**

## Uninstallation

```bash
./install.sh --uninstall
```

## Configuration

Right-click the Linexin Launcher icon in your panel → **Configure**:

| Setting | Description |
|---------|-------------|
| Panel icon | Custom icon for the panel button |
| App name format | Name only, description, or both |
| Icon sizes | Separate controls for apps, favorites, system actions |
| Animation duration | 100–800ms (default 350ms) |
| Background opacity | 10–95% (default 40%) |
| Search scope | Optionally include bookmarks, files, and emails |

## Architecture

```
package/
├── metadata.json                 # Plasma widget metadata
└── contents/
    ├── config/
    │   ├── config.qml            # Config tab registration
    │   └── main.xml              # Configuration schema (defaults)
    └── ui/
        ├── main.qml              # Entry point (PlasmoidItem)
        ├── CompactRepresentation.qml  # Panel button
        ├── DashboardRepresentation.qml # Fullscreen overlay
        ├── ItemGridView.qml      # Grid view with animations
        ├── ItemGridDelegate.qml  # Grid item with hover/entrance fx
        ├── ItemListView.qml      # List view for sub-menus
        ├── ItemListDelegate.qml  # List item delegate
        ├── ActionMenu.qml        # Context menu component
        ├── ConfigGeneral.qml     # Settings UI
        └── code/
            └── tools.js          # Favorites/actions utilities
```

## License

GPL-2.0-or-later
