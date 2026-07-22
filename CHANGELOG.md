# Changelog

## 1.2.0

### Dashboard

- **Editing a folder is now an animation, not a redraw.** Every folder change used to be an instant swap: the grid was torn down and rebuilt, and whatever the user had just dragged simply reappeared somewhere else. All three mutations now play out on screen.
  - **Creating a folder** — drop one icon onto another and it arcs across on a shadowed flight while a frosted glass plate swells into place beneath it, a shockwave marks the moment the two become one, and the new folder springs into being under the pointer.
  - **Adding to a folder** — an existing folder visibly gulps what it swallows, the icon flying in and the tile pulsing as it lands.
  - **Removing from a folder** — pulling an app out of the open folder throws it to its new dashboard slot in one continuous gesture from where it was let go, the card recoils from losing it, and the icons left behind close the gap. Dropping an app off the dashboard entirely flings it clear of the card and lets it dissipate, since nothing survives to land.
- **Folders open as a true shared element.** The popup now morphs *out of the folder tile itself* — the squircle preview unfolds into the card, scaling and travelling on a single curve so shape and position never disagree — and rewinds into the tile on close, faster and without the overshoot so dismissal feels decisive. The dashboard settles back and dims behind it, putting the card on a plane in front of the grid rather than merely on top of it.
- **The open folder resizes instead of snapping.** Adding or removing an app while the folder is open now stretches the card to its new shape.
- **Folder contents fade in as one block.** The per-icon staggered entrance is gone: a folder's icons are part of the thing that just expanded, so presenting them in sequence fought the morph the card was already performing.
- **Three new duration sliders** — **Create folder**, **Add to folder** and **Remove from folder** (0 = off, which collapses each sequence to an instant write).
- **Live reordering with a real gap.** Dragging an icon now reflows the grid in real time: the surrounding icons **physically slide apart to open a gap** exactly where the icon will land, and the icon's original slot **fills in** so the board always previews how it will look after the drop. The dragged icon lifts with a spring, carries a real shape-aware drop shadow, drifts with a gentle tilt, and lives only under the pointer. Holding over another icon's centre still switches to a filled highlight with an expanding ring pulse to **group them into a folder** — a "cross the centre to reorder, rest on the centre to merge" model, so both gestures coexist. Live reordering works on the Dashboard and inside folders alike.

### Added

- **Zoom-into-app launch animation.** Opening an app no longer just closes the launcher — the whole board now winds up briefly and then dives into the activated icon while dissolving, so launching finally reads as *opening the app* rather than dismissing the menu. Works from the Dashboard, the app grid, A–Z, search results, Recent Apps, Recent Files, and from inside folders (the dive originates from wherever you clicked). Falls back to the normal close when switched off.
- **Font size sliders for every part of the launcher.** Five new sliders (50–200%) under widget settings size the **Category bar**, **Dashboard**, **All apps**, **Recent apps** and **Recent files** independently. Each one scales that view's whole type hierarchy rather than flattening it, so headings stay larger than body text and A–Z letters stay larger than app names. The grids and the recent-file rows grow with the text, so bigger labels are not clipped.
- **App launch** and **Move icons** duration sliders in the widget settings, so the new motion — like every other animation — is fully tunable (0 = off).
- **The background colour is now yours to pick.** The backdrop was always the Plasma theme's background colour, which left no way to darken the launcher on a light theme or tint it to match a wallpaper. A **Use a custom colour** toggle and colour picker now sit under the opacity slider; the chosen colour is still a tint rather than an opaque fill, so opacity keeps working as before, and it cross-fades when changed. Switched off, the theme colour is used exactly as it was.
- **Edit Application… on the app right-click menu**, the way Plasma's own launchers offer it. Editing an entry meant right-clicking the *panel icon* and opening the menu editor with nothing selected, then hunting the app down by hand. Right-clicking an app — in the grid, in A–Z, in search results, on the Dashboard, or inside a folder — now offers **Edit Application…**, which opens the menu editor on that entry. It shows up only where it can do something: real applications, with menu editing permitted and `kmenuedit` installed, so a calculator answer or a file hit in the search results is left alone.
- **Apps inside a folder get the full right-click menu.** Opening a folder and right-clicking one of its apps offered exactly one thing — *Remove from Folder* — so pinning, editing or uninstalling meant pulling the app back out of the folder first, or hunting it down again in All Apps. The folder now shows the same menu a dashboard tile does: **Pin to Task Manager**, **Edit Application…** and **Uninstall or Manage Add-Ons…**. It is literally the same menu rather than a copy of it, so the two cannot drift apart again.
- **Remove from Dashboard, from inside a folder.** Getting a foldered app off the dashboard meant taking it out of the folder and then removing it from the board — two gestures for one intention. The folder menu now carries **Remove from Dashboard** directly beneath *Remove from Folder*, so both endings are one click from the same place.

### Changed

