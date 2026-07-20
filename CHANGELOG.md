# Changelog

## 1.1.1

### Fixed

- **Dashboard-pinned apps now launch through KDE's native application launcher.** Pinned apps were started with `gtk-launch`, a separate code path from the Recent Apps view (which uses the Kicker model's `trigger()` / `ApplicationLauncherJob`). Because `gtk-launch` did not execute the `.desktop` entry the way KDE does, fixed `Exec` arguments could be dropped or mishandled — e.g. AppImages that require `--no-sandbox` (such as Wootility) failed to start from the Dashboard while launching fine from Recent Apps. The Dashboard now launches via `kstart --application`, matching the Recent Apps path, so the full `Exec` line and each app's `StartupWMClass` / single-instance handling are honoured. As a bonus this drops the GTK dependency in favour of the Plasma-provided `kstart`.

## 1.1.0

### Added

- **Recent Apps & Recent Files view** — the "Recent Apps" and "Recent Files" categories now open a dedicated view instead of the standard application grid. Recent apps render as a centred hero grid with icons scaled to the number of entries; recent files render as a list of rows showing the file name and its parent folder (with `~` shorthand for your home directory), switching to two columns past 8 entries.
- **Item counter** in the recent view header, next to the title.
- **Clear History button** — two-step confirmation ("Click again to confirm") before forgetting the usage history, since the action cannot be undone. It disarms automatically when you switch tabs or leave the view.
- **Empty states** for both recent tabs ("Files you open will show up here" / "Apps you launch will show up here").
- **Right-click context menus** on recent files, with the full set of actions the model provides.
- Six new translatable strings; `.pot` regenerated.

### Changed

- **Shared-Z-axis transitions.** Entering search now raises the results from behind the screen plane with a spring settle while the outgoing page zooms slightly toward the viewer and fades; leaving search reverses the depth. Replaces the previous vertical slide.
- **Backdrop dims while searching**, so results read as a raised layer.
- **Search field is now a hero element** — the pill stretches from 16 to 22 grid units with an elastic overshoot when a query begins, the search icon takes the accent colour and pops, and the clear button springs in.
- **Category pills recede and spring back** when entering and leaving search, instead of only fading.
- **Springy motion throughout** — hover scale, press feedback, the grid selection highlight, folder popups, dashboard page flips, and displaced-item shuffles all moved from `OutCubic` to `OutBack`/`OutQuint` easing.
- **Selection highlight fades and scales in** on first appearance instead of teleporting into place.
- **Dashboard and A–Z views hand off with an animation** rather than a visibility snap.
- **Search results now stagger in** when the first results land; subsequent keystrokes swap the model silently so refining a query no longer replays the entrance choreography on every character.

### Fixed

- **Blank category pill** — the placeholder row `RootModel` emits between "All Applications" and the real categories rendered as an empty pill mid-row. It is now hidden.
- **Layout jump when leaving search** — the letter-navigation back button was hidden mid-fade, shifting the grid underneath.
- **Grid flash during the search transition** — the idle base grid could briefly appear while the Dashboard, A–Z, or Recent view owned the stage.
- **Search exit no longer snaps** — the stack stays visible for the duration of the transition instead of disappearing under the returning view.
- Category selection routing consolidated into a single `selectCategory()` path, fixing inconsistent state when toggling a category off from the Dashboard or A–Z buttons.
