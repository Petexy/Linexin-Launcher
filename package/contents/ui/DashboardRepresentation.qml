/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later

    Linexin Launcher — Full-screen dashboard with macOS Launchpad-style animations
*/

import QtQuick 2.15
import QtQml 2.15
import QtQuick.Effects

import org.kde.kquickcontrolsaddons 2.0
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.kirigami 2.20 as Kirigami
import QtQuick.Layouts 1.1

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.private.kicker 0.1 as Kicker

import QtQuick.Controls

import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support 2.0 as P5Support

import "code/tools.js" as Tools


Kicker.DashboardWindow {
    id: root

    property bool smallScreen: ((Math.floor(width / Kirigami.Units.iconSizes.huge) <= 22)
                                || (Math.floor(height / Kirigami.Units.iconSizes.huge) <= 14))

    property int iconSize: {
        switch (Plasmoid.configuration.appsIconSize) {
        case 0: return Kirigami.Units.iconSizes.smallMedium;
        case 1: return Kirigami.Units.iconSizes.medium;
        case 2: return Kirigami.Units.iconSizes.large;
        case 3: return Kirigami.Units.iconSizes.huge;
        case 4: return Kirigami.Units.iconSizes.large * 2;
        case 5: return Kirigami.Units.iconSizes.enormous;
        default: return 64;
        }
    }

    property int favsIconSize: {
        switch (Plasmoid.configuration.favsIconSize) {
        case 0: return Kirigami.Units.iconSizes.smallMedium;
        case 1: return Kirigami.Units.iconSizes.medium;
        case 2: return Kirigami.Units.iconSizes.large;
        case 3: return Kirigami.Units.iconSizes.huge;
        case 4: return Kirigami.Units.iconSizes.enormous;
        default: return 64;
        }
    }

    property int systemIconSize: {
        switch (Plasmoid.configuration.systemIconSize) {
        case 0: return Kirigami.Units.iconSizes.smallMedium;
        case 1: return Kirigami.Units.iconSizes.medium;
        case 2: return Kirigami.Units.iconSizes.large;
        case 3: return Kirigami.Units.iconSizes.huge;
        case 4: return Kirigami.Units.iconSizes.enormous;
        default: return 64;
        }
    }

    // The label allowance grows (never shrinks) with the largest grid font
    // scale in play, so bumped-up app names don't get clipped by the cell.
    property int cellSize: iconSize + (2 * Kirigami.Units.iconSizes.sizeForLabels
                                       * Math.max(1, dashboardFontScale, allAppsFontScale))
                           + (2 * Kirigami.Units.largeSpacing)
                           + (2 * Math.max(highlightItemSvg.margins.top + highlightItemSvg.margins.bottom,
                                           highlightItemSvg.margins.left + highlightItemSvg.margins.right))

    // Clamped to >= 1: columns feeds `count / columns` and `ip % columns` in the
    // page/grid math, where a 0 (very narrow window) would yield Infinity/NaN.
    property int columns: Math.max(1, Math.floor(((smallScreen ? 85 : 80) / 100) * Math.ceil(width / cellSize)))
    property int dashRows: Math.max(1, Math.floor(height * 0.6 / cellSize) + 1)
    property int itemsPerPage: columns * dashRows
    property bool searching: searchField.text !== ""

    // -- Recent Apps / Recent Files --
    // Both are Kicker RecentUsageModels, capped at 15 entries, and RootModel
    // prepends their groups, so they always occupy the first category rows.
    // Checking the row index keeps this locale-independent. They render in a
    // dedicated RecentView instead of the standard category grid.
    // Deliberately independent of `searching`: RecentView animates its own
    // exit (shown && !searching), and keeping this true during a search keeps
    // the StackView's base grid transparent underneath.
    property int recentRowCount: (rootModel.showRecentApps ? 1 : 0) + (rootModel.showRecentDocs ? 1 : 0)
    property bool showingRecent: !rootItem.showingDashboard && !rootItem.showingAllApps
                                 && categoryRow.currentCategory >= 0
                                 && categoryRow.currentCategory < recentRowCount

    // -- Kicker model row labels --
    // RootModel names its synthetic rows with i18n() strings from the
    // "libkicker" catalog, so they arrive already translated. Matching them
    // against the English literals left every non-English locale unable to
    // find the all-apps row, i.e. an empty All Apps section. Translate the
    // literals through the same catalog instead.
    readonly property string allAppsRowLabel: i18nd("libkicker", "All Applications")
    readonly property string recentAppsRowLabel: i18nd("libkicker", "Recent Applications")

    // -- Font scaling --
    // Each view keeps its own internal type hierarchy (headers larger than
    // rows, group letters larger than app names); these multiply the whole
    // hierarchy rather than replacing it, so proportions survive.
    property real categoryFontScale: Plasmoid.configuration.categoryFontSize / 100.0
    property real dashboardFontScale: Plasmoid.configuration.dashboardFontSize / 100.0
    property real allAppsFontScale: Plasmoid.configuration.allAppsFontSize / 100.0
    property real recentAppsFontScale: Plasmoid.configuration.recentAppsFontSize / 100.0
    property real recentFilesFontScale: Plasmoid.configuration.recentFilesFontSize / 100.0

    // Point sizes below ~4 render as unreadable specks and can collapse the
    // layouts that size themselves off implicitHeight, so clamp the floor.
    function scaledFont(base, scale) {
        return Math.max(4, base * scale);
    }

    // -- Animation properties --
    property int animDuration: Plasmoid.configuration.animationDuration
    property int iconEntranceDuration: Plasmoid.configuration.iconEntranceDuration
    property int hoverEffectDuration: Plasmoid.configuration.hoverEffectDuration
    property int folderPopupDuration: Plasmoid.configuration.folderPopupDuration
    property int appLaunchDuration: Plasmoid.configuration.appLaunchDuration
    property int dragMoveDuration: Plasmoid.configuration.dragMoveDuration
    property int folderCreateDuration: Plasmoid.configuration.folderCreateDuration
    property int folderAddDuration: Plasmoid.configuration.folderAddDuration
    property int folderRemoveDuration: Plasmoid.configuration.folderRemoveDuration
    property real bgOpacity: Plasmoid.configuration.backgroundOpacity / 100.0
    property color bgColor: Plasmoid.configuration.useCustomBackgroundColor
        ? Plasmoid.configuration.backgroundColor
        : Kirigami.Theme.backgroundColor

    // State tracking for open/close animation
    property bool isOpening: false
    property bool isClosing: false

    backgroundColor: "transparent"

    // -- Dismiss on focus loss --
    // Kicker's DashboardWindow is a bare frameless fullscreen QQuickWindow.
    // There is no dependable way to pin it above other windows on Wayland:
    // core Wayland has no raise / keep-above a normal window can ask for
    // (raise() is an X11-only no-op there), and the one lever left —
    // re-asserting activation — is exactly what KWin denies, because Alt-Tab
    // hands the activation serial to the window you switched *to*, so our
    // requestActivate() is downgraded to "demands attention" and ignored. The
    // fullscreen launcher was then left mapped but stranded behind whatever
    // took focus and, still `visible`, took two button presses to recover (the
    // first merely toggled the hidden window shut).
    //
    // So we do what Kickoff and the stock Application Dashboard do: the moment
    // focus genuinely leaves the launcher, we close it. A single button press
    // reopens it, on X11 and Wayland alike. (Covering the window you Alt-Tabbed
    // *to* would be meaningless for a fullscreen overlay anyway.)
    //
    // stayOnTop() still runs once on open, to pull activation onto the launcher
    // so search-as-you-type works and it starts out in front.
    //
    // The timer that debounces this lives in rootItem, not here: DashboardWindow's
    // default property is `mainItem`, a single Item, so any unnamed child
    // declared at this level is an assignment to it.
    function stayOnTop() {
        raise();
        requestActivate();
    }

    onActiveChanged: {
        // Ignore deactivations we must not close on: isClosing/isOpening cover
        // the open, dismiss and app-launch animations (where focus legitimately
        // moves), and our own context menus open as transient children that
        // keep the window `active`, so a right-click never trips this.
        if (active || !visible || isClosing || isOpening) {
            return;
        }
        deactivateTimer.restart();
    }

    onKeyEscapePressed: {
        if (rootItem.openFolderIndex !== -1) {
            rootItem.openFolderIndex = -1;
        } else if (allAppsGrid.parentModel) {
            allAppsGrid.model = allAppsGrid.parentModel;
            allAppsGrid.parentModel = null;
            allAppsGrid.currentIndex = -1;
            allAppsGrid.animateEntrance();
        } else if (searching) {
            searchField.clear();
        } else {
            closeWithAnimation();
        }
    }

    onVisibleChanged: {
        if (visible) {
            isOpening = true;
            isClosing = false;
            stayOnTop();
            // Clear any in-flight launch zoom so an interrupted launch can't
            // leave the board scaled up on the next open. Flush first: stopping
            // the animation skips its onFinished, which would otherwise strand
            // a queued app and silently swallow the launch.
            flushPendingLaunch();
            appLaunchAnimation.stop();
            launchScale.xScale = 1.0;
            launchScale.yScale = 1.0;
            // Reset grid items to hidden before opening so they animate in fresh
            allAppsGrid.resetEntrance();
            dashboardGrid.resetEntrance();
            allAppsView.resetEntrance();
            recentView.resetEntrance();
            // reset() before starting: it swaps models, re-runs forceLayout and
            // moves focus, all of which block the UI thread. Starting the
            // animation first meant that work landed on top of the first
            // animated frames and ate the opening — the single biggest source
            // of the entrance feeling sluggish rather than instant.
            reset();
            openAnimation.start();
        } else {
            rootItem.opacity = 0;
            reset();
        }
    }

    onSearchingChanged: {
        if (!searching) {
            mainView.pop();
            reset();
        } else {
            mainView.push(runnerComponent);
        }
    }

    function colorWithAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // Stagger delay, in ms, for the grid item at (row, col) — a diagonal wave,
    // so the whole leading diagonal moves together rather than the grid
    // filling one icon at a time.
    //
    // Everything here is a fraction of iconEntranceDuration rather than a
    // fixed millisecond count. With fixed constants the cap became the
    // dominant term as soon as the durations were shortened: a 190ms wave
    // sequencing a 150ms animation means the last icon lands at 3x the
    // duration the user actually configured, which is exactly the sluggishness
    // the setting is supposed to control. Scaling keeps the tail at roughly
    // 1.3x the configured duration no matter what that duration is.
    function entranceDelay(row, col) {
        var d = root.iconEntranceDuration;
        return Math.min((row * 0.057 + col * 0.025) * d, d * 0.55);
    }

    // Routes a category-pill selection to the right view: recent rows go to
    // the dedicated RecentView, everything else to the standard grid.
    function selectCategory(row) {
        rootItem.showingDashboard = false;
        rootItem.showingAllApps = false;
        categoryRow.currentCategory = row;
        if (row < recentRowCount) {
            recentView.animateEntrance();
        } else {
            allAppsGrid.model = rootModel.modelForRow(row);
            allAppsGrid.currentIndex = -1;
            allAppsGrid.animateEntrance();
        }
    }

    // Recent rows move when either recent category is hidden, so persist the
    // user's intent as sentinels rather than as a brittle RootModel row number.
    // Returns -1 when neither recent category is available.
    function defaultRecentRow(defaultCategory) {
        if (defaultCategory === -3) { // Recent Apps
            if (rootModel.showRecentApps) return 0;
            return rootModel.showRecentDocs ? 0 : -1;
        }
        if (defaultCategory === -4) { // Recent Files
            if (rootModel.showRecentDocs) return rootModel.showRecentApps ? 1 : 0;
            return rootModel.showRecentApps ? 0 : -1;
        }
        return -1;
    }

    // 1.2.0 stored recent views as mutable RootModel row numbers. Keep
    // interpreting those two legacy values by their original meaning, but do
    // not let any other obsolete row index keep following a mutable model
    // position. Unsupported stored values safely fall back to Dashboard.
    function normalizedDefaultCategory() {
        var defaultCategory = Plasmoid.configuration.defaultCategory;
        if (defaultCategory === -4 || defaultCategory === -3
                || defaultCategory === -2 || defaultCategory === -1) {
            return defaultCategory;
        }
        if (defaultCategory === 0) return -3;
        if (defaultCategory === 1) return -4;
        return -2;
    }

    // Where a category pill sends you when it is clicked while already active:
    // back to the configured Starting Category, same target reset() picks on
    // open. Hidden recent views and unsupported legacy values fall back safely.
    function selectDefaultCategory() {
        var defCat = normalizedDefaultCategory();
        if (defCat === -2) {
            rootItem.showingDashboard = true;
            rootItem.showingAllApps = false;
            categoryRow.currentCategory = -1;
            dashboardGrid.animateEntrance();
        } else if (defCat === -1) {
            rootItem.showingDashboard = false;
            rootItem.showingAllApps = true;
            categoryRow.currentCategory = -1;
            allAppsView.populate();
            allAppsView.animateEntrance();
        } else {
            var recentRow = defaultRecentRow(defCat);
            if (recentRow >= 0) {
                selectCategory(recentRow);
            } else {
                rootItem.showingDashboard = true;
                rootItem.showingAllApps = false;
                categoryRow.currentCategory = -1;
                dashboardGrid.animateEntrance();
            }
        }
    }

    // Give keyboard focus to the control that is actually visible. The
    // StackView keeps allAppsGrid alive as its base page, so a catch-all route
    // to that grid can otherwise launch a hidden item from Dashboard or A-Z.
    function focusVisibleContent() {
        if (root.searching) {
            if (mainView.currentItem && mainView.currentItem.tryActivate) {
                mainView.currentItem.tryActivate(0, 0);
                mainView.currentItem.forceActiveFocus();
            }
        } else if (rootItem.showingDashboard) {
            dashboardGrid.activateFirstVisible();
        } else if (rootItem.showingAllApps) {
            allAppsView.focusSection(0, 0, 0);
        } else if (root.showingRecent) {
            recentView.tryActivate();
        } else {
            allAppsGrid.tryActivate(0, 0);
            allAppsGrid.forceActiveFocus();
        }
    }

    function focusCurrentCategory() {
        if (rootItem.showingDashboard) {
            dashboardCatBtn.forceActiveFocus();
        } else if (rootItem.showingAllApps) {
            allAppsCatBtn.forceActiveFocus();
        } else if (categoryRow.currentCategory >= 0) {
            var categoryButton = categoryRepeater.itemAt(categoryRow.currentCategory);
            if (categoryButton && categoryButton.visible) {
                categoryButton.forceActiveFocus();
                return;
            }
            dashboardCatBtn.forceActiveFocus();
        }
    }

    function categoryFocusItems() {
        var items = [dashboardCatBtn, allAppsCatBtn];
        for (var i = 0; i < categoryRepeater.count; ++i) {
            var item = categoryRepeater.itemAt(i);
            if (item && item.visible && item.enabled) {
                items.push(item);
            }
        }
        return items;
    }

    function navigateCategoryFocus(currentItem, direction, wrap) {
        var items = categoryFocusItems();
        var currentIndex = items.indexOf(currentItem);
        if (items.length === 0 || currentIndex < 0) {
            searchField.forceActiveFocus();
            return;
        }

        var nextIndex = currentIndex + direction;
        if (nextIndex >= 0 && nextIndex < items.length) {
            items[nextIndex].forceActiveFocus();
        } else if (wrap) {
            items[(nextIndex + items.length) % items.length].forceActiveFocus();
        } else if (direction > 0) {
            focusVisibleContent();
        } else {
            searchField.forceActiveFocus();
        }
    }

    function focusSystemActionsOrFallback() {
        if (systemFavoritesGrid.count > 0) {
            systemFavoritesGrid.tryActivate(0, 0);
            systemFavoritesGrid.forceActiveFocus();
        } else if (runningDockContainer.visible && runningRepeater.count > 0) {
            var firstTask = runningRepeater.itemAt(0);
            if (firstTask) {
                firstTask.forceActiveFocus();
            }
        } else {
            searchField.forceActiveFocus();
        }
    }

    // Wipes the KActivities usage history backing the current recent model.
    function clearRecentHistory() {
        var recentModel = recentView.recentModel;
        if (!recentModel || recentModel.count <= 0 || !("trigger" in recentModel)) {
            return;
        }
        recentModel.trigger(0, "forgetAll", null);
    }

    function closeWithAnimation() {
        isClosing = true;
        closeAnimation.start();
    }

    // Desktop file waiting on the launch animation. Spawning the process is
    // held back until the zoom has finished: kstart plus the app's own startup
    // (DBus activation, first window mapping, the compositor's map effect) all
    // land on the same thread that drives this animation, and starting it up
    // front stutters the dive right where it should be smoothest. A frame or
    // two of extra latency is invisible; the hitch was not.
    property string pendingLaunchDesktopFile: ""

    function flushPendingLaunch() {
        if (root.pendingLaunchDesktopFile === "") {
            return;
        }
        var df = root.pendingLaunchDesktopFile;
        root.pendingLaunchDesktopFile = "";
        rootItem.launchDesktopFile(df);
    }

    // Zoom-into-app launch: the whole board dives toward the activated icon and
    // dissolves, so opening an app reads distinctly from dismissing it. Falls
    // back to the plain close when the effect is switched off in settings.
    function launchWithZoom(cx, cy) {
        if (root.appLaunchDuration <= 0) {
            // No zoom to protect — launch straight away.
            flushPendingLaunch();
            closeWithAnimation();
            return;
        }
        isClosing = true;
        launchScale.origin.x = cx;
        launchScale.origin.y = cy;
        appLaunchAnimation.start();
    }

    // Convenience: zoom out from the centre of the delegate that was activated.
    function launchZoomFromItem(item) {
        if (!item) {
            flushPendingLaunch();
            closeWithAnimation();
            return;
        }
        var c = item.mapToItem(rootItem, item.width / 2, item.height / 2);
        launchWithZoom(c.x, c.y);
    }

    // Queue the app, then play the dive; flushPendingLaunch() spawns it once
    // the animation is done (or immediately if the effect is switched off).
    function launchAppFromItem(desktopFile, item) {
        root.pendingLaunchDesktopFile = desktopFile ? String(desktopFile) : "";
        launchZoomFromItem(item);
    }

    function reset() {
        rootItem.showingDashboard = false;
        rootItem.showingAllApps = false;
        rootItem.openFolderIndex = -1;
        allAppsGrid.parentModel = null;

        var defCat = normalizedDefaultCategory();
        if (defCat === -2) {
            rootItem.showingDashboard = true;
            categoryRow.currentCategory = -1;
        } else if (defCat === -1) {
            rootItem.showingAllApps = true;
            categoryRow.currentCategory = -1;
            allAppsView.populate();
        } else {
            var recentRow = defaultRecentRow(defCat);
            if (recentRow >= 0) {
                categoryRow.currentCategory = recentRow;
            } else {
                rootItem.showingDashboard = true;
                categoryRow.currentCategory = -1;
            }
        }

        dashboardView.resetToFirstPage();
        allAppsGrid.currentIndex = -1;
        systemFavoritesGrid.currentIndex = -1;

        allAppsGrid.forceLayout();

        searchField.clear();
        searchField.forceActiveFocus();
    }

    // =============================================
    //               MAIN ITEM
    // =============================================

    mainItem: Item {
        id: rootItem

        anchors.fill: parent

        opacity: 0

        transformOrigin: Item.Center

        // Zoom-into-app launch transform — its origin is moved onto the
        // activated icon so the whole board appears to dive into it. Composes
        // on top of the Item.Center scale used by open/close. See launchWithZoom.
        transform: Scale {
            id: launchScale
            origin.x: rootItem.width / 2
            origin.y: rootItem.height / 2
            xScale: 1.0
            yScale: 1.0
        }

        // Debounces focus loss into a dismiss. Deferred by a frame or two
        // rather than run straight from onActiveChanged: activation can flip
        // twice in quick succession while one of our own popups is being
        // mapped, and the intermediate frame reports the launcher inactive
        // before the popup settles as its transient child. Re-checking active
        // here lets those transient flips resolve without closing the launcher.
        Timer {
            id: deactivateTimer
            interval: 50
            repeat: false
            onTriggered: {
                if (root.visible && !root.active && !root.isClosing && !root.isOpening) {
                    root.closeWithAnimation();
                }
            }
        }

        // Background click handler — closes the launcher when clicking empty space
        MouseArea {
            id: bgClickArea
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton
            onClicked: closeWithAnimation()
        }

        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true




        // =============================================
        //           OPEN / CLOSE ANIMATIONS
        // =============================================

        ParallelAnimation {
            id: openAnimation

            // Background fades in — front-loaded so the backdrop is essentially
            // there by the time the eye arrives, the way Launchpad's is.
            NumberAnimation {
                target: bgRect
                property: "opacity"
                from: 0
                to: root.bgOpacity
                duration: Math.round(root.animDuration * 0.45)
                easing.type: Easing.OutCubic
            }
            // Content fades in
            NumberAnimation {
                target: rootItem
                property: "opacity"
                from: 0
                to: 1
                duration: Math.round(root.animDuration * 0.5)
                easing.type: Easing.OutCubic
            }
            // Depth settle, Launchpad-style: the overlay resolves *down* from
            // slightly in front of the screen plane rather than rising from
            // behind it. Two reasons this direction and not the other:
            //   - Coming from below 1.0 left bgRect smaller than the screen for
            //     the whole entrance, so the desktop showed through a border.
            //   - Settling down from larger reads as arriving; growing from
            //     smaller reads as loading.
            // OutExpo, not OutBack: the per-icon springs below already supply
            // the overshoot, and stacking a board-level bounce on top of ~40
            // icon bounces is what made this feel wobbly and slow rather than
            // fluid. Nothing here runs past animDuration — a multiplier above
            // 1.0 meant the user's configured duration was a floor, not a value.
            NumberAnimation {
                target: rootItem
                property: "scale"
                from: 1.06
                to: 1
                duration: Math.round(root.animDuration * 0.75)
                easing.type: Easing.OutExpo
            }
            // A short lift under the zoom. Kept deliberately small: a long
            // vertical slide fights the scale settle and is the part that read
            // as "heavy" — Launchpad has no translation here at all.
            NumberAnimation {
                target: contentArea
                property: "anchors.verticalCenterOffset"
                from: Kirigami.Units.gridUnit * 3
                to: Kirigami.Units.gridUnit * 2
                duration: Math.round(root.animDuration * 0.65)
                easing.type: Easing.OutQuint
            }

            onFinished: {
                isOpening = false;
            }

            onStarted: {
                gridEntranceAnimation.start();
            }
        }

        ParallelAnimation {
            id: closeAnimation

            NumberAnimation {
                target: rootItem
                property: "opacity"
                from: 1
                to: 0
                duration: Math.round(root.animDuration * 0.5)
                easing.type: Easing.InCubic
            }
            // Recede back into the screen plane while fading out
            NumberAnimation {
                target: rootItem
                property: "scale"
                from: 1
                to: 0.97
                duration: Math.round(root.animDuration * 0.5)
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: bgRect
                property: "opacity"
                from: root.bgOpacity
                to: 0
                duration: Math.round(root.animDuration * 0.6)
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: contentArea
                property: "anchors.verticalCenterOffset"
                from: Kirigami.Units.gridUnit * 2
                to: Kirigami.Units.gridUnit * 4
                duration: Math.round(root.animDuration * 0.5)
                easing.type: Easing.InCubic
            }

            onFinished: {
                isClosing = false;
                root.toggle();
            }
        }

        // App-launch "dive in": the whole overlay rushes into the activated
        // icon and dissolves. Distinct from the recede-and-fade dismiss so
        // launching an app feels like opening it rather than closing the menu.
        //
        // Easing note: this accelerates — an unhurried start that builds into
        // a fast exit — but it must never actually rest. Easing.In* is the
        // obvious pick and the wrong one: it leaves from *zero* velocity, so
        // the board sits visibly frozen before it moves. This curve instead
        // departs at ~0.6x speed (gentle, but real motion from frame one) and
        // arrives at ~1.6x, so the dive is at its fastest exactly as it
        // vanishes. No control point sits at y=1.0, so it never stalls at
        // full zoom either.
        //
        // Every track below shares that one curve and the *same* duration, and
        // that uniformity is the point. The earlier version mixed an
        // accelerating scale with two InCubic fades — and because bgRect is a
        // child of rootItem the fades multiplied, so the compound alpha sat
        // near-flat through exactly the stretch where the scale was slowest.
        // Nothing visibly changed for the middle third of the flight: the
        // "brief stop" that read as a lag. bgRect ending at 80% compounded it,
        // freezing the backdrop while the rest was still travelling.
        ParallelAnimation {
            id: appLaunchAnimation

            readonly property var diveCurve: [0.25, 0.15, 0.6, 0.4, 1.0, 1.0]

            NumberAnimation {
                target: launchScale; property: "xScale"
                from: 1.0; to: 2.0
                duration: root.appLaunchDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: appLaunchAnimation.diveCurve
            }
            NumberAnimation {
                target: launchScale; property: "yScale"
                from: 1.0; to: 2.0
                duration: root.appLaunchDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: appLaunchAnimation.diveCurve
            }
            // Both fades run the full duration on the dive curve, so the board
            // dissolves at the same rate it travels — fastest right as it
            // disappears, with no flat spot anywhere in between.
            NumberAnimation {
                target: rootItem; property: "opacity"
                from: 1; to: 0
                duration: root.appLaunchDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: appLaunchAnimation.diveCurve
            }
            NumberAnimation {
                target: bgRect; property: "opacity"
                from: root.bgOpacity; to: 0
                duration: root.appLaunchDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: appLaunchAnimation.diveCurve
            }

            onFinished: {
                isClosing = false;
                // Reset the launch transform so the next open starts clean
                launchScale.xScale = 1.0;
                launchScale.yScale = 1.0;
                launchScale.origin.x = rootItem.width / 2;
                launchScale.origin.y = rootItem.height / 2;
                root.flushPendingLaunch();
                root.toggle();
            }
        }

        SequentialAnimation {
            id: gridEntranceAnimation

            // No lead-in pause. The icons are the content — gating them behind
            // the board meant the open read as two sequential animations
            // (board, then grid) instead of one. They now start on the same
            // frame and the per-icon stagger provides all the sequencing.

            ScriptAction {
                script: {
                    if (rootItem.showingDashboard) {
                        dashboardGrid.animateEntrance();
                    } else if (rootItem.showingAllApps) {
                        allAppsView.animateEntrance();
                    } else if (root.showingRecent) {
                        recentView.animateEntrance();
                    } else {
                        allAppsGrid.animateEntrance();
                    }
                }
            }
        }

        // Background with blur-like tinted overlay
        Rectangle {
            id: bgRect
            anchors.fill: parent
            color: root.bgColor
            opacity: root.bgOpacity

            Behavior on color {
                ColorAnimation { duration: root.hoverEffectDuration }
            }

            // Cancels out rootItem's launch-zoom Scale (see launchScale) so the
            // fullscreen backdrop stays put — only the foreground content dives
            // toward the launched icon, keeping the overlay from ever looking
            // smaller than the screen mid-bounce.
            transform: Scale {
                origin.x: launchScale.origin.x
                origin.y: launchScale.origin.y
                xScale: 1 / launchScale.xScale
                yScale: 1 / launchScale.yScale
            }
        }

        // Focus dim — darkens the backdrop while searching so the results
        // read as a raised layer above everything else
        Rectangle {
            id: searchDimRect
            anchors.fill: parent
            color: "black"
            opacity: root.searching ? 0.2 : 0

            Behavior on opacity {
                NumberAnimation { duration: root.animDuration * 0.7; easing.type: Easing.OutCubic }
            }

            // Same launch-zoom cancellation as bgRect — this dim layer reads as
            // part of the backdrop, not foreground content.
            transform: Scale {
                origin.x: launchScale.origin.x
                origin.y: launchScale.origin.y
                xScale: 1 / launchScale.xScale
                yScale: 1 / launchScale.yScale
            }
        }

        Connections {
            target: kicker

            function onReset() {
                if (!root.searching) {
                    // no-op when not searching
                }
            }

            function onDragSourceChanged() {
                if (!kicker.dragSource) {
                    rootModel.refresh();
                }
            }
        }

        Connections {
            target: Plasmoid
            function onUserConfiguringChanged() {
                if (Plasmoid.userConfiguring) {
                    root.hide();
                }
            }
        }

        Connections {
            target: Plasmoid.configuration
            function onShowAllAppsInDashboardChanged() {
                dashboardModel.reload();
            }
        }

        PlasmaExtras.Menu {
            id: contextMenu

            PlasmaExtras.MenuItem {
                action: Plasmoid.internalAction("configure")
            }
        }

        // =============================================
        //     APP GRID CONTEXT MENU
        // =============================================
        PlasmaExtras.Menu {
            id: appContextMenu
            property string appUrl: ""
            property bool appIsApplication: false
            property bool appCanEdit: false
            property string appName: ""
            property string appIcon: ""
            property var appModel: null
            property int appIndex: -1

            onStatusChanged: {
                // Start the asynchronous check only after the native popup is
                // open. Starting it before menuOpenTimer's deferred open meant
                // a fast reply was discarded as stale, leaving Pin disabled
                // for the lifetime of that menu.
                if (status === PlasmaExtras.Menu.Open && appIsApplication) {
                    pinMenuItem.isPinned = false;
                    pinMenuItem.taskManagerFound = false;
                    rootItem.queryPinState(pinChecker, appUrl);
                }
            }

            PlasmaExtras.MenuItem {
                id: dashboardMenuItem
                text: rootItem.isDashboardApp(appContextMenu.appUrl) ? i18n("Remove from Dashboard") : i18n("Add to Dashboard")
                icon: rootItem.isDashboardApp(appContextMenu.appUrl) ? "edit-delete-remove" : "list-add"
                visible: appContextMenu.appIsApplication
                onClicked: {
                    var url = appContextMenu.appUrl;
                    var name = appContextMenu.appName;
                    var ic = appContextMenu.appIcon;
                    var wasDash = rootItem.isDashboardApp(url);
                    appContextMenu.close();
                    if (wasDash) {
                        rootItem.removeFromDashboard(url);
                    } else {
                        rootItem.addToDashboard(url, name, ic);
                    }
                }
            }

            PlasmaExtras.MenuItem { separator: true; visible: appContextMenu.appIsApplication }

            PlasmaExtras.MenuItem {
                id: pinMenuItem
                property bool isPinned: false
                text: isPinned ? i18n("Unpin from Task Manager") : i18n("Pin to Task Manager")
                icon: isPinned ? "window-unpin" : "window-pin"
                visible: appContextMenu.appIsApplication
                enabled: taskManagerFound
                property bool taskManagerFound: false
                onClicked: {
                    rootItem.toggleTaskManagerLauncher(appContextMenu.appUrl);
                }
            }

            PlasmaExtras.MenuItem { separator: true; visible: appContextMenu.appIsApplication }

            PlasmaExtras.MenuItem {
                text: i18n("Edit Application…")
                icon: "kmenuedit"
                visible: appContextMenu.appCanEdit
                onClicked: {
                    var srcModel = appContextMenu.appModel;
                    var row = appContextMenu.appIndex;
                    appContextMenu.close();
                    closeWithAnimation();
                    // Hand off to the Kicker model rather than spawning kmenuedit
                    // ourselves — it resolves the entry's menu ID from KService,
                    // which is what kmenuedit expects and is not always the plain
                    // .desktop file name.
                    if (srcModel && "trigger" in srcModel) {
                        srcModel.trigger(row, "editApplication", null);
                    }
                }
            }

            PlasmaExtras.MenuItem {
                text: i18n("Uninstall or Manage Add-Ons…")
                icon: "plasmadiscover"
                visible: appContextMenu.appIsApplication
                onClicked: {
                    var appUrl = appContextMenu.appUrl;
                    appContextMenu.close();
                    closeWithAnimation();
                    rootItem.openApplicationInDiscover(appUrl);
                }
            }
        }

        // Files, settings and other runner results keep their model-provided
        // actions. They must never inherit Dashboard/Task Manager/Discover
        // actions merely because the runner supplied a URL.
        ActionMenu {
            id: resultActionMenu
            property var sourceModel: null
            property int sourceIndex: -1

            onActionClicked: (actionId, actionArgument) => {
                if (sourceModel && "trigger" in sourceModel) {
                    var closeRequested = sourceModel.trigger(sourceIndex, actionId, actionArgument);
                    if (closeRequested === true) {
                        closeWithAnimation();
                    }
                }
            }
        }

        P5Support.DataSource {
            id: discoverHelper
            engine: "executable"
            onNewData: function(source, data) {
                disconnectSource(source);
            }
        }

        P5Support.DataSource {
            id: pinHelper
            engine: "executable"
            onNewData: function(source, data) {
                disconnectSource(source);
            }
        }

        P5Support.DataSource {
            id: pinChecker
            engine: "executable"
            onNewData: function(source, data) {
                var stdout = (data["stdout"] || "").trim();
                disconnectSource(source);
                // This reply is a qdbus round-trip and can land after the menu
                // has already closed. Flipping isPinned then rewrites the item's
                // text and icon, reflowing the popup — and if the menu is mid
                // teardown that pushes a blur region to a surface being
                // destroyed, the fatal Wayland error that crashes plasmashell.
                // Only apply while the menu is actually open; a stale result is
                // re-queried on the next open anyway.
                if (appContextMenu.status !== PlasmaExtras.Menu.Open) {
                    return;
                }
                var result;
                try {
                    result = JSON.parse(stdout);
                } catch (error) {
                    return;
                }
                if (!result || result.url !== appContextMenu.appUrl) {
                    return;
                }
                pinMenuItem.taskManagerFound = result.found === true;
                pinMenuItem.isPinned = result.pinned === true;
            }
        }

        // Deferred menu opener — QMenu needs a frame between close() and open()
        Timer {
            id: menuOpenTimer
            interval: 16
            property var menu: null
            property real mx: 0
            property real my: 0
            onTriggered: {
                if (!menu || dragHelper.dragging) {
                    return;
                }
                // The visualParent is the delegate the menu anchors to. It can
                // be destroyed within this 16ms window while the app model is
                // relaying out — e.g. right after a .desktop file is edited or
                // removed and the sycoca DB reloads, tearing down and rebuilding
                // every delegate. An Item-typed property reads back null once its
                // object is gone, so a null here means the anchor died under us.
                // Opening a blurred PlasmaExtras.Menu popup against a destroyed
                // surface makes plasmashell push a blur region to a dead
                // wl_surface — a fatal Wayland protocol error
                // (ext_background_effect_surface_v1: "tried to set blur region on
                // destroyed surface") that takes the whole shell down. Skip the
                // open rather than anchor to a corpse.
                if (!menu.visualParent || !root.visible) {
                    return;
                }
                menu.open(mx, my);
            }
            function openMenu(m, x, y) {
                menu = m;
                mx = x;
                my = y;
                m.close();
                restart();
            }
        }

        // After a native drag ends, force-close all menus to reset QMenu state.
        // Without this, QMenu can get stuck and refuse to open after a drag.
        Connections {
            target: dragHelper
            function onDropped() {
                appContextMenu.close();
                dockContextMenu.close();
                dashContextMenu.close();
            }
        }

        // Quote one complete shell argument. Desktop-entry storage IDs are file
        // names, not identifiers restricted to ASCII: spaces, apostrophes and
        // non-Latin text are all legal. Keep those names intact while making the
        // shell treat every byte as data rather than syntax.
        function shellQuote(value) {
            return "'" + String(value).replace(/'/g, "'\\''") + "'";
        }

        function jsStringLiteral(value) {
            // U+2028/U+2029 were line terminators rather than string contents in
            // older ECMAScript parsers still used by some Plasma releases.
            return JSON.stringify(String(value))
                .replace(/\u2028/g, "\\u2028")
                .replace(/\u2029/g, "\\u2029");
        }

        // Reduce an applications:/file: URL, an encoded QUrl string, or a bare
        // KService storage ID to the desktop file name KService understands.
        // A bare storage ID is already decoded data, so preserve literal '%',
        // '?' and '#'. They acquire URL syntax only when a scheme/path is present.
        function desktopFileFromApplication(value) {
            var desktopFile = String(value || "");
            if (desktopFile === "") {
                return "";
            }

            var isUrl = /^applications:/i.test(desktopFile)
                     || /^file:/i.test(desktopFile)
                     || desktopFile.indexOf("/") !== -1;
            if (isUrl) {
                desktopFile = desktopFile.replace(/^applications:\/*/i, "");
                desktopFile = desktopFile.replace(/^file:\/\/*/i, "/");
                // Query and fragment parts describe a runner action, not its app.
                desktopFile = desktopFile.replace(/[?#].*$/, "");
                desktopFile = desktopFile.replace(/^.*\//, "");
                try {
                    desktopFile = decodeURIComponent(desktopFile);
                } catch (error) {
                    // Keep malformed URL text inert. Structural validation below
                    // still prevents it from becoming a path.
                }
            }

            // A slash/NUL cannot be part of a KService storage ID. This
            // is structural validation only; punctuation and Unicode stay valid.
            if (desktopFile.indexOf("/") !== -1 || desktopFile.indexOf("\0") !== -1
                    || !/\.desktop$/i.test(desktopFile)) {
                return "";
            }
            return desktopFile;
        }

        function canonicalApplicationUrl(value) {
            var desktopFile = desktopFileFromApplication(value);
            // Keep the persisted/inter-component form unambiguous: a literal '%'
            // in a storage ID becomes %25, while spaces and Unicode follow normal
            // QUrl serialization. Process/API boundaries decode through the
            // helper above when they need the storage ID itself.
            return desktopFile === ""
                ? "" : "applications:" + encodeURIComponent(desktopFile);
        }

        function sameApplication(first, second) {
            var firstUrl = canonicalApplicationUrl(first);
            var secondUrl = canonicalApplicationUrl(second);
            return firstUrl !== "" && firstUrl === secondUrl;
        }

        // Resolve an AppStream component without ever interpolating the desktop
        // file into shell syntax. appstreamcli's output remains inside a quoted
        // URL argument as well.
        function openApplicationInDiscover(applicationUrl) {
            var desktopFile = desktopFileFromApplication(applicationUrl);
            if (desktopFile === "") {
                return;
            }
            var stem = desktopFile.replace(/\.desktop$/i, "");
            var quotedStem = shellQuote(stem);
            var quotedDesktopFile = shellQuote(desktopFile);
            var cmd = "ID=$(appstreamcli get -- " + quotedStem + " 2>/dev/null | head -1 | awk '{print $2}');"
                    + "[ -z \"$ID\" ] && ID=$(appstreamcli get -- " + quotedDesktopFile + " 2>/dev/null | head -1 | awk '{print $2}');"
                    + "[ -z \"$ID\" ] && ID=$(appstreamcli search -- " + quotedStem + " 2>/dev/null | grep 'Identifier:.*\\[desktop-application\\]' | head -1 | awk '{print $2}');"
                    + "[ -n \"$ID\" ] && xdg-open \"appstream://$ID\""
                    + " #" + Date.now();
            discoverHelper.connectSource(cmd);
        }

        // Select one Task Manager deterministically. Prefer the one in the panel
        // containing this launcher; otherwise use the first Task Manager found.
        // Supporting both task-manager applet types avoids showing an action that
        // silently does nothing for users of the non-icons-only variant.
        function taskManagerScriptPrefix() {
            var ownId = Number(Plasmoid.id);
            return "var ps=panels();var target=null;var fallback=null;"
                + "for(var i=0;i<ps.length;i++){var ws=ps[i].widgets();var own=false;"
                + "for(var j=0;j<ws.length;j++){if(Number(ws[j].id)===" + ownId + "){own=true;break;}}"
                + "for(var k=0;k<ws.length;k++){var t=ws[k].type;"
                + "if(t==='org.kde.plasma.icontasks'||t==='org.kde.plasma.taskmanager'"
                + "||t==='org.kde.plasma.expandingiconstaskmanager'){"
                + "if(!fallback){fallback=ws[k];}if(own&&!target){target=ws[k];}}}}"
                + "if(!target){target=fallback;}";
        }

        function toggleTaskManagerLauncher(desktopFile) {
            var url = canonicalApplicationUrl(desktopFile);
            if (url === "") {
                return;
            }
            var urlLiteral = jsStringLiteral(url);
            var script = taskManagerScriptPrefix()
                + "if(target){target.currentConfigGroup=['General'];"
                + "var raw=target.readConfig('launchers')||'';"
                + "var cur=raw===''?[]:raw.split(',');"
                + "var wanted=" + urlLiteral + ";"
                + "function launcherKey(v){v=String(v||'');"
                + "if(v.indexOf('applications:')!==0){return v;}"
                + "var p=v.substring(13).replace(/[?#].*$/,'');"
                + "try{p=decodeURIComponent(p);}catch(e){}"
                + "return 'applications:'+encodeURIComponent(p);}"
                + "var idx=-1;for(var n=0;n<cur.length;n++){"
                + "if(launcherKey(cur[n])===wanted){idx=n;break;}}"
                + "if(idx!==-1){cur.splice(idx,1);}else{cur.push(wanted);}"
                + "target.writeConfig('launchers',cur);}";
            var cmd = "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                + shellQuote(script) + " #" + Date.now();
            pinHelper.connectSource(cmd);
        }

        // Whether the Kicker model offers a given action for this row. Used to
        // gate menu entries on the same rules Plasma itself applies — e.g. the
        // editApplication action only exists for real .desktop services, and
        // only when menu editing is permitted and kmenuedit is installed, so
        // runner hits (calculator answers, files, …) drop out on their own.
        function hasAction(model, actionId) {
            var actions = ("actionList" in model) ? model.actionList : null;
            if (!actions) {
                return false;
            }
            for (var i = 0; i < actions.length; i++) {
                if (actions[i].actionId === actionId) {
                    return true;
                }
            }
            return false;
        }

        // Kicker only assigns favoriteId to real application matches from the
        // services runner; file/recent-document rows expose their file URL
        // instead. Use that semantic role as the gate, then normalize the
        // application URL used by our Dashboard and Task Manager actions.
        function applicationUrlForModel(model, url) {
            var favoriteId = ("favoriteId" in model) ? String(model.favoriteId || "") : "";
            if (favoriteId === "" || /^file:/i.test(favoriteId)) {
                return "";
            }
            var isApplicationId = /^applications:/i.test(favoriteId)
                                  || /^preferred:/i.test(favoriteId)
                                  || /\.desktop$/i.test(favoriteId);
            if (!isApplicationId) {
                return "";
            }

            // A plain storage ID is more authoritative than model.url: converting
            // the latter QUrl to a string percent-encodes spaces and Unicode.
            if (/\.desktop$/i.test(favoriteId) && !/^applications:/i.test(favoriteId)) {
                return canonicalApplicationUrl(favoriteId);
            }

            if (/^applications:/i.test(favoriteId)) {
                return canonicalApplicationUrl(favoriteId);
            }

            // A preferred:// AppEntry exposes its resolved KService through url.
            // Do not persist the preference alias: Dashboard and Discover need
            // the concrete desktop file that is current at menu-open time.
            return canonicalApplicationUrl(url);
        }

        // Ask the selected Task Manager which apps it currently has pinned.
        // The reply arrives asynchronously on the given checker, which flips the
        // Pin/Unpin label on the menu it belongs to.
        function queryPinState(checker, desktopFile) {
            var url = canonicalApplicationUrl(desktopFile);
            if (url === "") {
                return;
            }
            var urlLiteral = jsStringLiteral(url);
            var script = taskManagerScriptPrefix()
                + "if(target){target.currentConfigGroup=['General'];"
                + "var raw=target.readConfig('launchers')||'';"
                + "var cur=raw===''?[]:raw.split(',');"
                + "var wanted=" + urlLiteral + ";"
                + "function launcherKey(v){v=String(v||'');"
                + "if(v.indexOf('applications:')!==0){return v;}"
                + "var p=v.substring(13).replace(/[?#].*$/,'');"
                + "try{p=decodeURIComponent(p);}catch(e){}"
                + "return 'applications:'+encodeURIComponent(p);}"
                + "var pinned=false;for(var n=0;n<cur.length;n++){"
                + "if(launcherKey(cur[n])===wanted){pinned=true;break;}}"
                + "print(JSON.stringify({found:true,pinned:pinned,url:wanted}));"
                + "}else{print(JSON.stringify({found:false,pinned:false,url:"
                + urlLiteral + "}));}";
            var cmd = "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                + shellQuote(script) + " #" + Date.now();
            checker.connectSource(cmd);
        }

        function openAppContextMenu(delegateItem, model, mx, my) {
            var url = model.url ? model.url.toString() : "";
            var appUrl = applicationUrlForModel(model, url);
            var sourceModel = delegateItem.GridView ? delegateItem.GridView.view.model : null;

            if (appUrl === "") {
                var actionList = ("actionList" in model) ? model.actionList : null;
                if (actionList && actionList.length > 0 && sourceModel) {
                    resultActionMenu.visualParent = delegateItem;
                    resultActionMenu.sourceModel = sourceModel;
                    resultActionMenu.sourceIndex = model.index;
                    resultActionMenu.actionList = actionList;
                    resultActionMenu.open(mx, my);
                }
                return;
            }

            appContextMenu.appUrl = appUrl;
            appContextMenu.appIsApplication = true;
            appContextMenu.appName = model.display || "";
            appContextMenu.appIcon = model.decoration || "";
            appContextMenu.appModel = sourceModel;
            appContextMenu.appIndex = model.index;
            appContextMenu.appCanEdit = hasAction(model, "editApplication");
            appContextMenu.visualParent = delegateItem;
            // Check if this app is currently pinned in icontasks
            pinMenuItem.isPinned = false;
            pinMenuItem.taskManagerFound = false;
            appContextMenu.visualParent = delegateItem;
            menuOpenTimer.openMenu(appContextMenu, mx, my);
        }

        // =============================================
        //     DOCK CONTEXT MENU (Task Manager style)
        // =============================================
        PlasmaExtras.Menu {
            id: dockContextMenu
            property var taskModel: null
            property var taskIndex: null
            property bool isWindow: false
            property bool isLauncher: false
            property bool isMinimized: false
            property bool isMaximized: false
            property bool isKeepAbove: false
            property bool isKeepBelow: false
            property bool isFullScreen: false

            PlasmaExtras.MenuItem {
                text: i18n("Open New Instance")
                icon: "window-new"
                visible: dockContextMenu.taskModel !== null
                onClicked: {
                    dockContextMenu.taskModel.requestNewInstance(dockContextMenu.taskIndex);
                }
            }
            PlasmaExtras.MenuItem { separator: true; visible: dockContextMenu.isWindow }
            PlasmaExtras.MenuItem {
                text: dockContextMenu.isMinimized ? i18n("Restore") : i18n("Minimize")
                icon: dockContextMenu.isMinimized ? "window-restore" : "window-minimize"
                visible: dockContextMenu.isWindow
                onClicked: {
                    dockContextMenu.taskModel.requestToggleMinimized(dockContextMenu.taskIndex);
                }
            }
            PlasmaExtras.MenuItem {
                text: dockContextMenu.isMaximized ? i18n("Restore") : i18n("Maximize")
                icon: dockContextMenu.isMaximized ? "window-restore" : "window-maximize"
                visible: dockContextMenu.isWindow
                onClicked: {
                    dockContextMenu.taskModel.requestToggleMaximized(dockContextMenu.taskIndex);
                }
            }
            PlasmaExtras.MenuItem { separator: true; visible: dockContextMenu.isWindow }
            PlasmaExtras.MenuItem {
                text: i18n("Keep Above Others")
                icon: "window-keep-above"
                checkable: true
                checked: dockContextMenu.isKeepAbove
                visible: dockContextMenu.isWindow
                onClicked: {
                    dockContextMenu.taskModel.requestToggleKeepAbove(dockContextMenu.taskIndex);
                }
            }
            PlasmaExtras.MenuItem {
                text: i18n("Keep Below Others")
                icon: "window-keep-below"
                checkable: true
                checked: dockContextMenu.isKeepBelow
                visible: dockContextMenu.isWindow
                onClicked: {
                    dockContextMenu.taskModel.requestToggleKeepBelow(dockContextMenu.taskIndex);
                }
            }
            PlasmaExtras.MenuItem {
                text: i18n("Fullscreen")
                icon: "view-fullscreen"
                checkable: true
                checked: dockContextMenu.isFullScreen
                visible: dockContextMenu.isWindow
                onClicked: {
                    dockContextMenu.taskModel.requestToggleFullScreen(dockContextMenu.taskIndex);
                }
            }
            PlasmaExtras.MenuItem { separator: true; visible: dockContextMenu.isWindow }
            PlasmaExtras.MenuItem {
                text: i18n("Close")
                icon: "window-close"
                visible: dockContextMenu.isWindow
                onClicked: {
                    dockContextMenu.taskModel.requestClose(dockContextMenu.taskIndex);
                }
            }
        }

        function openDockContextMenu(tasksModelRef, modelIndex, delegateItem, mx, my, props) {
            var idx = tasksModelRef.index(modelIndex, 0);
            dockContextMenu.taskModel = tasksModelRef;
            dockContextMenu.taskIndex = idx;
            dockContextMenu.isWindow = props.isWindow;
            dockContextMenu.isLauncher = props.isLauncher;
            dockContextMenu.isMinimized = props.isMinimized;
            dockContextMenu.isMaximized = props.isMaximized;
            dockContextMenu.isKeepAbove = props.isKeepAbove;
            dockContextMenu.isKeepBelow = props.isKeepBelow;
            dockContextMenu.isFullScreen = props.isFullScreen;
            dockContextMenu.visualParent = delegateItem;
            menuOpenTimer.openMenu(dockContextMenu, mx, my);
        }

        Kirigami.Heading {
            id: dummyHeading
            visible: false
            width: 0
            level: 1
        }

        TextMetrics {
            id: headingMetrics
            font: dummyHeading.font
        }

        Kicker.FunnelModel {
            id: funnelModel

            onSourceModelChanged: {
                allAppsGrid.currentIndex = -1;
                allAppsGrid.forceLayout();
            }
        }

        Kicker.ContainmentInterface {
            id: containmentInterface
        }

        // =============================================
        //              DASHBOARD DATA
        // =============================================

        property bool showingDashboard: false
        property bool showingAllApps: false
        property int openFolderIndex: -1  // index of currently open folder, -1 if none

        // Bumped on every dashboard rebuild. The folder popup sizes itself from
        // dashboardModel.get(i).apps.count, which is reached through a plain JS
        // lookup rather than a tracked binding, so it would otherwise keep the
        // stale size after an item joins or leaves the open folder. Reading this
        // alongside it forces the re-measure, and lets the card animate to it.
        property int folderRevision: 0

        property var dashboardApps: {
            try { return JSON.parse(Plasmoid.configuration.dashboardApps || "[]"); }
            catch(e) { return []; }
        }

        function normalizedDashboardItem(item) {
            if (!item) {
                return item;
            }
            if (item.type === "folder") {
                var folderApps = [];
                var sourceApps = item.apps || [];
                for (var i = 0; i < sourceApps.length; ++i) {
                    var sourceApp = sourceApps[i];
                    var sourceUrl = canonicalApplicationUrl(sourceApp.desktopFile);
                    folderApps.push({
                        desktopFile: sourceUrl || sourceApp.desktopFile,
                        name: sourceApp.name,
                        icon: sourceApp.icon
                    });
                }
                return {type: "folder", name: item.name, apps: folderApps};
            }

            var appUrl = canonicalApplicationUrl(item.desktopFile);
            if (item.type === "auto") {
                return {type: "auto", desktopFile: appUrl || item.desktopFile};
            }
            return {
                desktopFile: appUrl || item.desktopFile,
                name: item.name,
                icon: item.icon
            };
        }

        function saveDashboard() {
            // Saving is also the migration point for IDs written by older code
            // from QUrl.toString(), such as applications:Desktop%20Explorer.
            var normalized = [];
            for (var i = 0; i < rootItem.dashboardApps.length; ++i) {
                normalized.push(normalizedDashboardItem(rootItem.dashboardApps[i]));
            }
            rootItem.dashboardApps = normalized;
            Plasmoid.configuration.dashboardApps = JSON.stringify(normalized);
        }

        function launchDesktopFile(desktopFile) {
            var df = desktopFileFromApplication(desktopFile);
            if (df === "") return;
            var stem = df.replace(/\.desktop$/i, "");
            // Launch through KDE's ApplicationLauncherJob (via kstart) rather than
            // gtk-launch. This is the same code path the Recent Apps view uses via
            // the Kicker model's trigger(), so the .desktop Exec line — including
            // fixed arguments like --no-sandbox — is honoured identically, and the
            // app's StartupWMClass / single-instance handling is respected.
            dashLauncher.connectSource("kstart --application " + shellQuote(stem)
                                       + " #" + Date.now());
        }

        function addToDashboard(desktopFile, name, icon) {
            desktopFile = canonicalApplicationUrl(desktopFile);
            if (desktopFile === "") {
                return;
            }
            // Check if already in dashboard (pinned or in folders)
            for (var i = 0; i < dashboardApps.length; i++) {
                var item = dashboardApps[i];
                if (item.type === "auto") continue;  // a slot, not a pin
                if (sameApplication(item.desktopFile, desktopFile)) return;
                if (item.type === "folder" && item.apps) {
                    for (var j = 0; j < item.apps.length; j++) {
                        if (sameApplication(item.apps[j].desktopFile, desktopFile)) return;
                    }
                }
            }
            // If item is currently auto in the model, promote it to pinned
            if (Plasmoid.configuration.showAllAppsInDashboard) {
                for (var i = 0; i < dashboardModel.count; i++) {
                    var mItem = dashboardModel.get(i);
                    if (sameApplication(mItem.desktopFile, desktopFile)
                            && mItem.type === "auto") {
                        dashboardModel.setProperty(i, "desktopFile", desktopFile);
                        dashboardModel.setProperty(i, "type", "app");
                        syncModelToConfig();
                        return;
                    }
                }
            }
            var apps = dashboardApps.slice();
            apps.push({desktopFile: desktopFile, name: name, icon: icon});
            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
        }

        function removeFromDashboard(desktopFile) {
            desktopFile = canonicalApplicationUrl(desktopFile);
            if (desktopFile === "") {
                return;
            }
            // Unpinning does not have to mean leaving. With all apps shown the
            // tile stays put as an auto one, so the grid keeps its shape and only
            // the pin goes away.
            var keepSlot = Plasmoid.configuration.showAllAppsInDashboard;
            var apps = [];
            var removedFromFolder = false;
            for (var i = 0; i < dashboardApps.length; i++) {
                var item = dashboardApps[i];
                if (item.type !== "folder"
                        && sameApplication(item.desktopFile, desktopFile)) {
                    if (keepSlot && item.type !== "auto") {
                        apps.push({type: "auto", desktopFile: desktopFile});
                    }
                    continue;
                }

                if (item.type === "folder" && item.apps) {
                    var folderApps = item.apps.filter(function(app) {
                        return !rootItem.sameApplication(app.desktopFile, desktopFile);
                    });
                    if (folderApps.length !== item.apps.length) {
                        removedFromFolder = true;
                        if (folderApps.length > 1) {
                            apps.push({type: "folder", name: item.name, apps: folderApps});
                        } else if (folderApps.length === 1) {
                            apps.push({
                                type: "app",
                                desktopFile: folderApps[0].desktopFile,
                                name: folderApps[0].name,
                                icon: folderApps[0].icon
                            });
                        }
                        if (keepSlot) {
                            apps.push({type: "auto", desktopFile: desktopFile});
                        }
                        continue;
                    }
                }
                apps.push(item);
            }
            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
            folderRevision++;
            if (removedFromFolder) {
                openFolderIndex = -1;
            }
        }

        // A working-array index survives the rebuild unchanged: saveFromArray()
        // writes every slot, auto ones included, and reload() lays them back down
        // in the same order. So the plans below can hand out working-array
        // indices as the positions the rebuilt grid will use.

        // --- Folder mutations: plan / commit ---
        //
        // Each of these is split in two. The plan* half is pure — it works out
        // the resulting array and where things end up — and the commit half
        // writes it. Splitting them lets the caller start the transition, hold
        // the write until the motion reaches the point where the grid should
        // change, and tell the rebuilt delegates which arrival beat to play.
        // See the FOLDER CHOREOGRAPHY FX section.

        function planRemoveFromFolder(folderIndex, appDesktopFile) {
            var apps = modelToArray();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return null;

            folder.apps = folder.apps.filter(function(a) {
                return !rootItem.sameApplication(a.desktopFile, appDesktopFile);
            });

            // If folder has 1 or 0 apps left, dissolve it
            if (folder.apps.length === 1) {
                apps[folderIndex] = folder.apps[0];
                apps[folderIndex].type = "app";
            } else if (folder.apps.length === 0) {
                apps.splice(folderIndex, 1);
            } else {
                apps[folderIndex] = folder;
            }

            var survives = (apps[folderIndex] && apps[folderIndex].type === "folder");
            return {
                apps: apps,
                folderIndex: survives ? folderIndex : -1,
                folderSurvives: survives
            };
        }

        function commitFolderPlan(plan) {
            if (!plan) return;
            saveFromArray(plan.apps);
        }


        function reorderInFolder(folderIndex, fromIdx, toIdx) {
            var apps = modelToArray();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return;
            var arr = folder.apps.slice();
            var item = arr.splice(fromIdx, 1)[0];
            arr.splice(toIdx, 0, item);
            folder.apps = arr;
            apps[folderIndex] = folder;
            saveFromArray(apps);
        }

        function planMoveAppOutOfFolder(folderIndex, appIndex) {
            var apps = modelToArray();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return null;
            var arr = folder.apps.slice();
            var item = arr.splice(appIndex, 1)[0];
            // Mark the extracted item as a pinned app
            item.type = "app";

            // Update folder
            if (arr.length === 1) {
                apps[folderIndex] = arr[0]; // dissolve
                apps[folderIndex].type = "app";
            } else if (arr.length === 0) {
                apps.splice(folderIndex, 1);
            } else {
                folder.apps = arr;
                apps[folderIndex] = folder;
            }

            // Add the removed app after the folder position
            var insertIdx = Math.min(folderIndex + 1, apps.length);
            apps.splice(insertIdx, 0, item);

            var survives = (apps[folderIndex] && apps[folderIndex].type === "folder");
            return {
                apps: apps,
                landIndex: insertIdx,
                folderIndex: survives ? folderIndex : -1,
                folderSurvives: survives
            };
        }


        function removeFolder(folderIndex) {
            var apps = modelToArray();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return;
            // Move all apps inside folder to top-level at that position
            var folderApps = folder.apps || [];
            apps.splice(folderIndex, 1);
            for (var i = 0; i < folderApps.length; i++) {
                folderApps[i].type = "app";
                apps.splice(folderIndex + i, 0, folderApps[i]);
            }
            saveFromArray(apps);
            openFolderIndex = -1;
        }

        function planCreateFolder(indexA, indexB) {
            // Merge two dashboard items into a folder
            var apps = modelToArray();
            var itemA = apps[indexA];
            var itemB = apps[indexB];
            if (!itemA || !itemB) return null;

            var folderApps = [];
            var keptIdx;        // working-array slot the surviving folder sits in
            var isNew = false;  // a folder came into being, rather than growing

            // If A is already a folder, add B into it
            if (itemA.type === "folder") {
                folderApps = (itemA.apps || []).slice();
                if (itemB.type === "folder") {
                    folderApps = folderApps.concat(itemB.apps || []);
                } else {
                    folderApps.push({desktopFile: itemB.desktopFile, name: itemB.name, icon: itemB.icon});
                }
                apps[indexA] = {type: "folder", name: itemA.name, apps: folderApps};
                apps.splice(indexB, 1);
                keptIdx = indexB < indexA ? indexA - 1 : indexA;
            }
            // If B is already a folder, add A into it
            else if (itemB.type === "folder") {
                folderApps = (itemB.apps || []).slice();
                folderApps.unshift({desktopFile: itemA.desktopFile, name: itemA.name, icon: itemA.icon});
                apps[indexB] = {type: "folder", name: itemB.name, apps: folderApps};
                apps.splice(indexA, 1);
                keptIdx = indexA < indexB ? indexB - 1 : indexB;
            }
            // Both are regular apps (or auto) — create new folder
            else {
                var folder = {
                    type: "folder",
                    name: i18n("New Folder"),
                    apps: [
                        {desktopFile: itemA.desktopFile, name: itemA.name, icon: itemA.icon},
                        {desktopFile: itemB.desktopFile, name: itemB.name, icon: itemB.icon}
                    ]
                };
                // Replace the target (B) with the folder, remove the dragged (A)
                apps[indexB] = folder;
                apps.splice(indexA, 1);
                keptIdx = indexA < indexB ? indexB - 1 : indexB;
                isNew = true;
            }

            return {apps: apps, folderIndex: keptIdx, isNew: isNew};
        }

        function renameFolder(folderIndex, newName) {
            var apps = modelToArray();
            if (apps[folderIndex] && apps[folderIndex].type === "folder") {
                apps[folderIndex].name = newName;
                saveFromArray(apps);
            }
        }

        // Centre of grid cell `idx`, in root coordinates.
        //
        // Worked out from the grid's fixed cell geometry rather than by asking
        // the delegate where it is. A flight is aimed at the slot an item will
        // end up in, and at the moment of aiming that delegate either does not
        // exist yet or is still sliding towards the slot — either way its own
        // position is the wrong answer. Cell n, on the other hand, is always the
        // same place on screen.
        function cellCentre(grid, idx) {
            var cols = Math.max(1, Math.round(grid.width / grid.cellWidth));
            return grid.mapToItem(rootItem,
                ((idx % cols) + 0.5) * grid.cellWidth - grid.contentX,
                (Math.floor(idx / cols) + 0.5) * grid.cellHeight - grid.contentY);
        }

        // Drops an app out of the open folder and onto the dashboard. The icon
        // flies from wherever it was let go to the slot it will occupy, and the
        // write lands with it so the grid never shows an intermediate state.
        function ejectToDashboard(folderIndex, appIndex, icon, fromX, fromY) {
            var plan = planMoveAppOutOfFolder(folderIndex, appIndex);
            if (!plan) return;

            var dur = root.folderRemoveDuration;
            var to = cellCentre(dashboardGrid, plan.landIndex);
            if (plan.folderSurvives && dur > 0) {
                folderCardRecoil.start();
            }

            dashboardGrid.beginFolderFx(-1, -1, plan.landIndex, dur, function() {
                commitFolderPlan(plan);
            });
            // The rebuild can shift the folder's row; follow it so the popup
            // keeps showing the folder the user is actually looking at.
            openFolderIndex = plan.folderSurvives ? plan.folderIndex : -1;

            folderFx.fly(icon, fromX, fromY, to.x, to.y, dur, 1.0, false);
        }

        // Menu-driven counterpart to ejectToDashboard. A menu click has no drag
        // release point to carry on from, so the icon sets off from the cell it
        // occupies in the folder.
        function ejectFromFolder(folderIndex, appIndex, icon) {
            var from = cellCentre(folderGrid, appIndex);
            ejectToDashboard(folderIndex, appIndex, icon, from.x, from.y);
        }

        // Takes an app out of the folder and off the dashboard entirely. Nothing
        // survives to land, so the icon is flung clear of the card and dissipates.
        function dismissFromFolder(folderIndex, appIndex, appDesktopFile, icon) {
            var plan = planRemoveFromFolder(folderIndex, appDesktopFile);
            if (!plan) return;

            var dur = root.folderRemoveDuration;
            var from = cellCentre(folderGrid, appIndex);
            var cardCx = folderCard.x + folderCard.width / 2;
            var cardCy = folderCard.y + folderCard.height / 2;

            // Thrown straight outwards from the middle of the card, so whichever
            // cell it came from it leaves by the nearest edge.
            var dx = from.x - cardCx;
            var dy = from.y - cardCy;
            var len = Math.sqrt(dx * dx + dy * dy);
            if (len < 1) {
                dx = 0; dy = -1; len = 1;
            }
            var reach = root.cellSize * 1.7;

            if (plan.folderSurvives && dur > 0) {
                folderCardRecoil.start();
            }

            commitFolderPlan(plan);
            if (openFolderIndex === folderIndex) {
                openFolderIndex = plan.folderSurvives ? plan.folderIndex : -1;
            }

            folderFx.fly(icon, from.x, from.y,
                         from.x + (dx / len) * reach, from.y + (dy / len) * reach - reach * 0.25,
                         dur, 0.15, false);
        }

        function isDashboardApp(desktopFile) {
            desktopFile = canonicalApplicationUrl(desktopFile);
            if (desktopFile === "") {
                return false;
            }
            for (var i = 0; i < dashboardApps.length; i++) {
                var item = dashboardApps[i];
                if (item.type === "auto") continue;  // a slot, not a pin
                if (sameApplication(item.desktopFile, desktopFile)) return true;
                if (item.type === "folder" && item.apps) {
                    for (var j = 0; j < item.apps.length; j++) {
                        if (sameApplication(item.apps[j].desktopFile, desktopFile)) return true;
                    }
                }
            }
            return false;
        }

        // Extract dashboardModel into a JS array (including auto items)
        function modelToArray() {
            var arr = [];
            for (var i = 0; i < dashboardModel.count; i++) {
                var item = dashboardModel.get(i);
                if (item.type === "folder") {
                    var folderApps = [];
                    var sa = item.apps;
                    if (sa) {
                        for (var j = 0; j < sa.count; j++) {
                            var sub = sa.get(j);
                            folderApps.push({desktopFile: sub.desktopFile, name: sub.name, icon: sub.icon});
                        }
                    }
                    arr.push({type: "folder", name: item.name, desktopFile: "", icon: "", apps: folderApps});
                } else {
                    arr.push({type: item.type, desktopFile: item.desktopFile, name: item.name, icon: item.icon});
                }
            }
            return arr;
        }

        // Turn one working-array/model item into its persisted form. Auto items
        // are kept as bare placeholders: they carry no name or icon of their own
        // (the all-apps model owns those, and they can change under us) and exist
        // only to remember the slot the user left the app in.
        function persistedItem(item) {
            if (item.type === "folder") {
                return {type: "folder", name: item.name, apps: item.apps};
            }
            if (item.type === "auto") {
                return {type: "auto", desktopFile: item.desktopFile};
            }
            return {desktopFile: item.desktopFile, name: item.name, icon: item.icon};
        }

        // Save from a working array, preserving the arrangement, then reload
        function saveFromArray(arr) {
            var saved = [];
            for (var i = 0; i < arr.length; i++) {
                saved.push(persistedItem(arr[i]));
            }
            dashboardApps = saved;
            saveDashboard();
            dashboardModel.reload();
            folderRevision++;
        }

        // Serialize dashboardModel back to the apps array (handles folders).
        // Auto items are written out as placeholders so a reorder that moves one
        // of them survives the next reload.
        function syncModelToConfig() {
            var apps = [];
            for (var i = 0; i < dashboardModel.count; i++) {
                var item = dashboardModel.get(i);
                if (item.type === "folder") {
                    var folderApps = [];
                    // ListModel stores the sub-array as a ListModel too
                    var sa = item.apps;
                    if (sa) {
                        for (var j = 0; j < sa.count; j++) {
                            var sub = sa.get(j);
                            folderApps.push({desktopFile: sub.desktopFile, name: sub.name, icon: sub.icon});
                        }
                    }
                    apps.push({type: "folder", name: item.name, apps: folderApps});
                } else {
                    apps.push(rootItem.persistedItem(item));
                }
            }
            rootItem.dashboardApps = apps;
            rootItem.saveDashboard();
        }

        ListModel {
            id: dashboardModel

            function reload() {
                clear();

                // Auto items the all-apps model can currently supply, by url.
                var available = {};
                var haveAuto = Plasmoid.configuration.showAllAppsInDashboard
                               && allAppsHelper.active && allAppsHelper.count > 0;
                if (haveAuto) {
                    for (var i = 0; i < allAppsHelper.count; i++) {
                        var obj = allAppsHelper.objectAt(i);
                        if (obj && obj.appUrl) available[obj.appUrl] = obj;
                    }
                }

                var existing = {};
                var apps = rootItem.dashboardApps;
                for (var i = 0; i < apps.length; i++) {
                    var item = apps[i];
                    if (item.type === "folder") {
                        var entry = {type: "folder", name: item.name, desktopFile: "", icon: "",
                                     apps: []};
                        append(entry);
                        // Add sub-apps into the nested ListModel
                        var folderApps = item.apps || [];
                        for (var j = 0; j < folderApps.length; j++) {
                            var folderApp = rootItem.normalizedDashboardItem(folderApps[j]);
                            get(count - 1).apps.append(folderApp);
                            existing[folderApp.desktopFile] = true;
                        }
                    } else if (item.type === "auto") {
                        // A placeholder: the app is not pinned, it just holds the
                        // slot the user put it in. It only reappears while the
                        // all-apps model still lists it, so uninstalled apps fall
                        // out instead of lingering as dead tiles.
                        var autoUrl = rootItem.canonicalApplicationUrl(item.desktopFile)
                                      || item.desktopFile;
                        var src = available[autoUrl];
                        if (!src) continue;
                        append({type: "auto", desktopFile: src.appUrl, name: src.appName,
                                icon: src.appIcon, apps: []});
                        existing[src.appUrl] = true;
                    } else {
                        var pinnedUrl = rootItem.canonicalApplicationUrl(item.desktopFile)
                                        || item.desktopFile;
                        append({type: "app", desktopFile: pinnedUrl,
                                name: item.name, icon: item.icon, apps: []});
                        existing[pinnedUrl] = true;
                    }
                }

                // Everything else the all-apps model knows about — newly installed
                // apps, and the whole list on a dashboard that has never been
                // arranged — goes on the end in the model's own order.
                if (haveAuto) {
                    for (var i = 0; i < allAppsHelper.count; i++) {
                        var obj = allAppsHelper.objectAt(i);
                        if (!obj || !obj.appUrl || existing[obj.appUrl]) continue;
                        append({type: "auto", desktopFile: obj.appUrl, name: obj.appName,
                                icon: obj.appIcon, apps: []});
                    }
                }

                // clear() above scrolled the grid back to the top. Put it back on
                // the page the user is looking at now, in the same frame as the
                // rebuild: the deferred sync on countChanged is a frame or two
                // late, which is long enough for page one to flash past.
                dashboardView.syncPageOffset();
            }

            Component.onCompleted: reload()
        }

        P5Support.DataSource {
            id: dashLauncher
            engine: "executable"
            onNewData: function(source, data) { disconnectSource(source); }
        }

        P5Support.DataSource {
            id: dashPinChecker
            engine: "executable"
            onNewData: function(source, data) {
                var stdout = (data["stdout"] || "").trim();
                disconnectSource(source);
                // See pinChecker: only reflow the menu while it is open, so a
                // late qdbus reply can't push a blur region to a torn-down popup
                // surface and take plasmashell down with it.
                if (dashContextMenu.status !== PlasmaExtras.Menu.Open) {
                    return;
                }
                var result;
                try {
                    result = JSON.parse(stdout);
                } catch (error) {
                    return;
                }
                if (!result || result.url
                        !== rootItem.canonicalApplicationUrl(dashContextMenu.desktopFile)) {
                    return;
                }
                dashPinMenuItem.taskManagerFound = result.found === true;
                dashPinMenuItem.isPinned = result.pinned === true;
            }
        }

        // Flat all-apps model for dashboard "show all apps" mode
        Kicker.RootModel {
            id: flatAllAppsRootModel
            autoPopulate: false
            appNameFormat: Plasmoid.configuration.appNameFormat
            flat: true
            sorted: true
            showSeparators: false
            appletInterface: kicker
            showAllApps: true
            showAllAppsCategorized: false
            showTopLevelItems: false
            showRecentApps: false
            showRecentDocs: false
        }

        property var dashAllAppsModel: null

        Connections {
            target: flatAllAppsRootModel
            function onRefreshed() {
                for (var i = 0; i < flatAllAppsRootModel.count; i++) {
                    if (flatAllAppsRootModel.labelForRow(i) === root.allAppsRowLabel) {
                        rootItem.dashAllAppsModel = flatAllAppsRootModel.modelForRow(i);
                        dashboardModel.reload();
                        return;
                    }
                }
            }
        }

        // Instantiator to extract app data from the Kicker model
        Instantiator {
            id: allAppsHelper
            active: Plasmoid.configuration.showAllAppsInDashboard && rootItem.dashAllAppsModel !== null
            model: rootItem.dashAllAppsModel
            delegate: QtObject {
                property string appUrl: {
                    var url = model.url ? model.url.toString() : "";
                    return rootItem.applicationUrlForModel(model, url);
                }
                property string appName: model.display || ""
                property string appIcon: model.decoration || ""
            }
            onObjectAdded: (index, object) => {
                // Reload dashboard model when all apps become available
                if (index === count - 1 && Plasmoid.configuration.showAllAppsInDashboard) {
                    dashboardModel.reload();
                }
            }
        }

        PlasmaExtras.Menu {
            id: dashContextMenu
            property string desktopFile: ""
            property bool isFolder: false
            property bool isAutoItem: false
            // Set when the menu was opened on an app inside an open folder
            // rather than on a dashboard tile. Everything below the first
            // group applies to both, so the two share this one menu.
            property bool isFolderItem: false
            property int folderIdx: -1
            property int appIndex: -1
            property string appName: ""
            property string appIcon: ""

            onStatusChanged: {
                if (status === PlasmaExtras.Menu.Open && !isFolder
                        && desktopFile !== "") {
                    dashPinMenuItem.isPinned = false;
                    dashPinMenuItem.taskManagerFound = false;
                    rootItem.queryPinState(dashPinChecker, desktopFile);
                }
            }

            // Puts the app back on the dashboard alongside the folder it was in.
            PlasmaExtras.MenuItem {
                text: i18n("Remove from Folder")
                icon: "edit-delete-remove"
                visible: dashContextMenu.isFolderItem
                onClicked: {
                    var fi = dashContextMenu.folderIdx;
                    var ai = dashContextMenu.appIndex;
                    var ic = dashContextMenu.appIcon;
                    dashContextMenu.close();
                    rootItem.ejectFromFolder(fi, ai, ic);
                }
            }
            // Drops the app off the dashboard outright. From inside a folder that
            // means leaving the folder and the board in one go, rather than
            // surfacing onto the dashboard first.
            PlasmaExtras.MenuItem {
                text: i18n("Remove from Dashboard")
                icon: "edit-delete-remove"
                visible: !dashContextMenu.isFolder && !dashContextMenu.isAutoItem
                onClicked: {
                    var fi = dashContextMenu.folderIdx;
                    var ai = dashContextMenu.appIndex;
                    var df = dashContextMenu.desktopFile;
                    var ic = dashContextMenu.appIcon;
                    var fromFolder = dashContextMenu.isFolderItem;
                    dashContextMenu.close();
                    if (fromFolder) {
                        rootItem.dismissFromFolder(fi, ai, df, ic);
                    } else {
                        rootItem.removeFromDashboard(df);
                    }
                }
            }
            PlasmaExtras.MenuItem {
                text: i18n("Pin to Dashboard")
                icon: "pin"
                visible: !dashContextMenu.isFolder && dashContextMenu.isAutoItem && !dashContextMenu.isFolderItem
                onClicked: {
                    var df = dashContextMenu.desktopFile;
                    dashContextMenu.close();
                    rootItem.addToDashboard(df, "", "");
                }
            }
            PlasmaExtras.MenuItem {
                text: i18n("Ungroup Folder")
                icon: "edit-delete-remove"
                visible: dashContextMenu.isFolder
                onClicked: {
                    var idx = dashContextMenu.folderIdx;
                    dashContextMenu.close();
                    rootItem.removeFolder(idx);
                }
            }
            PlasmaExtras.MenuItem {
                text: i18n("Rename Folder")
                icon: "edit-rename"
                visible: dashContextMenu.isFolder
                onClicked: {
                    var idx = dashContextMenu.folderIdx;
                    dashContextMenu.close();
                    // No tile was clicked, so grow from the centre of the screen
                    folderPopup.originX = rootItem.width / 2;
                    folderPopup.originY = rootItem.height / 2;
                    folderPopup.originW = root.iconSize * 0.85 + 8;
                    folderPopup.originH = root.iconSize * 0.85 + 8;
                    rootItem.openFolderIndex = idx;
                    folderPopup.startRename();
                }
            }

            PlasmaExtras.MenuItem { separator: true; visible: !dashContextMenu.isFolder && dashContextMenu.desktopFile !== "" }

            PlasmaExtras.MenuItem {
                id: dashPinMenuItem
                property bool isPinned: false
                property bool taskManagerFound: false
                text: isPinned ? i18n("Unpin from Task Manager") : i18n("Pin to Task Manager")
                icon: isPinned ? "window-unpin" : "window-pin"
                visible: !dashContextMenu.isFolder && dashContextMenu.desktopFile !== ""
                enabled: taskManagerFound
                onClicked: {
                    rootItem.toggleTaskManagerLauncher(dashContextMenu.desktopFile);
                }
            }

            PlasmaExtras.MenuItem { separator: true; visible: !dashContextMenu.isFolder && dashContextMenu.desktopFile !== "" }

            PlasmaExtras.MenuItem {
                text: i18n("Edit Application…")
                icon: "kmenuedit"
                visible: !dashContextMenu.isFolder && dashContextMenu.desktopFile !== ""
                    && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
                onClicked: {
                    // Dashboard tiles are backed by plain config entries, not by a
                    // Kicker model row, so there is no editApplication action to
                    // trigger — go through the same ProcessRunner the plasmoid's
                    // own "Edit Applications…" action uses.
                    var menuId = rootItem.desktopFileFromApplication(
                        dashContextMenu.desktopFile);
                    dashContextMenu.close();
                    closeWithAnimation();
                    if (menuId !== "") {
                        processRunner.runMenuEditor(menuId);
                    }
                }
            }

            PlasmaExtras.MenuItem {
                text: i18n("Uninstall or Manage Add-Ons…")
                icon: "plasmadiscover"
                visible: !dashContextMenu.isFolder && dashContextMenu.desktopFile !== ""
                onClicked: {
                    var appUrl = dashContextMenu.desktopFile;
                    dashContextMenu.close();
                    closeWithAnimation();
                    rootItem.openApplicationInDiscover(appUrl);
                }
            }
        }

        // =============================================
        //           FOLDER CHOREOGRAPHY FX
        // =============================================
        //
        // Creating a folder, dropping an app into one, and pulling one back out
        // all end in dashboardModel.reload(), which tears down and rebuilds
        // every delegate. Motion therefore cannot live on the delegates alone —
        // whatever is mid-animation is destroyed the instant the data changes.
        //
        // So the transition is split across two halves that meet in the middle:
        //
        //   1. This overlay carries the icon in root coordinates, above the
        //      grid and unaffected by the rebuild. It is the thing the eye
        //      follows across the cut.
        //   2. The write is held back until the icon is nearly home (see
        //      dashboardGrid.beginFolderFx), and the rebuilt delegate reads
        //      dashboardGrid.fx* to know which arrival beat to play — a folder
        //      springing into being, one swallowing an icon, or an ejected app
        //      landing.
        //
        // Every piece scales off the caller's duration, so a 0 setting collapses
        // the whole sequence to an instant write.
        Item {
            id: folderFx
            anchors.fill: parent
            z: 9000
            visible: fxFlight.running || fxBurst.running
            enabled: false

            // Flight endpoints, in root coordinates and centred on the icon
            property real fromX: 0
            property real fromY: 0
            property real toX: 0
            property real toY: 0
            property real endScale: 0.35
            property int duration: 400

            // Frosted plate that swells at the destination as the icon arrives —
            // the folder's surface forming under it. Only for merges.
            property bool plateEnabled: false

            // Fraction of the flight after which the icon has effectively
            // arrived. The delegates delay their arrival beat by this much so
            // the two halves meet, even though the data changed up front.
            readonly property real handoff: 0.72

            // Sends `icon` from one point to another. Both points are centres in
            // root coordinates. Purely decorative: the model has already been
            // written by the time this runs, so an interrupted or never-started
            // flight costs nothing but the animation.
            function fly(icon, sx, sy, tx, ty, dur, endScl, withPlate) {
                fxFlight.stop();
                fxBurst.stop();

                if (dur <= 0) {
                    return;
                }

                fxIcon.source = icon || "";
                folderFx.fromX = sx;
                folderFx.fromY = sy;
                folderFx.toX = tx;
                folderFx.toY = ty;
                folderFx.duration = dur;
                folderFx.endScale = endScl;
                folderFx.plateEnabled = withPlate;

                fxPlate.x = tx - fxPlate.width / 2;
                fxPlate.y = ty - fxPlate.height / 2;
                fxRing.x = tx - fxRing.width / 2;
                fxRing.y = ty - fxRing.height / 2;

                fxFlight.start();
            }

            // The icon itself. x and y run on different curves so the path bows
            // rather than tracking a straight line — the arc reads as thrown
            // rather than slid.
            Kirigami.Icon {
                id: fxIcon
                width: root.iconSize
                height: root.iconSize
                animated: false
                opacity: 0
                transformOrigin: Item.Center

                layer.enabled: folderFx.visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.55)
                    shadowBlur: 0.8
                    shadowVerticalOffset: Kirigami.Units.smallSpacing
                    shadowHorizontalOffset: 0
                }
            }

            // Glass surface swelling into place beneath the arriving icon
            Kirigami.ShadowedRectangle {
                id: fxPlate
                width: root.iconSize * 0.85 + 8
                height: width
                radius: width / 5
                color: colorWithAlpha(Kirigami.Theme.backgroundColor, 0.75)
                border.width: 1
                border.color: colorWithAlpha(Kirigami.Theme.textColor, 0.15)
                shadow.size: Kirigami.Units.gridUnit
                shadow.color: Qt.rgba(0, 0, 0, 0.35)
                shadow.yOffset: Kirigami.Units.smallSpacing / 2
                opacity: 0
                scale: 0.3
                transformOrigin: Item.Center
                visible: folderFx.plateEnabled
            }

            // Shockwave marking the moment the two items become one
            Rectangle {
                id: fxRing
                width: root.iconSize * 1.1
                height: width
                radius: width / 3
                color: "transparent"
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
                opacity: 0
                scale: 0.6
                transformOrigin: Item.Center
            }

            ParallelAnimation {
                id: fxFlight

                // Horizontal settles early, vertical keeps travelling — the
                // mismatch is what bends the path.
                NumberAnimation {
                    target: fxIcon; property: "x"
                    from: folderFx.fromX - fxIcon.width / 2
                    to: folderFx.toX - fxIcon.width / 2
                    duration: folderFx.duration
                    easing.type: Easing.OutQuint
                }
                NumberAnimation {
                    target: fxIcon; property: "y"
                    from: folderFx.fromY - fxIcon.height / 2
                    to: folderFx.toY - fxIcon.height / 2
                    duration: folderFx.duration
                    easing.type: Easing.InOutCubic
                }
                // Winds up a touch before being drawn in
                SequentialAnimation {
                    NumberAnimation {
                        target: fxIcon; property: "scale"
                        from: 1.0; to: 1.18
                        duration: Math.round(folderFx.duration * 0.28)
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.4
                    }
                    NumberAnimation {
                        target: fxIcon; property: "scale"
                        to: folderFx.endScale
                        duration: Math.round(folderFx.duration * 0.72)
                        easing.type: Easing.InBack
                        easing.overshoot: 1.1
                    }
                }
                SequentialAnimation {
                    NumberAnimation {
                        target: fxIcon; property: "opacity"
                        from: 0.0; to: 1.0
                        duration: Math.round(folderFx.duration * 0.18)
                    }
                    PauseAnimation { duration: Math.round(folderFx.duration * 0.55) }
                    NumberAnimation {
                        target: fxIcon; property: "opacity"
                        to: 0.0
                        duration: Math.round(folderFx.duration * 0.27)
                        easing.type: Easing.InCubic
                    }
                }
                // Plate rises to meet the icon
                SequentialAnimation {
                    PauseAnimation { duration: Math.round(folderFx.duration * 0.35) }
                    ParallelAnimation {
                        NumberAnimation {
                            target: fxPlate; property: "scale"
                            from: 0.3; to: 1.0
                            duration: Math.round(folderFx.duration * 0.65)
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.0
                        }
                        NumberAnimation {
                            target: fxPlate; property: "opacity"
                            from: 0.0; to: folderFx.plateEnabled ? 0.9 : 0.0
                            duration: Math.round(folderFx.duration * 0.4)
                            easing.type: Easing.OutCubic
                        }
                    }
                    NumberAnimation {
                        target: fxPlate; property: "opacity"
                        to: 0.0
                        duration: Math.round(folderFx.duration * 0.3)
                        easing.type: Easing.InCubic
                    }
                }

                // Shockwave at touchdown, timed to meet the delegate's own
                // arrival beat (which is delayed by the same fraction).
                SequentialAnimation {
                    PauseAnimation { duration: Math.round(folderFx.duration * folderFx.handoff) }
                    ScriptAction { script: fxBurst.start() }
                }
            }

            SequentialAnimation {
                id: fxBurst
                ParallelAnimation {
                    NumberAnimation {
                        target: fxRing; property: "scale"
                        from: 0.6; to: 1.9
                        duration: Math.round(folderFx.duration * 0.75)
                        easing.type: Easing.OutQuint
                    }
                    NumberAnimation {
                        target: fxRing; property: "opacity"
                        from: 0.75; to: 0.0
                        duration: Math.round(folderFx.duration * 0.75)
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // Drag ghost — a lifted, softly-shadowed icon that follows the cursor
        Item {
            id: dragGhost
            visible: false
            width: root.cellSize
            height: root.cellSize
            z: 9999

            property string iconSource: ""
            property string labelText: ""

            // Pick-up lift: springs up in scale when grabbed and settles back on
            // release, so the carried item reads as physically raised off the grid.
            opacity: visible ? 0.92 : 0.0
            scale: visible ? (root.dragMoveDuration > 0 ? 1.16 : 1.0) : 0.9
            transformOrigin: Item.Center

            Behavior on scale {
                NumberAnimation {
                    duration: Math.max(1, root.dragMoveDuration)
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }

            // Gentle continuous tilt while carried — a touch of liquid life
            SequentialAnimation {
                id: dragGhostWobble
                running: dragGhost.visible && root.dragMoveDuration > 0
                loops: Animation.Infinite
                onStopped: dragGhost.rotation = 0
                NumberAnimation { target: dragGhost; property: "rotation"; from: -2.5; to: 2.5; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { target: dragGhost; property: "rotation"; from: 2.5; to: -2.5; duration: 900; easing.type: Easing.InOutSine }
            }

            Kirigami.Icon {
                width: root.iconSize
                height: root.iconSize
                source: dragGhost.iconSource
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Kirigami.Units.smallSpacing
                animated: false

                // Real, shape-aware drop shadow for depth (skipped when off)
                layer.enabled: root.dragMoveDuration > 0
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.55)
                    shadowBlur: 0.8
                    shadowVerticalOffset: Kirigami.Units.smallSpacing
                    shadowHorizontalOffset: 0
                }
            }

            PlasmaComponents.Label {
                text: dragGhost.labelText
                width: parent.width - 4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 1, root.dashboardFontScale)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Kirigami.Units.smallSpacing
            }
        }

        // Timer for folder merge readiness — hold over another icon to arm
        Timer {
            id: folderMergeTimer
            interval: 600
            repeat: false
            property int targetIndex: -1
            onTriggered: {
                if (dashboardGrid.dragFromIndex !== -1 && targetIndex !== -1
                    && dashboardGrid.dragFromIndex !== targetIndex) {
                    dashboardGrid.readyToMerge = true;
                }
            }
        }

        // =============================================
        //              SEARCH FIELD
        // =============================================

        TextField {
            id: searchField
            z: 3
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: categoryRowContainer.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing * 2

            // Hero motion: the pill stretches with a springy overshoot when a
            // query begins, signalling the mode change before results land.
            width: Kirigami.Units.gridUnit * (root.searching ? 22 : 16)
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            leftPadding: Kirigami.Units.largeSpacing * 2 + Kirigami.Units.iconSizes.small
            rightPadding: Kirigami.Units.largeSpacing * 2 + (root.searching ? Kirigami.Units.iconSizes.small : 0)

            Behavior on width {
                NumberAnimation {
                    duration: root.animDuration * 1.3
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }

            Behavior on rightPadding {
                NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
            }

            placeholderText: i18nc("@info:placeholder", "Search applications…")
            horizontalAlignment: TextInput.AlignHCenter
            wrapMode: Text.NoWrap
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1

            onTextChanged: {
                runnerModel.query = searchField.text;
            }

            function clear() {
                text = "";
            }

            background: Rectangle {
                color: colorWithAlpha(Kirigami.Theme.backgroundColor, 0.75)
                radius: height / 2
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus
                    ? Kirigami.Theme.highlightColor
                    : colorWithAlpha(Kirigami.Theme.textColor, 0.08)

                Behavior on border.color {
                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on border.width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            // Search icon — wakes up (accent color + a small pop) while searching
            Kirigami.Icon {
                source: "search"
                width: Kirigami.Units.iconSizes.small
                height: width
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.searching ? 1.0 : 0.5
                color: root.searching ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                scale: root.searching ? 1.15 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root.animDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.0
                    }
                }
            }

            // Clear / back button
            Kirigami.Icon {
                id: clearButton
                source: "edit-clear"
                width: Kirigami.Units.iconSizes.small
                height: width
                anchors.right: parent.right
                anchors.rightMargin: Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter
                visible: root.searching
                opacity: clearMouse.containsMouse ? 1.0 : 0.5
                // Pops in with a playful overshoot once there is text to clear
                scale: root.searching ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root.animDuration * 0.9
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.5
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchField.clear();
                    }
                }
            }

            function appendText(newText) {
                if (!root.visible) return;
                focus = true;
                text = text + newText;
            }

            function backspace() {
                if (!root.visible) return;
                focus = true;
                text = text.slice(0, -1);
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    event.accepted = true;
                    root.focusVisibleContent();
                } else if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    if (root.searching) {
                        root.focusVisibleContent();
                    } else {
                        root.focusCurrentCategory();
                    }
                }
            }
        }

        // =============================================
        //            CATEGORY FILTER ROW
        // =============================================

        Item {
            id: categoryRowContainer
            z: 3

            // Vertical breathing room inside each pill, on top of the label's
            // own implicitHeight. Shared so the pills stay the same height.
            readonly property int pillPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: contentArea.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing * 2
            opacity: root.searching ? 0 : 1
            // Recedes while searching; the OutBack return gives the pills a
            // springy re-entrance when the query is cleared
            scale: root.searching ? 0.9 : 1.0
            enabled: !root.searching

            Behavior on opacity {
                NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.animDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            }

            // Sum children widths to know the single-line (unclipped) width
            property real singleLineWidth: {
                var total = 0;
                for (var i = 0; i < categoryRow.children.length; i++) {
                    var child = categoryRow.children[i];
                    if (child.visible && child.width > 0 && child.height > 0) {
                        if (total > 0) total += categoryRow.spacing;
                        total += child.width;
                    }
                }
                return Math.max(1, total);
            }

            property real maxWidth: parent.width - Kirigami.Units.largeSpacing * 8

            // Scale factor needed to fit everything on a single line
            property real scaleFactor: Math.min(1.0, maxWidth / singleLineWidth)

            // If scaling below 0.7 would be needed, use wrapping instead
            property bool needsWrapping: scaleFactor < 0.7

            // When not wrapping, size to content (centered); when wrapping, use max width
            width: needsWrapping
                ? maxWidth
                : Math.min(singleLineWidth, maxWidth)
            height: categoryRow.implicitHeight * (needsWrapping ? 1.0 : scaleFactor)

        Flow {
            id: categoryRow
            // When wrapping: constrain to container width so items wrap
            // When scaling: use full single-line width so all items stay in one row (scale handles visual fit)
            width: categoryRowContainer.needsWrapping ? parent.width : categoryRowContainer.singleLineWidth
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Kirigami.Units.smallSpacing

            scale: categoryRowContainer.needsWrapping ? 1.0 : categoryRowContainer.scaleFactor
            transformOrigin: Item.Top

            property int currentCategory: -1

            // Dashboard category button
            Rectangle {
                id: dashboardCatBtn
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: dashCatLabel.text
                width: dashCatLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                height: dashCatLabel.implicitHeight + categoryRowContainer.pillPadding
                radius: height / 2
                border.width: activeFocus ? 2 : 0
                border.color: Kirigami.Theme.focusColor

                color: rootItem.showingDashboard
                    ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.85)
                    : dashCatMouse.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.25)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                Behavior on color {
                    ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                }

                scale: dashCatMouse.pressed ? 0.93 : 1.0

                function activate() {
                    if (rootItem.showingDashboard) {
                        root.selectDefaultCategory();
                    } else {
                        rootItem.showingDashboard = true;
                        rootItem.showingAllApps = false;
                        categoryRow.currentCategory = -1;
                        dashboardGrid.animateEntrance();
                    }
                }

                Keys.onReturnPressed: event => {
                    event.accepted = true;
                    activate();
                }
                Keys.onEnterPressed: event => {
                    event.accepted = true;
                    activate();
                }
                Keys.onSpacePressed: event => {
                    event.accepted = true;
                    activate();
                }
                Keys.onDownPressed: event => {
                    event.accepted = true;
                    root.focusVisibleContent();
                }
                Keys.onUpPressed: event => {
                    event.accepted = true;
                    searchField.forceActiveFocus();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        event.accepted = true;
                        root.navigateCategoryFocus(
                            dashboardCatBtn, event.key === Qt.Key_Left ? -1 : 1, true);
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        event.accepted = true;
                        var reverse = event.key === Qt.Key_Backtab
                            || (event.modifiers & Qt.ShiftModifier);
                        root.navigateCategoryFocus(dashboardCatBtn, reverse ? -1 : 1, false);
                    }
                }

                PlasmaComponents.Label {
                    id: dashCatLabel
                    anchors.centerIn: parent
                    text: i18n("Dashboard")
                    font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 0.5, root.categoryFontScale)
                    font.weight: rootItem.showingDashboard ? Font.DemiBold : Font.Normal
                    color: rootItem.showingDashboard
                        ? Kirigami.Theme.highlightedTextColor
                        : Kirigami.Theme.textColor
                }

                MouseArea {
                    id: dashCatMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        dashboardCatBtn.activate();
                    }
                }
            }

            // All Apps category button (sectioned A-Z list)
            Rectangle {
                id: allAppsCatBtn
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: allAppsCatLabel.text
                width: allAppsCatLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                height: allAppsCatLabel.implicitHeight + categoryRowContainer.pillPadding
                radius: height / 2
                border.width: activeFocus ? 2 : 0
                border.color: Kirigami.Theme.focusColor

                color: rootItem.showingAllApps
                    ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.85)
                    : allAppsCatMouse.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.25)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                Behavior on color {
                    ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                }

                scale: allAppsCatMouse.pressed ? 0.93 : 1.0

                function activate() {
                    if (rootItem.showingAllApps) {
                        root.selectDefaultCategory();
                    } else {
                        rootItem.showingDashboard = false;
                        rootItem.showingAllApps = true;
                        categoryRow.currentCategory = -1;
                        allAppsView.populate();
                        allAppsView.animateEntrance();
                    }
                }

                Keys.onReturnPressed: event => {
                    event.accepted = true;
                    activate();
                }
                Keys.onEnterPressed: event => {
                    event.accepted = true;
                    activate();
                }
                Keys.onSpacePressed: event => {
                    event.accepted = true;
                    activate();
                }
                Keys.onDownPressed: event => {
                    event.accepted = true;
                    root.focusVisibleContent();
                }
                Keys.onUpPressed: event => {
                    event.accepted = true;
                    searchField.forceActiveFocus();
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                        event.accepted = true;
                        root.navigateCategoryFocus(
                            allAppsCatBtn, event.key === Qt.Key_Left ? -1 : 1, true);
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        event.accepted = true;
                        var reverse = event.key === Qt.Key_Backtab
                            || (event.modifiers & Qt.ShiftModifier);
                        root.navigateCategoryFocus(allAppsCatBtn, reverse ? -1 : 1, false);
                    }
                }

                PlasmaComponents.Label {
                    id: allAppsCatLabel
                    anchors.centerIn: parent
                    text: i18n("All Apps")
                    font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 0.5, root.categoryFontScale)
                    font.weight: rootItem.showingAllApps ? Font.DemiBold : Font.Normal
                    color: rootItem.showingAllApps
                        ? Kirigami.Theme.highlightedTextColor
                        : Kirigami.Theme.textColor
                }

                MouseArea {
                    id: allAppsCatMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        allAppsCatBtn.activate();
                    }
                }
            }

            Repeater {
                id: categoryRepeater
                model: rootModel

                delegate: Rectangle {
                    id: catBtn
                    activeFocusOnTab: visible
                    Accessible.role: Accessible.Button
                    Accessible.name: categoryLabel

                    readonly property string categoryLabel:
                        model.display === root.allAppsRowLabel ? i18n("Alphabetically")
                        : model.display === root.recentAppsRowLabel ? i18n("Recent Apps")
                        : (model.display || "")

                    // RootModel emits a placeholder row between "All Applications"
                    // and the real categories: empty label, and modelForRow() returns
                    // null. Without this it renders as a blank pill mid-row.
                    visible: categoryLabel.trim().length > 0

                    width: catLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                    height: catLabel.implicitHeight + categoryRowContainer.pillPadding
                    radius: height / 2
                    border.width: activeFocus ? 2 : 0
                    border.color: Kirigami.Theme.focusColor

                    color: categoryRow.currentCategory === index
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.85)
                        : catMouse.containsMouse
                            ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.25)
                            : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                    Behavior on color {
                        ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                    }

                    scale: catMouse.pressed ? 0.93 : 1.0

                    function activate() {
                        if (categoryRow.currentCategory === index) {
                            root.selectDefaultCategory();
                        } else {
                            root.selectCategory(index);
                        }
                    }

                    Keys.onReturnPressed: event => {
                        event.accepted = true;
                        activate();
                    }
                    Keys.onEnterPressed: event => {
                        event.accepted = true;
                        activate();
                    }
                    Keys.onSpacePressed: event => {
                        event.accepted = true;
                        activate();
                    }
                    Keys.onDownPressed: event => {
                        event.accepted = true;
                        root.focusVisibleContent();
                    }
                    Keys.onUpPressed: event => {
                        event.accepted = true;
                        searchField.forceActiveFocus();
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                            event.accepted = true;
                            root.navigateCategoryFocus(
                                catBtn, event.key === Qt.Key_Left ? -1 : 1, true);
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            event.accepted = true;
                            var reverse = event.key === Qt.Key_Backtab
                                || (event.modifiers & Qt.ShiftModifier);
                            root.navigateCategoryFocus(catBtn, reverse ? -1 : 1, false);
                        }
                    }

                    PlasmaComponents.Label {
                        id: catLabel
                        anchors.centerIn: parent
                        text: catBtn.categoryLabel
                        font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 0.5, root.categoryFontScale)
                        font.weight: categoryRow.currentCategory === index ? Font.DemiBold : Font.Normal
                        color: categoryRow.currentCategory === index
                            ? Kirigami.Theme.highlightedTextColor
                            : Kirigami.Theme.textColor
                    }

                    MouseArea {
                        id: catMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            catBtn.activate();
                        }
                    }
                }
            }
        }
        }  // categoryRowContainer

        // =============================================
        //             MAIN CONTENT AREA
        // =============================================

        Item {
            id: contentArea
            width: (root.columns * root.cellSize) + Kirigami.Units.gridUnit
            height: Math.ceil(root.height * 0.6 / root.cellSize) * root.cellSize
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: Kirigami.Units.gridUnit * 2
            }

            // The dashboard settles back a touch as a folder opens, the way One
            // UI pushes the home screen away behind a folder. Paired with the
            // dim, it puts the card on a plane in front of the grid instead of
            // merely on top of it.
            transform: Scale {
                origin.x: contentArea.width / 2
                origin.y: contentArea.height / 2
                xScale: 1 - 0.05 * Math.min(1, folderPopup.openProgress)
                yScale: 1 - 0.05 * Math.min(1, folderPopup.openProgress)
            }

        StackView {
            id: mainView
            // Stays visible while a transition runs so leaving search animates
            // out instead of snapping off under the returning view
            visible: (!rootItem.showingDashboard && !rootItem.showingAllApps && !root.showingRecent)
                     || root.searching || mainView.busy
            anchors.fill: parent

            initialItem: Column {
                id: allAppsColumn
                clip: true
                spacing: Kirigami.Units.largeSpacing * 2

                // Mirrors contentArea.height — using parent.height here would feed
                // back into the Column's implicit height.
                readonly property int fullGridHeight: Math.ceil(root.height * 0.6 / root.cellSize) * root.cellSize

                readonly property int chromeHeight: backButton.visible ? backButton.height + spacing : 0

                readonly property int gridHeight: fullGridHeight - chromeHeight

                // Back button for letter sub-model navigation.
                // Not gated on `searching` — during a search this page is the
                // covered StackView base, and hiding the button mid-exit-fade
                // makes the layout visibly jump (reset() clears parentModel
                // when search ends, so it never lingers).
                Rectangle {
                    id: backButton
                    visible: allAppsGrid.parentModel !== null
                    activeFocusOnTab: visible
                    Accessible.role: Accessible.Button
                    Accessible.name: backText.text
                    width: backLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                    height: visible ? backLabel.implicitHeight + Kirigami.Units.largeSpacing : 0
                    radius: height / 2
                    border.width: activeFocus ? 2 : 0
                    border.color: Kirigami.Theme.focusColor
                    color: backMouse.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.3)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                    Behavior on color {
                        ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                    }

                    scale: backMouse.pressed ? 0.93 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                    }

                    Row {
                        id: backLabel
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "go-previous"
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        PlasmaComponents.Label {
                            id: backText
                            text: i18n("All Letters")
                            font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 0.5, root.allAppsFontScale)
                            color: Kirigami.Theme.textColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    function activate() {
                        allAppsGrid.model = allAppsGrid.parentModel;
                        allAppsGrid.parentModel = null;
                        allAppsGrid.currentIndex = -1;
                        allAppsGrid.animateEntrance();
                    }

                    Keys.onReturnPressed: event => {
                        event.accepted = true;
                        activate();
                    }
                    Keys.onEnterPressed: event => {
                        event.accepted = true;
                        activate();
                    }
                    Keys.onSpacePressed: event => {
                        event.accepted = true;
                        activate();
                    }
                    Keys.onDownPressed: event => {
                        event.accepted = true;
                        allAppsGrid.tryActivate(0, 0);
                        allAppsGrid.forceActiveFocus();
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backButton.activate();
                        }
                    }
                }

                ItemGridView {
                    id: allAppsGrid
                    labelFontScale: root.allAppsFontScale
                    width: parent.width
                    height: allAppsColumn.gridHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    cellWidth: root.cellSize
                    cellHeight: cellWidth
                    iconSize: root.iconSize
                    dragEnabled: false
                    dropEnabled: false
                    animatedEntrance: true

                    // When the Dashboard, A-Z, or Recent view owns the stage this
                    // grid is just the StackView's idle base page — keep it fully
                    // hidden so it can't flash while the search push runs.
                    opacity: (rootItem.showingDashboard || rootItem.showingAllApps || root.showingRecent) ? 0 : 1

                    property var parentModel: null

                    // Only the top level of the "Alphabetically" category lists
                    // letters; every other category — and any letter you drill
                    // into — lists apps, which keep the normal caption.
                    groupLabels: parentModel === null
                        && categoryRow.currentCategory >= 0
                        && rootModel.labelForRow(categoryRow.currentCategory) === root.allAppsRowLabel

                    onItemChildActivated: index => {
                        var childModel = allAppsGrid.model.modelForRow(index);
                        if (childModel) {
                            allAppsGrid.parentModel = allAppsGrid.model;
                            allAppsGrid.model = childModel;
                            allAppsGrid.currentIndex = -1;
                            allAppsGrid.animateEntrance();
                        }
                    }

                    onKeyNavDown: {
                        allAppsGrid.focus = false;
                        root.focusSystemActionsOrFallback();
                    }
                    onKeyNavUp: {
                        allAppsGrid.focus = false;
                        searchField.focus = true;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            allAppsGrid.focus = false;
                            root.focusSystemActionsOrFallback();
                        } else if (event.key === Qt.Key_Backspace) {
                            event.accepted = true;
                            if (allAppsGrid.parentModel) {
                                allAppsGrid.model = allAppsGrid.parentModel;
                                allAppsGrid.parentModel = null;
                                allAppsGrid.currentIndex = -1;
                                allAppsGrid.animateEntrance();
                            } else {
                                searchField.forceActiveFocus();
                                searchField.backspace();
                            }
                        } else if (event.key === Qt.Key_Escape) {
                            event.accepted = true;
                            if (allAppsGrid.parentModel) {
                                allAppsGrid.model = allAppsGrid.parentModel;
                                allAppsGrid.parentModel = null;
                                allAppsGrid.currentIndex = -1;
                                allAppsGrid.animateEntrance();
                            } else if (root.searching) {
                                reset();
                            } else {
                                closeWithAnimation();
                            }
                        } else if (event.text !== "" && !(event.modifiers & Qt.ControlModifier)) {
                            event.accepted = true;
                            searchField.forceActiveFocus();
                            searchField.appendText(event.text);
                        }
                    }
                }
            }

            // Shared-Z-axis transitions: entering search, the new page rises
            // from behind (scales up) with a spring settle while the old page
            // zooms slightly toward the viewer and fades. Popping reverses the
            // depth so leaving search feels like stepping back out.
            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0; to: 1
                        duration: root.animDuration * 0.7
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 0.9; to: 1
                        duration: root.animDuration * 1.2
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
            }
            pushExit: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: root.animDuration * 0.45
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        to: 1.08
                        duration: root.animDuration * 0.45
                        easing.type: Easing.InCubic
                    }
                }
            }
            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0; to: 1
                        duration: root.animDuration * 0.7
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        from: 1.08; to: 1
                        duration: root.animDuration * 0.7
                        easing.type: Easing.OutCubic
                    }
                }
            }
            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: root.animDuration * 0.45
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "scale"
                        to: 0.9
                        duration: root.animDuration * 0.45
                        easing.type: Easing.InCubic
                    }
                }
            }
        }

        // =============================================
        //        ALL APPS SECTIONED GRID (A-Z)
        // =============================================

        Item {
            id: allAppsView
            // Animated hand-off instead of a visibility snap: fades while
            // zooming slightly toward the viewer (shared-Z depth), matching
            // the search push underneath
            readonly property bool shown: rootItem.showingAllApps && !root.searching
            visible: opacity > 0.01
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 1.05
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: root.animDuration * 0.8; easing.type: Easing.OutCubic }
            }

            property var alphaModel: null

            function populate() {
                // Find the all-apps row in rootModel
                var idx = -1;
                for (var i = 0; i < rootModel.count; i++) {
                    if (rootModel.labelForRow(i) === root.allAppsRowLabel) {
                        idx = i;
                        break;
                    }
                }
                if (idx === -1) return;
                alphaModel = rootModel.modelForRow(idx);
                if (!alphaModel) return;

                // Build letter sections
                var sections = [];
                for (var i = 0; i < alphaModel.count; i++) {
                    var letter = alphaModel.labelForRow(i) || "";
                    var letterModel = alphaModel.modelForRow(i);
                    if (letterModel && letterModel.count > 0) {
                        sections.push({ letter: letter, letterIndex: i, model: letterModel });
                    }
                }
                sectionRepeater.model = sections;
            }

            function animateEntrance() {
                for (var i = 0; i < sectionRepeater.count; i++) {
                    var section = sectionRepeater.itemAt(i);
                    if (section) {
                        var grid = section.grid;
                        if (grid && grid.animateEntrance) {
                            grid.animateEntrance();
                        }
                    }
                }
            }

            function resetEntrance() {
                for (var i = 0; i < sectionRepeater.count; i++) {
                    var section = sectionRepeater.itemAt(i);
                    if (section) {
                        var grid = section.grid;
                        if (grid && grid.resetEntrance) {
                            grid.resetEntrance();
                        }
                    }
                }
            }

            function focusSection(sectionIndex, row, col) {
                if (sectionRepeater.count <= 0) {
                    searchField.forceActiveFocus();
                    return;
                }
                sectionIndex = Math.max(0, Math.min(sectionIndex, sectionRepeater.count - 1));
                var section = sectionRepeater.itemAt(sectionIndex);
                if (!section || !section.grid) {
                    return;
                }
                var top = section.y;
                var maxY = Math.max(0, allAppsFlickable.contentHeight - allAppsFlickable.height);
                allAppsFlickable.contentY = Math.max(0, Math.min(top, maxY));
                section.grid.tryActivate(row, col);
                section.grid.forceActiveFocus();
            }

            function ensureContentVisible(top, itemHeight) {
                var viewportTop = allAppsFlickable.contentY;
                var viewportBottom = viewportTop + allAppsFlickable.height;
                var targetY = viewportTop;
                if (top < viewportTop) {
                    targetY = top;
                } else if (top + itemHeight > viewportBottom) {
                    targetY = top + itemHeight - allAppsFlickable.height;
                }
                var maxY = Math.max(0, allAppsFlickable.contentHeight
                                       - allAppsFlickable.height);
                allAppsFlickable.contentY = Math.max(0, Math.min(targetY, maxY));
            }

            // Close launcher when clicking empty space
            MouseArea {
                anchors.fill: parent
                onClicked: closeWithAnimation()
                z: -1
            }

            Flickable {
                id: allAppsFlickable
                anchors.fill: parent
                contentHeight: allAppsSectionsColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 1500

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var delta = event.angleDelta.y;
                        allAppsFlickable.contentY = Math.max(0,
                            Math.min(allAppsFlickable.contentY - delta * 2,
                                     allAppsFlickable.contentHeight - allAppsFlickable.height));
                        event.accepted = true;
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                }

                Column {
                    id: allAppsSectionsColumn
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing

                    Repeater {
                        id: sectionRepeater

                        delegate: Column {
                            property int sectionIndex: index
                            property alias grid: letterGrid
                            width: allAppsSectionsColumn.width
                            spacing: Kirigami.Units.smallSpacing

                            // Letter header
                            Item {
                                width: parent.width
                                height: sectionLbl.implicitHeight + Kirigami.Units.largeSpacing * 2

                                PlasmaComponents.Label {
                                    id: sectionLbl
                                    anchors {
                                        left: parent.left
                                        leftMargin: Kirigami.Units.largeSpacing
                                        bottom: parent.bottom
                                        bottomMargin: Kirigami.Units.smallSpacing
                                    }
                                    text: modelData.letter
                                    font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize + 10, root.allAppsFontScale)
                                    font.weight: Font.Bold
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.85
                                }

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: Kirigami.Units.largeSpacing
                                        rightMargin: Kirigami.Units.largeSpacing
                                    }
                                    height: 1
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.1
                                }
                            }

                            // App grid for this letter
                            ItemGridView {
                                id: letterGrid
                                labelFontScale: root.allAppsFontScale
                                width: parent.width
                                // Calculate height based on number of rows needed
                                height: Math.ceil(modelData.model.count
                                                  / Math.max(1, Math.floor(width / root.cellSize)))
                                        * root.cellSize
                                cellWidth: root.cellSize
                                cellHeight: root.cellSize
                                iconSize: root.iconSize
                                model: modelData.model
                                dragEnabled: false
                                dropEnabled: false
animatedEntrance: true
                                verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff

                                onCurrentIndexChanged: {
                                    if (currentIndex < 0) {
                                        return;
                                    }
                                    var itemTop = parent.y + y
                                        + currentRow() * cellHeight;
                                    allAppsView.ensureContentVisible(itemTop, cellHeight);
                                }

                                onKeyNavDown: {
                                    if (parent.sectionIndex + 1 < sectionRepeater.count) {
                                        allAppsView.focusSection(parent.sectionIndex + 1, 0, currentCol());
                                    } else {
                                        focus = false;
                                        root.focusSystemActionsOrFallback();
                                    }
                                }
                                onKeyNavUp: {
                                    if (parent.sectionIndex > 0) {
                                        var previous = sectionRepeater.itemAt(parent.sectionIndex - 1);
                                        var previousRow = previous && previous.grid ? previous.grid.lastRow() : 0;
                                        allAppsView.focusSection(parent.sectionIndex - 1,
                                                                 Math.max(0, previousRow),
                                                                 currentCol());
                                    } else {
                                        focus = false;
                                        searchField.forceActiveFocus();
                                    }
                                }
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab) {
                                        event.accepted = true;
                                        focus = false;
                                        root.focusSystemActionsOrFallback();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =============================================
        //           DASHBOARD GRID (category view)
        // =============================================

        Item {
            id: dashboardView
            // Same animated hand-off as allAppsView — see comment there
            readonly property bool shown: rootItem.showingDashboard && !root.searching
            visible: opacity > 0.01
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 1.05
            anchors.fill: parent

            Behavior on opacity {
                NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: root.animDuration * 0.8; easing.type: Easing.OutCubic }
            }

            property int currentPage: 0
            property int pageCount: Math.max(1, Math.ceil(dashboardModel.count / root.itemsPerPage))

            // Where the user has asked to end up. currentPage is walked toward
            // it one leg at a time, so a request landing mid-transition never
            // tears down the leg already playing — it just extends the walk.
            property int targetPage: 0

            // Whether that walk visits every page on the way. A scroll is a
            // relative gesture, so it does; the page dots are random access, so
            // they go straight there.
            property bool walkPages: false

            // Leg duration multiplier. Shortens as the backlog grows, so a fast
            // scroll shows every page it passes through without turning into a
            // long queue of full-length transitions. Recomputed once per leg
            // rather than bound to the backlog, so a notch arriving mid-leg
            // cannot re-time the animation that is already playing.
            property real pageSpeed: 1.0

            // How far the grid drifts sideways during a page change. Purely
            // cosmetic — see the note on goToPage.
            readonly property real pageSlideDistance: Kirigami.Units.gridUnit * 4

            // The grid flows left-to-right, so its scroll axis is *vertical*:
            // page N is the same column of items, dashRows further down. Paging
            // by contentX therefore had nowhere to go — it slid the whole grid
            // out of its own clip rect, which is why every page past the first
            // came up blank and unclickable.
            //
            // The horizontal read is kept as a shared-axis-X transition (the
            // transform below) rather than by reflowing top-to-bottom: a
            // column-major grid would break reading order — the alphabetical
            // run would go down each column instead of across each row — and
            // every index-based drag, folder and reorder path in here assumes
            // model index == row-major position.
            // Jump straight to a page — random access, for the page dots.
            function goToPage(page) {
                requestPage(page, false);
            }

            // One page along from wherever the grid is heading. Wheel navigation
            // goes through this rather than goToPage(currentPage ± 1): during a
            // transition currentPage is already the destination of the leg in
            // flight, so counting from it would make every notch in a burst ask
            // for the same page and the burst would move one page in total.
            function stepPage(delta) {
                requestPage(targetPage + delta, true);
            }

            function requestPage(page, walk) {
                targetPage = Math.max(0, Math.min(page, pageCount - 1));
                walkPages = walk;
                // A leg in flight picks the next one up itself when it lands.
                if (!pageAnimation.running) {
                    startNextLeg();
                }
            }

            // Advances one page toward targetPage, or straight to it when the
            // request was random access. Arriving is what ends the walk: this
            // is a no-op once there is nothing left to travel.
            function startNextLeg() {
                if (targetPage === currentPage) return;
                var dir = targetPage > currentPage ? 1 : -1;
                var next = walkPages ? currentPage + dir : targetPage;
                // Pages still to come after this one. A lone page change scores 0
                // and runs at full length; a backlog shortens each leg toward a
                // floor that still leaves every page a few frames on screen.
                var remaining = Math.abs(targetPage - next);
                pageSpeed = Math.max(0.45, 1 - 0.2 * remaining);
                currentPage = next;
                dashboardGrid.cancelFlick();
                pageSlideOut.to = dir > 0 ? -pageSlideDistance : pageSlideDistance;
                pageSlideIn.from = dir > 0 ? pageSlideDistance : -pageSlideDistance;
                pageAnimation.start();
            }

            // Re-applies the page offset without animating. A folder edit or an
            // "Add to Dashboard" rebuilds the model, which collapses contentY
            // back to the top, and a resize changes how many rows fit on a page
            // — in both cases the dots would otherwise keep claiming a page the
            // grid is no longer showing.
            function syncPageOffset() {
                currentPage = Math.max(0, Math.min(currentPage, pageCount - 1));
                targetPage = Math.max(0, Math.min(targetPage, pageCount - 1));
                if (pageAnimation.running) return;
                // Lay the grid out before scrolling it. Straight after a rebuild
                // the GridView's own geometry still belongs to the cleared model
                // — there is only one page of content as far as it is concerned —
                // so an offset assigned now is clamped back to the top and the
                // first page shows through until the next layout pass.
                dashboardGrid.forceLayout();
                dashboardGrid.contentY = currentPage * dashboardGrid.height;
            }

            function resetToFirstPage() {
                // Both land before the stop: stopping starts the next leg, and
                // it has to find nothing left to walk to.
                currentPage = 0;
                targetPage = 0;
                pageAnimation.stop();
                pageSpeed = 1.0;
                pageSlide.x = 0;
                dashboardGrid.opacity = 1;
                dashboardGrid.contentY = 0;
            }

            SequentialAnimation {
                id: pageAnimation

                // Outgoing page leaves in the direction of travel and dissolves.
                ParallelAnimation {
                    NumberAnimation {
                        id: pageSlideOut
                        target: pageSlide; property: "x"
                        duration: Math.round(root.animDuration * 0.45 * dashboardView.pageSpeed)
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: dashboardGrid; property: "opacity"
                        to: 0
                        duration: Math.round(root.animDuration * 0.4 * dashboardView.pageSpeed)
                        easing.type: Easing.InCubic
                    }
                }

                // The page change proper. Deliberately parked here, at zero
                // opacity: crossing into a page whose delegates do not exist yet
                // builds a screenful of them in one frame, and this is the one
                // moment in the transition where that costs nothing to look at.
                ScriptAction {
                    script: {
                        dashboardGrid.contentY = dashboardView.currentPage * dashboardGrid.height;
                        pageSlide.x = pageSlideIn.from;
                    }
                }

                // Incoming page arrives from the opposite side.
                ParallelAnimation {
                    NumberAnimation {
                        id: pageSlideIn
                        target: pageSlide; property: "x"
                        to: 0
                        duration: Math.round(root.animDuration * 0.75 * dashboardView.pageSpeed)
                        easing.type: Easing.OutQuint
                    }
                    NumberAnimation {
                        target: dashboardGrid; property: "opacity"
                        from: 0; to: 1
                        duration: Math.round(root.animDuration * 0.6 * dashboardView.pageSpeed)
                        easing.type: Easing.OutCubic
                    }
                }

                // Fires on interruption as well as completion — a page change
                // cut short must never strand the grid faded out and offset to
                // the side. The walk continues from here rather than from
                // onFinished so the two are in a guaranteed order (restore, then
                // carry on) without depending on which of stopped/finished Qt
                // emits first.
                onStopped: {
                    pageSlide.x = 0;
                    dashboardGrid.opacity = 1;
                    dashboardView.startNextLeg();
                }
            }

            // Close launcher when clicking empty space in the dashboard.
            // Uses drag threshold to avoid closing when swiping between pages.
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton

                property int pressStartX: -1
                property int pressStartY: -1

                onPressed: mouse => {
                    var cPos = mapToItem(dashboardGrid.contentItem, mouse.x, mouse.y);
                    var idx = dashboardGrid.indexAt(cPos.x, cPos.y);
                    if (idx !== -1) {
                        mouse.accepted = false; // delegate will handle it
                    } else {
                        pressStartX = mouse.x;
                        pressStartY = mouse.y;
                    }
                }

                onReleased: mouse => {
                    if (pressStartX !== -1) {
                        var dx = mouse.x - pressStartX;
                        var dy = mouse.y - pressStartY;
                        // Only close if it was a tap, not a swipe
                        if (dx * dx + dy * dy < 400) {
                            closeWithAnimation();
                        }
                    }
                    pressStartX = -1;
                    pressStartY = -1;
                }
            }

            GridView {
                id: dashboardGrid
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: root.columns * root.cellSize
                height: root.dashRows * root.cellSize
                cellWidth: root.cellSize
                cellHeight: root.cellSize
                clip: true
                flow: GridView.FlowLeftToRight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                snapMode: GridView.NoSnap
                interactive: false

                // Sideways drift of a page change. Cosmetic only — the page
                // itself is a contentY jump. See dashboardView.goToPage.
                transform: Translate { id: pageSlide }

                // Pads the content out to a whole number of pages. A part-filled
                // last page is shorter than one screenful, so without this the
                // Flickable clamps contentY on the next layout pass and the last
                // page slides back up onto the previous one's rows.
                footer: Item {
                    width: dashboardGrid.width
                    height: Math.max(0, (dashboardView.pageCount * root.dashRows
                                         - Math.ceil(dashboardGrid.count / root.columns))
                                        * root.cellSize)
                }

                // Both of these land mid-rebuild/mid-resize, when the geometry
                // they need is not settled yet; callLater also collapses the
                // count churn of a full model reload into a single sync.
                onCountChanged: Qt.callLater(dashboardView.syncPageOffset)
                onHeightChanged: Qt.callLater(dashboardView.syncPageOffset)

                property int dragFromIndex: -1
                property int dragStartIndex: -1     // where the drag began, to detect a real reorder
                // Grid-level "a drag is active" flag. The dragged item is tracked
                // by index (dragFromIndex), not by delegate instance, so live
                // model.move()s during the drag stay correct even as GridView
                // re-binds delegates to data.
                property bool dragActive: false
                property int hoverTargetIndex: -1  // for folder merge highlight
                property bool readyToMerge: false   // armed after holding over target 600ms

                // --- Folder choreography hand-off ---
                // A folder write rebuilds every delegate, so the arrival beat is
                // addressed by index and picked up in Component.onCompleted. Set
                // these immediately before the write; fxClearTimer takes them
                // down afterwards so a later, unrelated reload cannot replay it.
                property int fxBirthIndex: -1    // a folder springs into being here
                property int fxAbsorbIndex: -1   // a folder here swallows an icon
                property int fxLandIndex: -1     // an app ejected from a folder lands here
                property int fxDuration: 0
                property int fxDelay: 0          // held back until the icon lands

                // Arms the arrival beat, then performs the write. The write is
                // called directly rather than being queued behind the animation:
                // persisting the user's change must not depend on an animation
                // finishing, or an interrupted flight silently loses the edit.
                // The delegates instead wait out fxDelay before they animate.
                function beginFolderFx(birthIdx, absorbIdx, landIdx, dur, write) {
                    fxBirthIndex = birthIdx;
                    fxAbsorbIndex = absorbIdx;
                    fxLandIndex = landIdx;
                    fxDuration = dur;
                    fxDelay = Math.round(dur * folderFx.handoff);
                    write();
                    if (dur > 0) {
                        fxClearTimer.restart();
                    } else {
                        fxClearTimer.stop();
                        clearFolderFx();
                    }
                }

                function clearFolderFx() {
                    fxBirthIndex = -1;
                    fxAbsorbIndex = -1;
                    fxLandIndex = -1;
                }

                // Lives on the grid rather than the delegate's MouseArea: a merge
                // defers this until the flight lands, by which point the delegate
                // that started the drag may already be gone.
                function endDrag() {
                    readyToMerge = false;
                    hoverTargetIndex = -1;
                    dragFromIndex = -1;
                    dragStartIndex = -1;
                    dragActive = false;
                }

                Timer {
                    id: fxClearTimer
                    // Must outlast the held-back start as well as the beat itself
                    interval: Math.max(1, dashboardGrid.fxDelay + dashboardGrid.fxDuration * 2)
                    repeat: false
                    onTriggered: dashboardGrid.clearFolderFx()
                }

                // Entrance animation trigger
                property bool _entranceTriggered: false

                function animateEntrance() {
                    _entranceTriggered = false;
                    Qt.callLater(function() { _entranceTriggered = true; });
                }
                function resetEntrance() {
                    _entranceTriggered = false;
                }

                function focusIndex(index) {
                    if (count <= 0) {
                        searchField.forceActiveFocus();
                        return;
                    }
                    currentIndex = Math.max(0, Math.min(index, count - 1));
                    dashboardView.goToPage(Math.floor(currentIndex / root.itemsPerPage));
                    forceActiveFocus();
                }

                function activateFirstVisible() {
                    focusIndex(dashboardView.currentPage * root.itemsPerPage);
                }

                onActiveFocusChanged: {
                    if (!activeFocus) {
                        currentIndex = -1;
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        event.accepted = true;
                        if (currentIndex > 0 && currentIndex % root.columns !== 0) {
                            focusIndex(currentIndex - 1);
                        }
                    } else if (event.key === Qt.Key_Right) {
                        event.accepted = true;
                        if (currentIndex >= 0 && currentIndex < count - 1
                                && currentIndex % root.columns !== root.columns - 1) {
                            focusIndex(currentIndex + 1);
                        }
                    } else if (event.key === Qt.Key_Up) {
                        event.accepted = true;
                        if (currentIndex >= root.columns) {
                            focusIndex(currentIndex - root.columns);
                        } else {
                            searchField.forceActiveFocus();
                        }
                    } else if (event.key === Qt.Key_Down) {
                        event.accepted = true;
                        if (currentIndex >= 0 && currentIndex + root.columns < count) {
                            focusIndex(currentIndex + root.columns);
                        } else {
                            root.focusSystemActionsOrFallback();
                        }
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                               || event.key === Qt.Key_Space) {
                        event.accepted = true;
                        if (currentItem && currentItem.activate) {
                            currentItem.activate(true);
                        }
                    } else if (event.key === Qt.Key_Menu) {
                        event.accepted = true;
                        if (currentItem && currentItem.openContextMenu) {
                            currentItem.openContextMenu();
                        }
                    } else if (event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        root.focusSystemActionsOrFallback();
                    }
                }

                model: dashboardModel

                // Icons part fluidly to make room for the dragged one
                moveDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: root.dragMoveDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
                    }
                }

                delegate: Item {
                    id: dashDelegate
                    width: dashboardGrid.cellWidth
                    height: dashboardGrid.cellHeight

                    property int itemIndex: index
                    property bool isFolder: model.type === "folder"
                    property bool entranceComplete: root.iconEntranceDuration <= 0
                    Accessible.role: Accessible.Button
                    Accessible.name: model.name || ""
                    Accessible.description: isFolder ? i18n("Folder") : ""
                    Accessible.onPressAction: activate(true)

                    function openContextMenu(x, y) {
                        dashContextMenu.isFolderItem = false;
                        dashContextMenu.appIndex = -1;
                        if (isFolder) {
                            dashContextMenu.isFolder = true;
                            dashContextMenu.isAutoItem = false;
                            dashContextMenu.folderIdx = itemIndex;
                            dashContextMenu.desktopFile = "";
                            dashContextMenu.appName = "";
                            dashContextMenu.appIcon = "";
                        } else {
                            dashContextMenu.isFolder = false;
                            dashContextMenu.isAutoItem = (model.type === "auto");
                            dashContextMenu.folderIdx = -1;
                            dashContextMenu.desktopFile = model.desktopFile;
                            dashContextMenu.appName = model.name || "";
                            dashContextMenu.appIcon = model.icon || "";
                            dashPinMenuItem.isPinned = false;
                            dashPinMenuItem.taskManagerFound = false;
                        }
                        dashContextMenu.visualParent = dashDelegate;
                        menuOpenTimer.openMenu(dashContextMenu,
                                               x === undefined ? width / 2 : x,
                                               y === undefined ? height / 2 : y);
                    }

                    function activate(showKeyboardFocus) {
                        if (isFolder) {
                            var fc = folderPreviewBox.mapToItem(rootItem,
                                                               folderPreviewBox.width / 2,
                                                               folderPreviewBox.height / 2);
                            var folderIndex = itemIndex;
                            var focusVisible = showKeyboardFocus === true;
                            folderPopup.originX = fc.x;
                            folderPopup.originY = fc.y;
                            folderPopup.originW = folderPreviewBox.plateSize;
                            folderPopup.originH = folderPreviewBox.plateSize;
                            rootItem.openFolderIndex = folderIndex;
                            Qt.callLater(function() {
                                if (rootItem.openFolderIndex === folderIndex) {
                                    folderGrid.focusIndex(0, focusVisible);
                                }
                            });
                        } else {
                            launchAppFromItem(model.desktopFile, dashDelegate);
                        }
                    }

                    // Staggered entrance animation — dashEntranceAnim drives the
                    // 0.7 → 1 spring; this binding only handles hover afterwards
                    opacity: root.iconEntranceDuration > 0 ? 0 : 1
                    scale: (entranceComplete
                            && (dashMA.containsMouse || dashboardGrid.currentIndex === itemIndex)
                            && !dashMA.dragging) ? 1.06 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                    }

                    // Folder choreography works on its own transform so it can
                    // overlap the hover scale above without the two clobbering
                    // each other's bindings.
                    transform: [
                        Scale {
                            id: fxDelegateScale
                            origin.x: dashDelegate.width / 2
                            origin.y: dashDelegate.height / 2
                            xScale: 1.0
                            yScale: 1.0
                        },
                        Rotation {
                            id: fxDelegateRotation
                            origin.x: dashDelegate.width / 2
                            origin.y: dashDelegate.height / 2
                            angle: 0
                        }
                    ]

                    // Puts the delegate back to its resting, fully visible state.
                    // The folder beats below hide it on the way in, and this is
                    // what guarantees it always comes back.
                    function restoreFromFx() {
                        dashDelegate.opacity = 1;
                        fxDelegateScale.xScale = 1.0;
                        fxDelegateScale.yScale = 1.0;
                        fxDelegateRotation.angle = 0;
                    }

                    Component.onCompleted: {
                        // Delegates created after entrance already triggered (e.g. scrolling to page 2+)
                        // should appear immediately instead of staying invisible
                        if (dashboardGrid._entranceTriggered) {
                            dashDelegate.entranceComplete = true;
                            dashDelegate.opacity = 1;
                        }
                        // This delegate is the result of a folder operation that
                        // just rebuilt the grid — play its half of the transition.
                        // The two that arrive from nothing are put into their
                        // starting state here rather than relying on the
                        // animation's `from`, which would otherwise show one
                        // frame at full size before it takes hold.
                        if (dashboardGrid.fxBirthIndex === dashDelegate.itemIndex) {
                            dashDelegate.opacity = 0;
                            fxDelegateScale.xScale = 0.25;
                            fxDelegateScale.yScale = 0.25;
                            folderBirthAnim.start();
                        } else if (dashboardGrid.fxAbsorbIndex === dashDelegate.itemIndex) {
                            folderAbsorbAnim.start();
                        } else if (dashboardGrid.fxLandIndex === dashDelegate.itemIndex) {
                            dashDelegate.opacity = 0;
                            fxDelegateScale.xScale = 0.4;
                            fxDelegateScale.yScale = 0.4;
                            itemLandAnim.start();
                        }
                    }

                    // A folder coming into existence: bursts out oversized and
                    // overshoots down into place, with a shake as it settles.
                    // Held back until the flying icon reaches it — the write
                    // already happened, so this waits for the picture to agree.
                    SequentialAnimation {
                        id: folderBirthAnim
                        // These beats start the delegate hidden, so whatever
                        // happens they must not be able to leave it that way —
                        // onStopped fires on interruption as well as completion.
                        onStopped: dashDelegate.restoreFromFx()
                        PauseAnimation { duration: dashboardGrid.fxDelay }
                        ParallelAnimation {
                        NumberAnimation {
                            targets: [fxDelegateScale]
                            properties: "xScale,yScale"
                            from: 0.25; to: 1.0
                            duration: Math.round(dashboardGrid.fxDuration * 1.15)
                            easing.type: Easing.OutBack
                            easing.overshoot: 3.2
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: fxDelegateRotation; property: "angle"
                                from: -14; to: 7
                                duration: Math.round(dashboardGrid.fxDuration * 0.45)
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: fxDelegateRotation; property: "angle"
                                to: 0
                                duration: Math.round(dashboardGrid.fxDuration * 0.7)
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.6
                            }
                        }
                        NumberAnimation {
                            target: dashDelegate; property: "opacity"
                            from: 0.0; to: 1.0
                            duration: Math.round(dashboardGrid.fxDuration * 0.4)
                            easing.type: Easing.OutCubic
                        }
                        }
                    }

                    // An existing folder swallowing an icon: a squash-and-swell
                    // gulp, so the folder visibly reacts to what it just took in.
                    SequentialAnimation {
                        id: folderAbsorbAnim
                        onStopped: dashDelegate.restoreFromFx()
                        PauseAnimation { duration: dashboardGrid.fxDelay }
                        NumberAnimation {
                            targets: [fxDelegateScale]
                            properties: "xScale,yScale"
                            from: 1.0; to: 0.82
                            duration: Math.round(dashboardGrid.fxDuration * 0.22)
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            targets: [fxDelegateScale]
                            properties: "xScale,yScale"
                            to: 1.0
                            duration: Math.round(dashboardGrid.fxDuration * 0.78)
                            easing.type: Easing.OutBack
                            easing.overshoot: 3.6
                        }
                    }

                    // An app pulled back out of a folder, arriving on the grid.
                    SequentialAnimation {
                        id: itemLandAnim
                        onStopped: dashDelegate.restoreFromFx()
                        PauseAnimation { duration: dashboardGrid.fxDelay }
                        ParallelAnimation {
                            NumberAnimation {
                                targets: [fxDelegateScale]
                                properties: "xScale,yScale"
                                from: 0.4; to: 1.0
                                duration: Math.round(dashboardGrid.fxDuration * 1.05)
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.8
                            }
                            NumberAnimation {
                                target: dashDelegate; property: "opacity"
                                from: 0.0; to: 1.0
                                duration: Math.round(dashboardGrid.fxDuration * 0.45)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Connections {
                        target: dashboardGrid
                        function on_EntranceTriggeredChanged() {
                            if (root.iconEntranceDuration <= 0) {
                                dashDelegate.entranceComplete = true;
                                dashDelegate.opacity = 1;
                                return;
                            }
                            if (dashboardGrid._entranceTriggered) {
                                // Diagonal wave rather than a row-at-a-time march:
                                // row * 40 held the bottom row back by most of a
                                // second on a tall grid.
                                // FlowLeftToRight: model index -> row = floor(i/cols), col = i%cols
                                var ip = dashDelegate.itemIndex % root.itemsPerPage;
                                dashEntranceTimer.interval = root.entranceDelay(
                                    Math.floor(ip / root.columns), ip % root.columns);
                                dashEntranceTimer.start();
                            } else {
                                dashEntranceAnim.stop();
                                dashEntranceTimer.stop();
                                dashDelegate.entranceComplete = false;
                                dashDelegate.opacity = 0;
                            }
                        }
                    }

                    Timer {
                        id: dashEntranceTimer
                        repeat: false
                        onTriggered: dashEntranceAnim.start()
                    }

                    ParallelAnimation {
                        id: dashEntranceAnim
                        NumberAnimation {
                            target: dashDelegate
                            property: "opacity"
                            from: 0; to: 1
                            duration: Math.round(root.iconEntranceDuration * 0.5)
                            easing.type: Easing.OutCubic
                        }
                        // Settles down from oversized — same curve as
                        // ItemGridDelegate so both grids enter identically.
                        NumberAnimation {
                            target: dashDelegate
                            property: "scale"
                            from: 1.22; to: 1.0
                            duration: Math.round(root.iconEntranceDuration * 0.75)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.12, 0.8, 0.24, 1.04, 1.0, 1.0]
                        }
                        onStarted: dashDelegate.entranceComplete = true
                    }

                    // GridView's current item is otherwise invisible: the delegates
                    // only had a hover treatment, so keyboard focus appeared lost.
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.iconSize + Kirigami.Units.largeSpacing * 2
                        height: width
                        radius: width / 4
                        color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.22)
                        border.width: 2
                        border.color: Kirigami.Theme.focusColor
                        opacity: dashboardGrid.activeFocus
                                 && dashboardGrid.currentIndex === dashDelegate.itemIndex ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: root.hoverEffectDuration }
                        }
                    }

                    // Highlight when another icon is held over this one (folder merge target)
                    Rectangle {
                        id: mergeHighlight
                        anchors.centerIn: parent
                        width: root.iconSize + Kirigami.Units.largeSpacing * 2
                        height: width
                        radius: width / 4
                        color: Kirigami.Theme.highlightColor
                        // Only the armed (folder-merge) state fills — the plain
                        // "drop here to reorder" hover is shown by dropTargetOutline
                        opacity: {
                            if (dashboardGrid.dragFromIndex === -1 || dashboardGrid.dragFromIndex === dashDelegate.itemIndex) return 0;
                            if (dashboardGrid.hoverTargetIndex !== dashDelegate.itemIndex) return 0;
                            return dashboardGrid.readyToMerge ? 0.55 : 0;
                        }
                        scale: dashboardGrid.readyToMerge && dashboardGrid.hoverTargetIndex === dashDelegate.itemIndex ? 1.15 : 1.0
                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6
                            }
                        }

                        // Expanding ring pulse once the merge is armed — a clear
                        // "release to group into a folder" signal
                        Rectangle {
                            id: mergePulseRing
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: parent.radius
                            color: "transparent"
                            border.width: 2
                            border.color: Kirigami.Theme.highlightColor
                            opacity: 0
                            visible: root.dragMoveDuration > 0
                                     && dashboardGrid.readyToMerge
                                     && dashboardGrid.hoverTargetIndex === dashDelegate.itemIndex

                            SequentialAnimation {
                                running: mergePulseRing.visible
                                loops: Animation.Infinite
                                ParallelAnimation {
                                    NumberAnimation { target: mergePulseRing; property: "scale"; from: 1.0; to: 1.5; duration: 700; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: mergePulseRing; property: "opacity"; from: 0.6; to: 0.0; duration: 700; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }

                    // Drop placeholder — frames the live gap (the empty slot the
                    // dragged icon will drop into). The surrounding icons have
                    // already slid aside to open it, so this just marks the spot.
                    Rectangle {
                        id: dropTargetOutline
                        anchors.centerIn: parent
                        width: root.iconSize + Kirigami.Units.largeSpacing * 2
                        height: width
                        radius: width / 4
                        color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
                        opacity: (dashboardGrid.dragActive
                                  && dashboardGrid.dragFromIndex === dashDelegate.itemIndex
                                  && !dashboardGrid.readyToMerge) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        scale: (opacity > 0.01) ? 1.0 : 0.85
                        Behavior on opacity {
                            NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                        }
                    }

                    // === APP DELEGATE ===
                    Column {
                        id: appContent
                        visible: !dashDelegate.isFolder
                        anchors.centerIn: parent
                        spacing: 2
                        // Hide whichever delegate currently holds the dragged item
                        // (tracked by index, since live moves re-bind delegates)
                        opacity: (dashboardGrid.dragActive && dashboardGrid.dragFromIndex === dashDelegate.itemIndex) ? 0.0 : 1.0
                        Behavior on opacity { NumberAnimation { duration: root.hoverEffectDuration } }

                        Kirigami.Icon {
                            width: root.iconSize
                            height: root.iconSize
                            source: model.icon || ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            animated: false
                        }

                        PlasmaComponents.Label {
                            text: model.name || ""
                            width: root.cellSize - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 1, root.dashboardFontScale)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // === FOLDER DELEGATE ===
                    Column {
                        id: folderContent
                        visible: dashDelegate.isFolder
                        anchors.centerIn: parent
                        spacing: 2

                        // Hidden while dragged, as app tiles are — and handed off
                        // to the popup while this folder is the one open: the card
                        // has taken this tile's place, so leaving it on screen
                        // would show the same folder twice. Tracked with the
                        // popup's own progress so it comes back exactly as the
                        // card collapses back onto it.
                        readonly property bool handedToPopup: folderPopup.visible
                                                              && folderPopup.displayedFolderIndex === dashDelegate.itemIndex
                        opacity: {
                            if (dashboardGrid.dragActive && dashboardGrid.dragFromIndex === dashDelegate.itemIndex) return 0.0;
                            if (handedToPopup) return Math.max(0, 1 - folderPopup.openProgress * 2.5);
                            return 1.0;
                        }
                        Behavior on opacity {
                            enabled: !folderContent.handedToPopup
                            NumberAnimation { duration: root.hoverEffectDuration }
                        }

                        // Mini-grid preview (2x2 icons) — same outer size as app icon for alignment
                        Item {
                            id: folderPreviewBox
                            width: root.iconSize
                            height: root.iconSize
                            anchors.horizontalCenter: parent.horizontalCenter

                            // The square the popup grows out of, published so the
                            // click handler can hand the popup an exact rect
                            readonly property real plateSize: root.iconSize * 0.85 + 8

                            Rectangle {
                                width: folderPreviewBox.plateSize
                                height: folderPreviewBox.plateSize
                                anchors.centerIn: parent
                                radius: width / 5
                                color: Kirigami.Theme.backgroundColor
                                opacity: 0.5
                            }

                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 2
                                property int miniSize: (root.iconSize * 0.85 - 6) / 2

                                Repeater {
                                    model: {
                                        if (!dashDelegate.isFolder) return 0;
                                        var item = dashboardModel.get(dashDelegate.itemIndex);
                                        if (!item || !item.apps) return 0;
                                        return Math.min(item.apps.count, 4);
                                    }
                                    delegate: Kirigami.Icon {
                                        width: parent.miniSize
                                        height: parent.miniSize
                                        source: {
                                            if (dashDelegate.itemIndex < 0 || dashDelegate.itemIndex >= dashboardModel.count) return "";
                                            var item = dashboardModel.get(dashDelegate.itemIndex);
                                            if (!item || !item.apps || index >= item.apps.count) return "";
                                            return item.apps.get(index).icon || "";
                                        }
                                        animated: false
                                    }
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            text: model.name || ""
                            width: root.cellSize - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 1, root.dashboardFontScale)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: dashMA
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        property int pressX: -1
                        property int pressY: -1
                        property bool dragging: false

                        onPressed: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                dashDelegate.openContextMenu(mouse.x, mouse.y);
                            } else {
                                pressX = mouse.x;
                                pressY = mouse.y;
                            }
                        }

                        onReleased: mouse => {
                            folderMergeTimer.stop();
                            // Reset up front: the merge below rebuilds the grid and
                            // destroys this delegate along with the MouseArea running
                            // this handler, so trailing statements may never run.
                            var wasDragging = dragging;
                            pressX = -1;
                            pressY = -1;

                            if (wasDragging) {
                                dragging = false;
                                dragGhost.visible = false;

                                if (dashboardGrid.readyToMerge && dashboardGrid.hoverTargetIndex !== -1
                                    && dashboardGrid.hoverTargetIndex !== dashboardGrid.dragFromIndex) {
                                    // Held over a target long enough — merge into a folder.
                                    var plan = rootItem.planCreateFolder(dashboardGrid.dragFromIndex,
                                                                         dashboardGrid.hoverTargetIndex);
                                    dashboardGrid.endDrag();
                                    if (plan) {
                                        var dur = plan.isNew ? root.folderCreateDuration : root.folderAddDuration;
                                        var ghostX = dragGhost.x + dragGhost.width / 2;
                                        var ghostY = dragGhost.y + dragGhost.height / 2;
                                        var to = rootItem.cellCentre(dashboardGrid, plan.folderIndex);

                                        // Flight first: it is decoration and touches
                                        // nothing the write needs, and starting it here
                                        // means it still plays even though the write
                                        // below tears this delegate down mid-handler.
                                        folderFx.fly(dragGhost.iconSource, ghostX, ghostY,
                                                     to.x, to.y, dur, 0.4, true);

                                        // The new folder is held invisible for the length
                                        // of the flight by fxDelay, so it still reads as
                                        // arriving with the icon rather than ahead of it.
                                        dashboardGrid.beginFolderFx(
                                            plan.isNew ? plan.folderIndex : -1,
                                            plan.isNew ? -1 : plan.folderIndex,
                                            -1, dur,
                                            function() { rootItem.commitFolderPlan(plan); });
                                    }
                                } else {
                                    // Reordered live during the drag — persist the new
                                    // order. Drag state cleared first, for the same
                                    // reason as above.
                                    var reordered = dashboardGrid.dragFromIndex !== dashboardGrid.dragStartIndex;
                                    dashboardGrid.endDrag();
                                    if (reordered) {
                                        rootItem.syncModelToConfig();
                                    }
                                }
                            } else if (mouse.button === Qt.LeftButton) {
                                dashDelegate.activate(false);
                            }
                        }

                        onPositionChanged: mouse => {
                            if (pressX !== -1 && !dragging) {
                                var dx = mouse.x - pressX;
                                var dy = mouse.y - pressY;
                                if (dx*dx + dy*dy > 400) {
                                    dragging = true;
                                    dashboardGrid.dragFromIndex = dashDelegate.itemIndex;
                                    dashboardGrid.dragStartIndex = dashDelegate.itemIndex;
                                    dashboardGrid.dragActive = true;
                                    if (dashDelegate.isFolder) {
                                        dragGhost.iconSource = "folder";
                                        dragGhost.labelText = model.name || i18n("Folder");
                                    } else {
                                        dragGhost.iconSource = model.icon;
                                        dragGhost.labelText = model.name;
                                    }
                                    dragGhost.visible = true;
                                }
                            }
                            if (dragging) {
                                var globalPos = mapToItem(rootItem, mouse.x, mouse.y);
                                dragGhost.x = globalPos.x - dragGhost.width / 2;
                                dragGhost.y = globalPos.y - dragGhost.height / 2;

                                var mapped = mapToItem(dashboardGrid.contentItem, mouse.x, mouse.y);
                                var overIdx = dashboardGrid.indexAt(mapped.x, mapped.y);
                                var fromIdx = dashboardGrid.dragFromIndex;

                                // Over empty space, or over the gap the dragged item
                                // already occupies — nothing to do.
                                if (overIdx === -1 || overIdx === fromIdx) {
                                    dashboardGrid.hoverTargetIndex = -1;
                                    dashboardGrid.readyToMerge = false;
                                    folderMergeTimer.stop();
                                    return;
                                }

                                var overItem = dashboardGrid.itemAtIndex(overIdx);
                                if (!overItem) return;

                                // Cursor position within the hovered cell (0..1)
                                var relX = (mapped.x - overItem.x) / dashboardGrid.cellWidth;
                                var relY = (mapped.y - overItem.y) / dashboardGrid.cellHeight;
                                var inCenter = relX > 0.30 && relX < 0.70 && relY > 0.30 && relY < 0.70;

                                // Has the cursor crossed past the hovered cell's centre,
                                // heading away from the gap? A dot product against the
                                // travel direction handles horizontal and row-changing
                                // moves alike.
                                var overCx = overItem.x + dashboardGrid.cellWidth / 2;
                                var overCy = overItem.y + dashboardGrid.cellHeight / 2;
                                var crossed = true;
                                var fromItem = dashboardGrid.itemAtIndex(fromIdx);
                                if (fromItem) {
                                    var fromCx = fromItem.x + dashboardGrid.cellWidth / 2;
                                    var fromCy = fromItem.y + dashboardGrid.cellHeight / 2;
                                    var dot = (mapped.x - overCx) * (overCx - fromCx)
                                            + (mapped.y - overCy) * (overCy - fromCy);
                                    crossed = dot > 0;
                                }

                                if (inCenter && !crossed) {
                                    // Dwelling on the heart of another icon → offer a
                                    // folder merge; the gap stays put so the target is a
                                    // stable thing to drop onto.
                                    if (dashboardGrid.hoverTargetIndex !== overIdx) {
                                        dashboardGrid.readyToMerge = false;
                                        dashboardGrid.hoverTargetIndex = overIdx;
                                        folderMergeTimer.targetIndex = overIdx;
                                        folderMergeTimer.restart();
                                    }
                                } else if (crossed) {
                                    // Passed the icon's centre → slide it aside and move
                                    // the gap here so the grid previews the drop result.
                                    dashboardGrid.hoverTargetIndex = -1;
                                    dashboardGrid.readyToMerge = false;
                                    folderMergeTimer.stop();
                                    dashboardModel.move(fromIdx, overIdx, 1);
                                    dashboardGrid.dragFromIndex = overIdx;
                                } else {
                                    // Approaching but not yet centred — hold steady
                                    dashboardGrid.hoverTargetIndex = -1;
                                    dashboardGrid.readyToMerge = false;
                                    folderMergeTimer.stop();
                                }
                            }
                        }
                    }
                }
            }

            // Mouse wheel page navigation
            MouseArea {
                anchors.fill: dashboardGrid
                acceptedButtons: Qt.NoButton
                z: 1
                property real wheelAccum: 0
                onWheel: wheel => {
                    wheel.accepted = true;
                    var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    wheelAccum += delta;
                    // Require at least 120 units (one standard notch) to change page
                    if (wheelAccum >= 120) {
                        wheelAccum = 0;
                        dashboardView.stepPage(-1);
                    } else if (wheelAccum <= -120) {
                        wheelAccum = 0;
                        dashboardView.stepPage(1);
                    }
                }
            }

            // Page indicator dots
            Row {
                id: pageIndicator
                visible: dashboardView.pageCount > 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: dashboardGrid.bottom
                anchors.topMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                z: 5

                Repeater {
                    model: dashboardView.pageCount
                    delegate: Rectangle {
                        readonly property bool isCurrent: dashboardView.currentPage === index

                        // Active page stretches into a pill (Material 3 style)
                        width: isCurrent ? Kirigami.Units.smallSpacing * 5 : Kirigami.Units.smallSpacing * 2
                        height: Kirigami.Units.smallSpacing * 2
                        radius: height / 2
                        color: isCurrent
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.textColor
                        opacity: isCurrent ? 1.0 : 0.3

                        Behavior on width {
                            NumberAnimation {
                                duration: root.animDuration * 0.9
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Kirigami.Units.smallSpacing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dashboardView.goToPage(index);
                            }
                        }
                    }
                }
            }

            // Empty state
            PlasmaComponents.Label {
                visible: dashboardModel.count === 0 && !Plasmoid.configuration.showAllAppsInDashboard
                anchors.centerIn: parent
                text: i18n("Right-click an app and choose \"Add to Dashboard\"")
                opacity: 0.5
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
            }
        }

        // =============================================
        //        RECENT APPS / FILES VIEW
        // =============================================

        RecentView {
            id: recentView
            anchors.fill: parent
        }

        } // end contentArea

        // =============================================
        //           FOLDER POPUP OVERLAY
        // =============================================

        Item {
            id: folderPopup
            visible: folderPopupOpen || folderCloseAnim.running
            anchors.fill: parent
            z: 100

            property bool folderPopupOpen: rootItem.openFolderIndex !== -1 && rootItem.showingDashboard
            property int lastOpenedFolderIndex: -1
            property int displayedFolderIndex: folderPopupOpen ? rootItem.openFolderIndex : lastOpenedFolderIndex

            // The on-screen rect of the folder tile's preview square, in this
            // item's coordinates. The card literally starts life as that square
            // and travels to the centre while growing, One UI style, so the tile
            // and the open folder read as the same object. Defaults to a small
            // box at the screen centre for openings with no tile to come from
            // (e.g. rename straight after a folder is created).
            property real originX: width / 2
            property real originY: height / 2
            property real originW: root.iconSize * 0.85 + 8
            property real originH: root.iconSize * 0.85 + 8

            // 0 = collapsed onto the folder tile, 1 = the open, centred card.
            // Everything about the transition — position, scale, dim, content
            // fade, the tile's own disappearance — is derived from this one
            // value, so the beats can never drift out of step with each other.
            property real openProgress: 0

            // Card contents trail the container, as One UI does: the panel
            // establishes itself first and the folder's guts arrive into it.
            readonly property real contentProgress: Math.max(0, Math.min(1, (openProgress - 0.3) / 0.5))

            // True only once the card has finished springing open, so the size
            // Behaviors engage for genuine content changes and nothing else.
            // Testing folderOpenAnim.running instead raced: the size bindings
            // can re-evaluate on folderPopupOpen before start() has been called,
            // which let the opening frame animate as if it were a resize.
            property bool sizeSettled: false

            onFolderPopupOpenChanged: {
                if (folderPopupOpen) {
                    lastOpenedFolderIndex = rootItem.openFolderIndex;
                    sizeSettled = false;
                    // Both animations drive openProgress, so whichever is in
                    // flight has to yield before the other takes over —
                    // otherwise a fast reopen leaves two writers fighting.
                    folderCloseAnim.stop();
                    folderOpenAnim.start();
                } else {
                    folderGrid.keyboardFocusVisible = false;
                    // The icons need no teardown of their own: contentProgress
                    // follows openProgress down, so they dissolve back into the
                    // tile as part of the same collapse.
                    sizeSettled = false;
                    folderOpenAnim.stop();
                    folderCloseAnim.start();
                }
            }

            // The card unfolds out of the tile and glides to the centre; closing
            // rewinds the same path, faster and without the overshoot so
            // dismissal feels decisive rather than bouncy.
            NumberAnimation {
                id: folderOpenAnim
                target: folderPopup; property: "openProgress"
                from: 0; to: 1
                duration: root.folderPopupDuration * 1.5
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
                onFinished: folderPopup.sizeSettled = true
            }

            NumberAnimation {
                id: folderCloseAnim
                target: folderPopup; property: "openProgress"
                to: 0
                duration: root.folderPopupDuration * 0.85
                easing.type: Easing.InCubic
                onFinished: folderPopup.lastOpenedFolderIndex = -1
            }

            // Card kicks back when an app is torn out of it — the container
            // reacting to losing something, rather than silently reflowing.
            // Deliberately on its own Scale node: the open/close transform is
            // bound to openProgress, and an animation writing to those same
            // properties would break the binding for good.
            SequentialAnimation {
                id: folderCardRecoil
                NumberAnimation {
                    targets: [folderCardRecoilScale]
                    properties: "xScale,yScale"
                    from: 1.0; to: 1.06
                    duration: Math.round(root.folderRemoveDuration * 0.25)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    targets: [folderCardRecoilScale]
                    properties: "xScale,yScale"
                    to: 1.0
                    duration: Math.round(root.folderRemoveDuration * 0.75)
                    easing.type: Easing.OutBack
                    easing.overshoot: 3.0
                }
            }


            function startRename() {
                folderNameEdit.readOnly = false;
                folderNameEdit.selectAll();
                folderNameEdit.forceActiveFocus();
            }

            // Dim background
            Rectangle {
                id: folderDimBg
                anchors.fill: parent
                color: "black"
                // Leads the card slightly so the backdrop has already receded
                // by the time the panel arrives at the centre
                opacity: 0.45 * Math.min(1, folderPopup.openProgress * 1.6)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        rootItem.openFolderIndex = -1;
                    }
                }
            }

            // Folder card — frosted glass panel with soft depth
            Kirigami.ShadowedRectangle {
                id: folderCard
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.largeSpacing * 4,
                                folderGrid.columns * root.cellSize
                                    + Kirigami.Units.largeSpacing * 4)
                height: folderNameEdit.height + folderGrid.height + Kirigami.Units.largeSpacing * 4

                // Squircle-to-panel morph. The card is scaled down at the start
                // of the transition, which shrinks the drawn radius too, so the
                // collapsed value is pre-divided by that scale: width/5 rendered
                // through collapsedXScale comes out as the tile's own plate
                // radius (plateSize/5), and it eases to a flat 22 as it opens.
                radius: {
                    var collapsed = Math.min(width, height) / 5;
                    return 22 + (collapsed - 22) * (1 - Math.min(1, folderPopup.openProgress));
                }
                color: colorWithAlpha(Kirigami.Theme.backgroundColor, 0.85)

                // The card only resizes while it is already open — when an app
                // joins or leaves the folder — so it stretches to its new shape
                // instead of snapping. Held off during the open/close spring,
                // which is already carrying its own scale.
                readonly property bool resizeAnimated: root.folderRemoveDuration > 0
                                                       && folderPopup.folderPopupOpen
                                                       && folderPopup.sizeSettled
                Behavior on width {
                    enabled: folderCard.resizeAnimated
                    NumberAnimation {
                        duration: root.folderRemoveDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }
                Behavior on height {
                    enabled: folderCard.resizeAnimated
                    NumberAnimation {
                        duration: root.folderRemoveDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }

                // Glass edge + a soft cast shadow lift the card off the backdrop
                border.width: 1
                border.color: colorWithAlpha(Kirigami.Theme.textColor, 0.12)
                shadow.size: Kirigami.Units.gridUnit * 2.5
                shadow.color: Qt.rgba(0, 0, 0, 0.5)
                shadow.yOffset: Kirigami.Units.smallSpacing * 1.5

                visible: folderPopup.visible
                // Only the panel itself fades, and early — by a third of the way
                // in it is solid and the rest of the move is pure geometry.
                opacity: Math.min(1, folderPopup.openProgress * 3)

                // Where the card would have to sit, and how far it would have to
                // shrink, to exactly cover the folder tile's preview square.
                // Scaling x and y separately means the card genuinely takes the
                // tile's shape at rest instead of merely being small there.
                readonly property real collapsedXScale: folderPopup.originW / Math.max(1, width)
                readonly property real collapsedYScale: folderPopup.originH / Math.max(1, height)

                // Morphs out of the folder tile: scales up about its own centre
                // while translating from the tile's position to the middle of
                // the screen. Both are driven off openProgress, so the card
                // tracks a single curve and the two never disagree.
                transform: [
                    Scale {
                        id: folderCardScale
                        origin.x: folderCard.width / 2
                        origin.y: folderCard.height / 2
                        xScale: folderCard.collapsedXScale
                               + (1 - folderCard.collapsedXScale) * folderPopup.openProgress
                        yScale: folderCard.collapsedYScale
                               + (1 - folderCard.collapsedYScale) * folderPopup.openProgress
                    },
                    Scale {
                        id: folderCardRecoilScale
                        origin.x: folderCard.width / 2
                        origin.y: folderCard.height / 2
                        xScale: 1.0
                        yScale: 1.0
                    },
                    Translate {
                        x: (1 - folderPopup.openProgress)
                           * (folderPopup.originX - (folderCard.x + folderCard.width / 2))
                        y: (1 - folderPopup.openProgress)
                           * (folderPopup.originY - (folderCard.y + folderCard.height / 2))
                    }
                ]

                // Folder name (editable on click)
                TextInput {
                    id: folderNameEdit
                    anchors.top: parent.top
                    anchors.topMargin: Kirigami.Units.largeSpacing * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var idx = folderPopup.displayedFolderIndex;
                        if (idx >= 0 && idx < dashboardModel.count) {
                            return dashboardModel.get(idx).name || "";
                        }
                        return "";
                    }
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    // Arrives with the folder's contents, after the panel has
                    // taken shape — see folderPopup.contentProgress
                    opacity: folderPopup.contentProgress
                    readOnly: true
                    selectByMouse: true
                    width: folderCard.width - Kirigami.Units.largeSpacing * 4

                    onAccepted: {
                        readOnly = true;
                        rootItem.renameFolder(rootItem.openFolderIndex, text);
                    }

                    Keys.onEscapePressed: {
                        readOnly = true;
                        // Guard the index like every other dashboardModel.get()
                        // here: openFolderIndex can be stale after a rebuild, and
                        // get() past the end returns null → null.name throws.
                        var idx = rootItem.openFolderIndex;
                        text = (idx >= 0 && idx < dashboardModel.count)
                            ? (dashboardModel.get(idx).name || "")
                            : "";
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: folderNameEdit.readOnly
                        cursorShape: Qt.IBeamCursor
                        onDoubleClicked: {
                            folderPopup.startRename();
                        }
                    }
                }

                // Folder contents grid
                GridView {
                    id: folderGrid
                    anchors.top: folderNameEdit.bottom
                    anchors.topMargin: Kirigami.Units.largeSpacing
                    anchors.horizontalCenter: parent.horizontalCenter

                    // rootItem.folderRevision is read purely to re-run these on
                    // every rebuild — apps.count is reached through a get() and
                    // does not notify on its own. See rootItem.folderRevision.
                    property int columns: {
                        var revision = rootItem.folderRevision;
                        var idx = folderPopup.displayedFolderIndex;
                        if (idx < 0 || idx >= dashboardModel.count) return 3;
                        var item = dashboardModel.get(idx);
                        if (!item || !item.apps) return 3;
                        var cnt = item.apps.count;
                        var desired = cnt <= 4 ? 2 : (cnt <= 9 ? 3 : 4);
                        var fitting = Math.max(1, Math.floor(
                            (folderPopup.width - Kirigami.Units.largeSpacing * 4)
                                / root.cellSize));
                        return Math.min(desired, fitting);
                    }

                    property int dragFromIndex: -1
                    property int dragStartIndex: -1
                    property bool dragActive: false
                    // The grid always takes focus so a pointer-opened modal can
                    // immediately receive Escape and navigation keys. Keep the
                    // blue selection treatment keyboard-only, though: active
                    // focus by itself must not make a mouse click look like a
                    // selection of the first app.
                    property bool keyboardFocusVisible: false
                    readonly property real requiredHeight: {
                        var revision = rootItem.folderRevision;
                        var idx = folderPopup.displayedFolderIndex;
                        if (idx < 0 || idx >= dashboardModel.count) return root.cellSize;
                        var item = dashboardModel.get(idx);
                        if (!item || !item.apps) return root.cellSize;
                        return Math.max(root.cellSize,
                                        Math.ceil(item.apps.count / columns) * root.cellSize);
                    }
                    readonly property real maximumHeight: Math.max(
                        root.cellSize,
                        folderPopup.height * 0.8 - folderNameEdit.height
                            - Kirigami.Units.largeSpacing * 4)

                    // Lives on the grid, not the delegate's MouseArea, and is
                    // called before any write: committing rebuilds this grid's
                    // model and destroys the delegate mid-handler, so anything
                    // left until afterwards may never run. Stale drag state here
                    // renders whichever item holds that index invisible.
                    function endDrag() {
                        dragFromIndex = -1;
                        dragStartIndex = -1;
                        dragActive = false;
                    }

                    function focusIndex(index, showKeyboardFocus) {
                        if (count <= 0) {
                            return;
                        }
                        keyboardFocusVisible = showKeyboardFocus !== false;
                        currentIndex = Math.max(0, Math.min(index, count - 1));
                        positionViewAtIndex(currentIndex, GridView.Contain);
                        forceActiveFocus();
                    }

                    width: columns * root.cellSize
                    height: Math.min(requiredHeight, maximumHeight)
                    cellWidth: root.cellSize
                    cellHeight: root.cellSize
                    clip: true
                    interactive: requiredHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: false
                    currentIndex: -1

                    ScrollBar.vertical: ScrollBar {
                        active: folderGrid.interactive
                        policy: folderGrid.interactive ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus) {
                            currentIndex = -1;
                            keyboardFocusVisible = false;
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                                || event.key === Qt.Key_Up || event.key === Qt.Key_Down
                                || event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space || event.key === Qt.Key_Menu) {
                            keyboardFocusVisible = true;
                        }
                        if (event.key === Qt.Key_Left) {
                            event.accepted = true;
                            if (currentIndex > 0 && currentIndex % columns !== 0) {
                                focusIndex(currentIndex - 1);
                            }
                        } else if (event.key === Qt.Key_Right) {
                            event.accepted = true;
                            if (currentIndex >= 0 && currentIndex < count - 1
                                    && currentIndex % columns !== columns - 1) {
                                focusIndex(currentIndex + 1);
                            }
                        } else if (event.key === Qt.Key_Up) {
                            event.accepted = true;
                            if (currentIndex >= columns) {
                                focusIndex(currentIndex - columns);
                            }
                        } else if (event.key === Qt.Key_Down) {
                            event.accepted = true;
                            if (currentIndex >= 0 && currentIndex + columns < count) {
                                focusIndex(currentIndex + columns);
                            }
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                   || event.key === Qt.Key_Space) {
                            event.accepted = true;
                            if (currentItem && currentItem.activate) {
                                currentItem.activate();
                            }
                        } else if (event.key === Qt.Key_Menu) {
                            event.accepted = true;
                            if (currentItem && currentItem.openContextMenu) {
                                currentItem.openContextMenu();
                            }
                        } else if (event.key === Qt.Key_Escape) {
                            event.accepted = true;
                            var folderIndex = folderPopup.displayedFolderIndex;
                            rootItem.openFolderIndex = -1;
                            dashboardGrid.focusIndex(folderIndex);
                        }
                    }

                    // The contents fade in as one block, not item by item. A
                    // per-icon stagger belongs to lists that are being read
                    // through; a folder's icons are part of the thing that just
                    // expanded, so anything that presents them in sequence
                    // fights the morph the card is already performing.
                    opacity: folderPopup.contentProgress

                    // Deliberately NOT animated, unlike the card around it. A
                    // GridView derives its column count and its viewport from
                    // its own width and height, so easing them re-flows the
                    // layout every frame — and an OutBack undershoot briefly
                    // narrows it to a single column. Items that land outside the
                    // viewport mid-animation are never instantiated, which shows
                    // up as apps simply missing from the folder. The grid stays
                    // snapped to exact cell multiples; the card does the moving.

                    moveDisplaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: root.dragMoveDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.3
                        }
                    }

                    model: {
                        var idx = folderPopup.displayedFolderIndex;
                        if (idx >= 0 && idx < dashboardModel.count) {
                            var item = dashboardModel.get(idx);
                            return item ? item.apps : null;
                        }
                        return null;
                    }

                    delegate: Item {
                        id: folderDelegate
                        width: root.cellSize
                        height: root.cellSize

                        property int itemIndex: index
                        Accessible.role: Accessible.Button
                        Accessible.name: model.name || ""
                        Accessible.onPressAction: activate()

                        function openContextMenu(x, y) {
                            dashContextMenu.isFolder = false;
                            dashContextMenu.isAutoItem = false;
                            dashContextMenu.isFolderItem = true;
                            dashContextMenu.folderIdx = rootItem.openFolderIndex;
                            dashContextMenu.appIndex = itemIndex;
                            dashContextMenu.desktopFile = model.desktopFile;
                            dashContextMenu.appName = model.name || "";
                            dashContextMenu.appIcon = model.icon || "";
                            dashPinMenuItem.isPinned = false;
                            dashPinMenuItem.taskManagerFound = false;
                            dashContextMenu.visualParent = folderDelegate;
                            menuOpenTimer.openMenu(dashContextMenu,
                                                   x === undefined ? width / 2 : x,
                                                   y === undefined ? height / 2 : y);
                        }

                        function activate() {
                            rootItem.openFolderIndex = -1;
                            launchAppFromItem(model.desktopFile, folderDelegate);
                        }

                        // Hide whichever delegate holds the dragged item (index-
                        // based, so live moves inside the folder stay correct); the
                        // emptied cell reads as the gap it will drop into.
                        opacity: (folderGrid.dragActive && folderGrid.dragFromIndex === folderDelegate.itemIndex) ? 0.0 : 1.0
                        Behavior on opacity { NumberAnimation { duration: root.hoverEffectDuration } }

                        Column {
                            id: folderItemContent
                            anchors.centerIn: parent
                            spacing: 2

                            // No per-icon entrance: the whole grid fades in
                            // together, driven by folderGrid.opacity. This also
                            // removes the old failure mode where a delegate that
                            // missed its trigger stayed at opacity 0 until
                            // plasmashell restarted — there is nothing left here
                            // that can leave an icon invisible.

                            Kirigami.Icon {
                                width: root.iconSize
                                height: root.iconSize
                                source: model.icon
                                anchors.horizontalCenter: parent.horizontalCenter
                                animated: false
                            }

                            PlasmaComponents.Label {
                                text: model.name
                                width: root.cellSize - 4
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 1, root.dashboardFontScale)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        scale: (folderItemMA.containsMouse
                                || (folderGrid.activeFocus
                                    && folderGrid.keyboardFocusVisible
                                    && folderGrid.currentIndex === folderDelegate.itemIndex))
                               && !folderItemMA.dragging ? 1.06 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.iconSize + Kirigami.Units.largeSpacing * 2
                            height: width
                            radius: width / 4
                            color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.22)
                            border.width: 2
                            border.color: Kirigami.Theme.focusColor
                            opacity: folderGrid.activeFocus
                                     && folderGrid.keyboardFocusVisible
                                     && folderGrid.currentIndex === folderDelegate.itemIndex ? 1 : 0
                            z: -1
                        }

                        MouseArea {
                            id: folderItemMA
                            anchors.fill: parent
                            hoverEnabled: true
                            // A mouse drag reorders immediately, but a touch
                            // swipe must remain available to the surrounding
                            // GridView. Touch takes ownership only after a
                            // deliberate press-and-hold starts reordering.
                            preventStealing: mouseDragArmed || dragging
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property int pressX: -1
                            property int pressY: -1
                            property bool dragging: false
                            property bool mouseDragArmed: false

                            function beginDrag(x, y) {
                                if (dragging || pressX === -1) {
                                    return;
                                }
                                dragging = true;
                                folderGrid.dragFromIndex = folderDelegate.itemIndex;
                                folderGrid.dragStartIndex = folderDelegate.itemIndex;
                                folderGrid.dragActive = true;
                                dragGhost.iconSource = model.icon;
                                dragGhost.labelText = model.name;
                                var globalPos = mapToItem(rootItem, x, y);
                                dragGhost.x = globalPos.x - dragGhost.width / 2;
                                dragGhost.y = globalPos.y - dragGhost.height / 2;
                                dragGhost.visible = true;
                            }

                            function cancelPress() {
                                var persistReorder = dragging
                                    && folderGrid.dragFromIndex !== folderGrid.dragStartIndex;
                                pressX = -1;
                                pressY = -1;
                                mouseDragArmed = false;
                                if (dragging) {
                                    dragging = false;
                                    dragGhost.visible = false;
                                    folderGrid.endDrag();
                                    // A cancellation after a live move should not
                                    // leave the displayed order disagreeing with
                                    // the persisted one.
                                    if (persistReorder) {
                                        rootItem.syncModelToConfig();
                                    }
                                }
                            }

                            onPressed: mouse => {
                                folderGrid.keyboardFocusVisible = false;
                                mouseDragArmed = mouse.source === Qt.MouseEventNotSynthesized;
                                if (mouse.button === Qt.RightButton) {
                                    pressX = -1;
                                    pressY = -1;
                                    folderDelegate.openContextMenu(mouse.x, mouse.y);
                                } else {
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                }
                            }

                            onPressAndHold: mouse => {
                                if (mouse.button === Qt.LeftButton && !mouseDragArmed) {
                                    beginDrag(mouse.x, mouse.y);
                                }
                            }

                            onCanceled: cancelPress()

                            onReleased: mouse => {
                                // Everything this handler needs is read and reset up
                                // front. The write below rebuilds the folder's model,
                                // which destroys this delegate and the MouseArea running
                                // this very handler — statements after that point are not
                                // guaranteed to execute.
                                var wasDragging = dragging;
                                pressX = -1;
                                pressY = -1;
                                mouseDragArmed = false;
                                if (!wasDragging) {
                                    if (mouse.button === Qt.LeftButton) {
                                        folderDelegate.activate();
                                    }
                                    return;
                                }

                                dragging = false;
                                dragGhost.visible = false;

                                var fromIdx = folderGrid.dragFromIndex;
                                var reordered = folderGrid.dragFromIndex !== folderGrid.dragStartIndex;
                                var ghostIcon = dragGhost.iconSource;
                                var ghostX = dragGhost.x + dragGhost.width / 2;
                                var ghostY = dragGhost.y + dragGhost.height / 2;
                                // Released outside the folder card means move out
                                var posInCard = mapToItem(folderCard, mouse.x, mouse.y);
                                var droppedOut = posInCard.x < 0 || posInCard.x > folderCard.width
                                                 || posInCard.y < 0 || posInCard.y > folderCard.height;

                                folderGrid.endDrag();

                                if (droppedOut) {
                                    // Carries on from where the ghost was let go, so
                                    // the throw and the flight read as one gesture
                                    rootItem.ejectToDashboard(rootItem.openFolderIndex, fromIdx,
                                                              ghostIcon, ghostX, ghostY);
                                } else if (reordered) {
                                    // Reordered live inside the folder — persist the order
                                    rootItem.syncModelToConfig();
                                }
                            }

                            onPositionChanged: mouse => {
                                if (pressX !== -1 && !dragging) {
                                    var dx = mouse.x - pressX;
                                    var dy = mouse.y - pressY;
                                    if (mouseDragArmed && dx*dx + dy*dy > 400) {
                                        beginDrag(mouse.x, mouse.y);
                                    }
                                }
                                if (dragging) {
                                    var globalPos = mapToItem(rootItem, mouse.x, mouse.y);
                                    dragGhost.x = globalPos.x - dragGhost.width / 2;
                                    dragGhost.y = globalPos.y - dragGhost.height / 2;

                                    // Live reorder: once the cursor passes another
                                    // icon's centre, slide it aside and move the gap
                                    // there so the folder previews the drop result.
                                    var mapped = mapToItem(folderGrid.contentItem, mouse.x, mouse.y);
                                    var overIdx = folderGrid.indexAt(mapped.x, mapped.y);
                                    var fromIdx = folderGrid.dragFromIndex;
                                    if (overIdx !== -1 && overIdx !== fromIdx) {
                                        var overItem = folderGrid.itemAtIndex(overIdx);
                                        if (overItem) {
                                            var overCx = overItem.x + folderGrid.cellWidth / 2;
                                            var overCy = overItem.y + folderGrid.cellHeight / 2;
                                            var crossed = true;
                                            var fromItem = folderGrid.itemAtIndex(fromIdx);
                                            if (fromItem) {
                                                var fromCx = fromItem.x + folderGrid.cellWidth / 2;
                                                var fromCy = fromItem.y + folderGrid.cellHeight / 2;
                                                var dot = (mapped.x - overCx) * (overCx - fromCx)
                                                        + (mapped.y - overCy) * (overCy - fromCy);
                                                crossed = dot > 0;
                                            }
                                            if (crossed && folderGrid.model && "move" in folderGrid.model) {
                                                folderGrid.model.move(fromIdx, overIdx, 1);
                                                folderGrid.dragFromIndex = overIdx;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =============================================
        //           RUNNER (SEARCH RESULTS)
        // =============================================

        Component {
            id: runnerComponent

            ItemGridView {
                id: runnerGrid
                anchors.horizontalCenter: mainView.horizontalCenter
                width: mainView.width / 2
                clip: true
                height: mainView.height
                grabFocus: true
                cellWidth: root.cellSize
                cellHeight: root.cellSize
                iconSize: root.iconSize
                dragEnabled: false
                animatedEntrance: true
                model: runnerModel.count > 0 ? runnerModel.modelForRow(0) : undefined

                // Stagger the icons in only when the first results land; later
                // keystrokes swap the model silently so refinement doesn't
                // re-trigger the choreography on every character.
                property bool entrancePlayed: false
                onCountChanged: {
                    if (count > 0 && !entrancePlayed) {
                        entrancePlayed = true;
                        animateEntrance();
                    }
                }

                onKeyNavDown: {
                    runnerGrid.focus = false;
                    root.focusSystemActionsOrFallback();
                }
                onKeyNavUp: {
                    runnerGrid.focus = false;
                    searchField.focus = true;
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        runnerGrid.focus = false;
                        root.focusSystemActionsOrFallback();
                    }
                }
            }
        }

        // =============================================
        //       DOCK (Bottom): Running Apps
        // =============================================

        // Running apps only (no launchers)
        TaskManager.TasksModel {
            id: runningTasksModel
            sortMode: TaskManager.TasksModel.SortManual
            groupMode: TaskManager.TasksModel.GroupApplications
            groupInline: false
            filterByVirtualDesktop: false
            filterByScreen: false
            filterByActivity: false
        }

        property int dockIconSize: root.favsIconSize
        property int dockCellSize: dockIconSize + Kirigami.Units.largeSpacing

        // ---- Running Apps Dock ----
        Item {
            id: runningDockContainer
            visible: runningTasksModel.count > 0 && Plasmoid.configuration.showActiveApps
            width: runningDockBg.width
            height: runningDockBg.height
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.largeSpacing * 2
            anchors.horizontalCenter: parent.horizontalCenter
            z: 2

                Rectangle {
                    id: runningDockBg
                    width: runningAppsRow.width + Kirigami.Units.largeSpacing * 2
                    height: runningAppsRow.height + Kirigami.Units.largeSpacing * 2
                    color: Kirigami.Theme.backgroundColor
                    radius: 16
                    opacity: 0.55

                    Behavior on width {
                        NumberAnimation {
                            duration: root.animDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                }

                Row {
                    id: runningAppsRow
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        id: runningRepeater
                        model: runningTasksModel

                        delegate: Item {
                            width: rootItem.dockCellSize
                            height: rootItem.dockCellSize
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: model.AppName || model.display || ""

                            function openContextMenu(x, y) {
                                rootItem.openDockContextMenu(runningTasksModel, index, runningTaskDelegate,
                                                            x === undefined ? width / 2 : x,
                                                            y === undefined ? height / 2 : y, {
                                    isWindow: model.IsWindow === true,
                                    isLauncher: model.IsLauncher === true,
                                    isMinimized: model.IsMinimized === true,
                                    isMaximized: model.IsMaximized === true,
                                    isKeepAbove: model.IsKeepAbove === true,
                                    isKeepBelow: model.IsKeepBelow === true,
                                    isFullScreen: model.IsFullScreen === true
                                });
                            }

                            function activate() {
                                var taskIndex = runningTasksModel.index(index, 0);
                                runningTasksModel.requestActivate(taskIndex);
                                closeWithAnimation();
                            }

                            id: runningTaskDelegate

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: rootItem.dockIconSize
                                height: rootItem.dockIconSize
                                source: model.decoration
                                animated: false

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 2
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: Kirigami.Theme.highlightColor
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: rootItem.dockIconSize + Kirigami.Units.smallSpacing * 2
                                height: width
                                radius: width / 4
                                color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.22)
                                border.width: 2
                                border.color: Kirigami.Theme.focusColor
                                visible: runningTaskDelegate.activeFocus
                                z: -1
                            }

                            scale: runMA.pressed ? 0.88
                                   : (runMA.containsMouse || activeFocus) ? 1.08 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                            }

                            PlasmaComponents.ToolTip.text: model.AppName || model.display || ""
                            PlasmaComponents.ToolTip.visible: runMA.containsMouse
                            PlasmaComponents.ToolTip.delay: 500

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                        || event.key === Qt.Key_Space) {
                                    event.accepted = true;
                                    activate();
                                } else if (event.key === Qt.Key_Menu) {
                                    event.accepted = true;
                                    openContextMenu();
                                } else if (event.key === Qt.Key_Left && index > 0) {
                                    event.accepted = true;
                                    var previous = runningRepeater.itemAt(index - 1);
                                    if (previous) previous.forceActiveFocus();
                                } else if (event.key === Qt.Key_Right
                                           && index + 1 < runningRepeater.count) {
                                    event.accepted = true;
                                    var next = runningRepeater.itemAt(index + 1);
                                    if (next) next.forceActiveFocus();
                                } else if (event.key === Qt.Key_Up) {
                                    event.accepted = true;
                                    searchField.forceActiveFocus();
                                } else if (event.key === Qt.Key_Tab) {
                                    event.accepted = true;
                                    searchField.forceActiveFocus();
                                }
                            }

                            MouseArea {
                                id: runMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        runningTaskDelegate.openContextMenu(mouse.x, mouse.y);
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        var idx = runningTasksModel.index(index, 0);
                                        runningTasksModel.requestNewInstance(idx);
                                    } else {
                                        runningTaskDelegate.activate();
                                    }
                                }
                            }
                        }
                    }
                }
            }

        // =============================================
        //       SYSTEM ACTIONS (Top-Right)
        // =============================================

        ItemGridView {
            id: systemFavoritesGrid
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            clip: true
            width: cellWidth
            height: systemFavoritesGrid.model ? systemFavoritesGrid.model.count * cellHeight : 0
            cellWidth: iconSize + Kirigami.Units.largeSpacing * 2
            cellHeight: cellWidth
            iconSize: root.systemIconSize
            z: 5
            showLabels: false
            model: systemFavorites
            dragEnabled: false
            dropEnabled: false

            onKeyNavUp: {
                focus = false;
                root.focusVisibleContent();
            }
            onKeyNavDown: {
                focus = false;
                if (runningDockContainer.visible && runningRepeater.count > 0) {
                    var firstTask = runningRepeater.itemAt(0);
                    if (firstTask) firstTask.forceActiveFocus();
                } else {
                    searchField.forceActiveFocus();
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    systemFavoritesGrid.focus = false;
                    if (runningDockContainer.visible && runningRepeater.count > 0) {
                        var firstTask = runningRepeater.itemAt(0);
                        if (firstTask) firstTask.forceActiveFocus();
                    } else {
                        searchField.forceActiveFocus();
                    }
                }
            }
        }

        // =============================================
        //           KEY HANDLING
        // =============================================

        Keys.onPressed: event => {
            // Always accept key events to prevent the Dialog from closing
            // on unhandled keys (standard Plasma behavior).
            event.accepted = true;

            // Don't steal keys while renaming a folder
            if (folderNameEdit.activeFocus) {
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (root.searching) {
                    reset();
                } else {
                    closeWithAnimation();
                }
                return;
            }
            // If searchField already has active focus, let it handle the event directly
            if (searchField.activeFocus) {
                return;
            }
            // Forward typing to the search field
            if (event.key === Qt.Key_Backspace) {
                searchField.forceActiveFocus();
                searchField.backspace();
            } else if (event.text !== "" && !(event.modifiers & Qt.ControlModifier)) {
                searchField.forceActiveFocus();
                searchField.appendText(event.text);
            }
        }
    }

    Component.onCompleted: {
        // OR'd in rather than assigned: DashboardWindow sets
        // Qt.FramelessWindowHint in its constructor and we must not drop it.
        // Safe to do here — the window is built up front but not shown until
        // the first toggle(), so no platform surface gets recreated.
        root.flags = root.flags | Qt.WindowStaysOnTopHint;

        rootModel.refresh();
        flatAllAppsRootModel.refresh();
        searchField.forceActiveFocus();
    }
}