- **Add to Favorites is gone from the right-click menus.** The launcher has no Favorites view to put anything in, so the entry wrote to a list nothing on screen ever read back — it looked like it did something and then nothing happened. Removed from both the app grid and the Dashboard menus.
- **Remove from Folder now means what it says.** It removed the app from the dashboard altogether, folder and all, which is what dragging an app clear of the board does — not what its label promised, and it left no way to simply take an app out of a folder without also losing it. It now surfaces the app onto the dashboard next to the folder it came from, the same as dragging it out of the card. Removing it outright is still one click away, now under its own name.
- **The backdrop defaults to 55% opacity** instead of 40%, so the launcher sits more solidly over a busy wallpaper out of the box. Only affects fresh installs — if you have already moved the opacity slider, your setting is kept.
- **Retuned animation defaults.** **Open/close** and **Icon entrance** both move to 350ms (from 150ms) so the launcher's arrival and the staggered pop-in read as motion rather than a flicker, while the **App launch** zoom drops to 150ms (from 450ms) so opening an app doesn't lag behind the click. Only affects fresh installs — if you have already moved a slider, your value is kept.
- **The A–Z letters are readable now.** In the **Alphabetically** category each letter is a tile you click to open that group, but it was drawn as an ordinary app caption — body-size text under an icon slot the letter groups never fill — so the whole page read as a grid of near-empty squares. The letter is now the tile's content: large, bold and centred in the cell, with the empty icon slot gone. The letter headings in the sectioned **All Apps** view were likewise only a few points above body text and dimmed; they are now larger and near-full opacity.
- **The widget now has its own logo.** Widget Management and *Show Alternatives* showed a generic KDE icon; they now show the Linexin logo (installed as `linexin-launcher` into the user icon theme).
- **Expressive, spring-driven motion throughout**, tuned toward Material 3 Expressive / Liquid Glass feel.
- **The folder card is a frosted-glass panel** with a light edge and a soft cast shadow for depth. (See **Dashboard** above for how it now opens.)
- **The launcher opens with more presence** — a deeper depth-settle with a firmer overshoot.

### Fixed

- **A new folder now appears where you made it.** With **Show all applications** enabled, dropping one icon onto another anywhere past the pinned ones sent the new folder shooting to the front of the dashboard, nowhere near the icons that formed it. Only pinned entries were ever written down, and everything else was re-appended after them on every rebuild — so the moment two of those unpinned tiles became a folder, the folder was pinned and jumped ahead of the whole crowd. The dashboard now remembers the position of every tile, pinned or not, and the folder takes the place of the icon it was dropped on. Reordering unpinned icons sticks for the same reason, and unpinning an app no longer flings it to the end of the board — it stays in its slot and simply stops being pinned. Apps that go away are still dropped rather than left behind as dead tiles, and newly installed ones still arrive at the end.
- **Dashboard pages past the first are no longer blank.** With **Show all applications** enabled the dashboard runs to several pages, but every page after the first came up empty and unclickable — the apps were there, just nowhere on screen. The grid fills left-to-right, so the axis it actually scrolls along is the vertical one: page 2 is the same column of icons further down. The paging code moved it sideways instead, which had nowhere to go and simply slid the whole grid out of its own clip rectangle, leaving bare background behind. Pages now move along the axis the grid really scrolls, and the last page can be reached even when it is only part-filled. The sideways motion is kept as a shared-axis transition, so a page change still reads as arriving from the side. Scrolling on while a page is still in motion no longer tears the transition down and replays it — the page in flight lands, and any further notches carry on from there rather than fighting it, including the case of scrolling past the last page, which is now simply ignored. A fast scroll still visits **every** page on the way rather than skipping to the last one; the pages it has yet to get through shorten each transition instead, so the run stays quick and then eases back to full length as it arrives. Clicking a page dot is random access and still goes straight there.
- **Clicking the active category now returns you to your Starting Category.** Clicking an already-selected category pill (or Dashboard / All Apps) always dropped you on Recent Apps, ignoring the Starting Category you configured; it now goes wherever the launcher would have opened.
- **Recent Apps and Recent Files no longer stutter into view.** KActivities fills the recent-history models asynchronously, so entries can still be arriving after the view is already showing — and every layout number the hero grid uses is derived from the item count. Starting the entrance before the history settled meant each late arrival re-ran that layout mid-animation, which read as the entrance stuttering or replaying several times over. The entrance now waits for one frame with no further insertions before it plays, so it always runs once, after the final count is known.
- **Restore Defaults now restores the real defaults.** The button and the shipped defaults disagreed: it reset open/close to 350ms and icon entrance to 400ms, while a fresh install started both at 150ms — so "restoring defaults" gave you something no new install had. The two are now in step across every slider, at the retuned values above.
- **All Apps was empty in every language but English.** The launcher locates Kicker's synthetic "All Applications" and "Recent Applications" rows by name, but those names arrive from Kicker already translated into the user's language — so comparing them against the English literals never matched outside an English locale. The all-apps row was then never found, leaving the **All Apps** view blank, and the category pills for those two rows fell through to their raw Kicker names instead of reading **Alphabetically** and **Recent Apps**. All five lookups now translate the literals through the same `libkicker` catalog Kicker itself uses, so they match in any language.

### Translations

- **The Recent Apps / Recent Files strings are actually translated now.** The six strings added for that view in 1.1.0 — *Clear History*, *Click again to confirm*, *Recent Files*, the `%1 item` / `%1 items` counter, and both empty-state lines — only ever reached the `.pot` template; no catalog carried a translation, so the view was English everywhere. All ten languages now translate them.
- **The settings page title is translatable.** *General*, the name of the widget's configuration page, lives in `config.qml`, which the extraction run never covered — so it was untranslated in every language regardless of catalog. It is now extracted and translated.
- **Dutch can count.** `nl.po` had no `Plural-Forms` header, which is what tells gettext how to pick between `%1 item` and `%1 items`; without it the plural form could not be resolved. The header is now present.
- **Every new 1.2.0 string is translated on arrival** — the five font-size labels, the *App launch*, *Move icons*, *Create folder*, *Add to folder* and *Remove from folder* duration labels, and the *Background color* / *Use a custom color* / *Choose Background Color* picker strings — across German, Spanish, French, Hindi, Dutch, Polish, Portuguese, Brazilian Portuguese, Russian and Simplified Chinese. No catalog has an untranslated entry.
- `.pot` regenerated; `App launch:` and `Move icons:`, whose sliders predate this release, were missing from the template and are now included.

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
