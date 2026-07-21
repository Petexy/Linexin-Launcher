# Linexin Launcher

A fully animated fullscreen plasmoid launcher for **KDE Plasma 6**, combining the best of macOS Launchpad aesthetics with the full functionality of Plasma's Application Dashboard.

## Features

- **Fullscreen overlay** — Takes over the screen like macOS Launchpad and GNOME Shell
- **Expressive, spring-driven animations** — Zoom-into-app launch, folders that spring open from their position with staggered glassy pop-in, lifted and shadowed icon dragging, staggered grid entrance, hover scale and press bounce — Material 3 Expressive in feel, and every timing is tunable
- **Animated folder editing** — Drop one icon on another and it arcs in on a shadowed flight while a glass plate swells beneath it and the new folder springs into being; existing folders gulp what they swallow, and pulling an app back out throws it to its new slot while the card recoils and the icons left behind close the gap
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
git clone https://github.com/Petexy/Linexin-Launcher
cd Linexin-Launcher
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
| Animation timings | Independent 0–1500ms sliders for open/close, app launch, icon entrance, hover effects, folder popup, moving icons, creating a folder, adding to a folder, and removing from a folder (0 = off) |
| Background opacity | 10–95% (default 40%) |
| Search scope | Optionally include bookmarks, files, and emails |

## License

GPL-3.0-or-later
