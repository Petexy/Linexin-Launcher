/*
    SPDX-FileCopyrightText: 2025 Petexy
    SPDX-License-Identifier: GPL-2.0-or-later

    Linexin Launcher — Full-screen dashboard with macOS Launchpad-style animations
*/

import QtQuick 2.15
import QtQml 2.15

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

    property int cellSize: iconSize + (2 * Kirigami.Units.iconSizes.sizeForLabels)
                           + (2 * Kirigami.Units.largeSpacing)
                           + (2 * Math.max(highlightItemSvg.margins.top + highlightItemSvg.margins.bottom,
                                           highlightItemSvg.margins.left + highlightItemSvg.margins.right))

    property int columns: Math.floor(((smallScreen ? 85 : 80) / 100) * Math.ceil(width / cellSize))
    property bool searching: searchField.text !== ""

    // -- Animation properties --
    property int animDuration: Plasmoid.configuration.animationDuration
    property int iconEntranceDuration: Plasmoid.configuration.iconEntranceDuration
    property int hoverEffectDuration: Plasmoid.configuration.hoverEffectDuration
    property int folderPopupDuration: Plasmoid.configuration.folderPopupDuration
    property real bgOpacity: Plasmoid.configuration.backgroundOpacity / 100.0

    // State tracking for open/close animation
    property bool isOpening: false
    property bool isClosing: false

    backgroundColor: "transparent"

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
            // Reset grid items to hidden before opening so they animate in fresh
            allAppsGrid.resetEntrance();
            openAnimation.start();
        } else {
            rootItem.opacity = 0;
        }
        reset();
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

    function closeWithAnimation() {
        isClosing = true;
        closeAnimation.start();
    }

    function reset() {
        rootItem.showingDashboard = false;
        rootItem.showingAllApps = false;
        rootItem.openFolderIndex = -1;
        allAppsGrid.parentModel = null;

        var defCat = Plasmoid.configuration.defaultCategory;
        if (defCat === -2) {
            rootItem.showingDashboard = true;
            categoryRow.currentCategory = -1;
        } else if (defCat === -1) {
            rootItem.showingAllApps = true;
            categoryRow.currentCategory = -1;
            allAppsView.populate();
        } else {
            var row = Math.min(defCat, rootModel.count - 1);
            categoryRow.currentCategory = row;
            allAppsGrid.model = rootModel.modelForRow(row);
        }

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

            // Background fades in
            NumberAnimation {
                target: bgRect
                property: "opacity"
                from: 0
                to: root.bgOpacity
                duration: root.animDuration * 0.6
                easing.type: Easing.OutCubic
            }
            // Content fades in
            NumberAnimation {
                target: rootItem
                property: "opacity"
                from: 0
                to: 1
                duration: root.animDuration * 0.8
                easing.type: Easing.OutCubic
            }
            // Content slides up from below
            NumberAnimation {
                target: contentArea
                property: "anchors.verticalCenterOffset"
                from: Kirigami.Units.gridUnit * 4
                to: Kirigami.Units.gridUnit * 2
                duration: root.animDuration
                easing.type: Easing.OutCubic
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

        SequentialAnimation {
            id: gridEntranceAnimation

            PauseAnimation { duration: Math.round(root.animDuration * 0.15) }

            ScriptAction {
                script: {
                    allAppsGrid.animateEntrance();
                }
            }
        }

        // Background with blur-like tinted overlay
        Rectangle {
            id: bgRect
            anchors.fill: parent
            color: Kirigami.Theme.backgroundColor
            opacity: root.bgOpacity
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
            property string appFavoriteId: ""
            property string appName: ""
            property string appIcon: ""
            property var appModel: null
            property int appIndex: -1

            PlasmaExtras.MenuItem {
                id: dashboardMenuItem
                text: rootItem.isDashboardApp(appContextMenu.appUrl) ? i18n("Remove from Dashboard") : i18n("Add to Dashboard")
                icon: rootItem.isDashboardApp(appContextMenu.appUrl) ? "edit-delete-remove" : "list-add"
                visible: appContextMenu.appUrl !== ""
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

            PlasmaExtras.MenuItem { separator: true; visible: appContextMenu.appFavoriteId !== "" }

            PlasmaExtras.MenuItem {
                id: favMenuItem
                text: {
                    if (appContextMenu.appFavoriteId && globalFavorites && globalFavorites.isFavorite(appContextMenu.appFavoriteId)) {
                        return i18n("Remove from Favorites");
                    }
                    return i18n("Add to Favorites");
                }
                icon: {
                    if (appContextMenu.appFavoriteId && globalFavorites && globalFavorites.isFavorite(appContextMenu.appFavoriteId)) {
                        return "bookmark-remove";
                    }
                    return "bookmark-new";
                }
                visible: appContextMenu.appFavoriteId !== ""
                onClicked: {
                    var favId = appContextMenu.appFavoriteId;
                    appContextMenu.close();
                    if (globalFavorites.isFavorite(favId)) {
                        globalFavorites.removeFavorite(favId);
                    } else {
                        globalFavorites.addFavorite(favId);
                    }
                }
            }

            PlasmaExtras.MenuItem { separator: true; visible: appContextMenu.appUrl !== "" }

            PlasmaExtras.MenuItem {
                id: pinMenuItem
                property bool isPinned: false
                text: isPinned ? i18n("Unpin from Task Manager") : i18n("Pin to Task Manager")
                icon: isPinned ? "window-unpin" : "window-pin"
                visible: appContextMenu.appUrl !== ""
                onClicked: {
                    // Read current launchers, toggle this app, write back — all via evaluateScript
                    var url = appContextMenu.appUrl;
                    var cmd = "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \""
                        + "var ps=panels();"
                        + "for(var i=0;i<ps.length;i++){"
                        + "var ws=ps[i].widgets();"
                        + "for(var j=0;j<ws.length;j++){"
                        + "if(ws[j].type==='org.kde.plasma.icontasks'){"
                        + "ws[j].currentConfigGroup=['General'];"
                        + "var cur=ws[j].readConfig('launchers').split(',');"
                        + "var idx=cur.indexOf('" + url + "');"
                        + "if(idx!==-1){cur.splice(idx,1);}else{cur.push('" + url + "');}"
                        + "ws[j].writeConfig('launchers',cur);"
                        + "}}}"
                        + "\"";
                    pinHelper.connectSource(cmd);
                }
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
                var launchers = stdout.length > 0 ? stdout.split(",") : [];
                pinMenuItem.isPinned = launchers.indexOf(appContextMenu.appUrl) !== -1;
                disconnectSource(source);
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
                if (menu && !dragHelper.dragging) menu.open(mx, my);
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
                folderItemContextMenu.close();
            }
        }

        function openAppContextMenu(delegateItem, model, mx, my) {
            var url = model.url ? model.url.toString() : "";
            // Normalize URL to applications:filename.desktop format
            var appUrl = "";
            if (url !== "") {
                var desktopFile = url.replace(/^.*\//, "");  // get filename
                if (desktopFile.endsWith(".desktop")) {
                    appUrl = "applications:" + desktopFile;
                } else {
                    appUrl = url;
                }
            }
            appContextMenu.appUrl = appUrl;
            appContextMenu.appFavoriteId = model.favoriteId || "";
            appContextMenu.appName = model.display || "";
            appContextMenu.appIcon = model.decoration || "";
            appContextMenu.appModel = delegateItem.GridView ? delegateItem.GridView.view.model : null;
            appContextMenu.appIndex = model.index;
            appContextMenu.visualParent = delegateItem;
            // Check if this app is currently pinned in icontasks
            pinMenuItem.isPinned = false;
            if (appUrl !== "") {
                var script = "var ps=panels();for(var i=0;i<ps.length;i++){"
                    + "var ws=ps[i].widgets();"
                    + "for(var j=0;j<ws.length;j++){"
                    + "if(ws[j].type==='org.kde.plasma.icontasks'){"
                    + "ws[j].currentConfigGroup=['General'];"
                    + "print(ws[j].readConfig('launchers'));break;}}}";
                var cmd = "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \""
                    + script + "\" #" + Date.now();
                pinChecker.connectSource(cmd);
            }
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

        property var dashboardApps: {
            try { return JSON.parse(Plasmoid.configuration.dashboardApps || "[]"); }
            catch(e) { return []; }
        }

        function saveDashboard() {
            Plasmoid.configuration.dashboardApps = JSON.stringify(rootItem.dashboardApps);
        }

        function addToDashboard(desktopFile, name, icon) {
            // Check top-level and inside folders
            for (var i = 0; i < dashboardApps.length; i++) {
                var item = dashboardApps[i];
                if (item.desktopFile === desktopFile) return;
                if (item.type === "folder" && item.apps) {
                    for (var j = 0; j < item.apps.length; j++) {
                        if (item.apps[j].desktopFile === desktopFile) return;
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
            var apps = dashboardApps.filter(function(a) { return a.desktopFile !== desktopFile; });
            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
        }

        function removeFromFolder(folderIndex, appDesktopFile) {
            var apps = dashboardApps.slice();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return;

            folder.apps = folder.apps.filter(function(a) { return a.desktopFile !== appDesktopFile; });

            // If folder has 1 or 0 apps left, dissolve it
            if (folder.apps.length === 1) {
                apps[folderIndex] = folder.apps[0];
            } else if (folder.apps.length === 0) {
                apps.splice(folderIndex, 1);
            } else {
                apps[folderIndex] = folder;
            }

            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
            if (openFolderIndex === folderIndex) {
                // If folder dissolved, close popup
                if (!dashboardApps[folderIndex] || dashboardApps[folderIndex].type !== "folder") {
                    openFolderIndex = -1;
                }
            }
        }

        function reorderInFolder(folderIndex, fromIdx, toIdx) {
            var apps = dashboardApps.slice();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return;
            var arr = folder.apps.slice();
            var item = arr.splice(fromIdx, 1)[0];
            arr.splice(toIdx, 0, item);
            folder.apps = arr;
            apps[folderIndex] = folder;
            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
        }

        function moveAppOutOfFolder(folderIndex, appIndex) {
            var apps = dashboardApps.slice();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return;
            var arr = folder.apps.slice();
            var item = arr.splice(appIndex, 1)[0];

            // Update folder
            if (arr.length === 1) {
                apps[folderIndex] = arr[0]; // dissolve
            } else if (arr.length === 0) {
                apps.splice(folderIndex, 1);
            } else {
                folder.apps = arr;
                apps[folderIndex] = folder;
            }

            // Add the removed app after the folder position
            var insertIdx = Math.min(folderIndex + 1, apps.length);
            apps.splice(insertIdx, 0, item);

            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
            // Close if folder dissolved
            if (!dashboardApps[folderIndex] || dashboardApps[folderIndex].type !== "folder") {
                openFolderIndex = -1;
            }
        }

        function removeFolder(folderIndex) {
            var apps = dashboardApps.slice();
            var folder = apps[folderIndex];
            if (!folder || folder.type !== "folder") return;
            // Move all apps inside folder to top-level at that position
            var folderApps = folder.apps || [];
            apps.splice(folderIndex, 1);
            for (var i = 0; i < folderApps.length; i++) {
                apps.splice(folderIndex + i, 0, folderApps[i]);
            }
            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
            openFolderIndex = -1;
        }

        function createFolder(indexA, indexB) {
            // Merge two dashboard items into a folder
            var apps = dashboardApps.slice();
            var itemA = apps[indexA];
            var itemB = apps[indexB];
            if (!itemA || !itemB) return;

            var folderApps = [];
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
            }
            // If B is already a folder, add A into it
            else if (itemB.type === "folder") {
                folderApps = (itemB.apps || []).slice();
                folderApps.unshift({desktopFile: itemA.desktopFile, name: itemA.name, icon: itemA.icon});
                apps[indexB] = {type: "folder", name: itemB.name, apps: folderApps};
                apps.splice(indexA, 1);
            }
            // Both are regular apps — create new folder
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
                var minIdx = Math.min(indexA, indexB);
                var maxIdx = Math.max(indexA, indexB);
                apps[indexB] = folder;
                apps.splice(indexA, 1);
            }

            dashboardApps = apps;
            saveDashboard();
            dashboardModel.reload();
        }

        function renameFolder(folderIndex, newName) {
            var apps = dashboardApps.slice();
            if (apps[folderIndex] && apps[folderIndex].type === "folder") {
                apps[folderIndex].name = newName;
                dashboardApps = apps;
                saveDashboard();
                dashboardModel.reload();
            }
        }

        function isDashboardApp(desktopFile) {
            for (var i = 0; i < dashboardApps.length; i++) {
                var item = dashboardApps[i];
                if (item.desktopFile === desktopFile) return true;
                if (item.type === "folder" && item.apps) {
                    for (var j = 0; j < item.apps.length; j++) {
                        if (item.apps[j].desktopFile === desktopFile) return true;
                    }
                }
            }
            return false;
        }

        // Serialize dashboardModel back to the apps array (handles folders)
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
                    apps.push({desktopFile: item.desktopFile, name: item.name, icon: item.icon});
                }
            }
            rootItem.dashboardApps = apps;
            rootItem.saveDashboard();
        }

        ListModel {
            id: dashboardModel

            function reload() {
                clear();
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
                            get(count - 1).apps.append(folderApps[j]);
                        }
                    } else {
                        append({type: "app", desktopFile: item.desktopFile,
                                name: item.name, icon: item.icon, apps: []});
                    }
                }
            }

            Component.onCompleted: reload()
        }

        P5Support.DataSource {
            id: dashLauncher
            engine: "executable"
            onNewData: function(source, data) { disconnectSource(source); }
        }

        PlasmaExtras.Menu {
            id: dashContextMenu
            property string desktopFile: ""
            property bool isFolder: false
            property int folderIdx: -1

            PlasmaExtras.MenuItem {
                text: i18n("Remove from Dashboard")
                icon: "edit-delete-remove"
                visible: !dashContextMenu.isFolder
                onClicked: {
                    var df = dashContextMenu.desktopFile;
                    dashContextMenu.close();
                    rootItem.removeFromDashboard(df);
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
                    rootItem.openFolderIndex = idx;
                    folderPopup.startRename();
                }
            }
        }

        // Drag ghost — semi-transparent icon that follows cursor during Dashboard drag
        Item {
            id: dragGhost
            visible: false
            width: root.cellSize
            height: root.cellSize
            z: 9999

            property string iconSource: ""
            property string labelText: ""

            Kirigami.Icon {
                width: root.iconSize
                height: root.iconSize
                source: dragGhost.iconSource
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Kirigami.Units.smallSpacing
                animated: false
            }

            PlasmaComponents.Label {
                text: dragGhost.labelText
                width: parent.width - 4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Kirigami.Units.smallSpacing
            }

            opacity: 0.7
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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: categoryRow.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing * 2

            width: Kirigami.Units.gridUnit * 16
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            leftPadding: Kirigami.Units.largeSpacing * 2
            rightPadding: Kirigami.Units.largeSpacing * 2

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

            // Search icon
            Kirigami.Icon {
                source: "search"
                width: Kirigami.Units.iconSizes.small
                height: width
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.5
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
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    if (root.searching) {
                        mainView.currentItem.tryActivate(0, 0);
                        mainView.currentItem.forceActiveFocus();
                    } else {
                        allAppsGrid.tryActivate(0, 0);
                        allAppsGrid.forceActiveFocus();
                    }
                }
            }
        }

        // =============================================
        //            CATEGORY FILTER ROW
        // =============================================

        Row {
            id: categoryRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: contentArea.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing * 2
            spacing: Kirigami.Units.smallSpacing
            visible: !root.searching

            property int currentCategory: -1

            // Dashboard category button
            Rectangle {
                id: dashboardCatBtn
                width: dashCatLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                height: dashCatLabel.implicitHeight + Kirigami.Units.largeSpacing
                radius: height / 2

                color: rootItem.showingDashboard
                    ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.85)
                    : dashCatMouse.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.25)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                Behavior on color {
                    ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                scale: dashCatMouse.pressed ? 0.93 : 1.0

                PlasmaComponents.Label {
                    id: dashCatLabel
                    anchors.centerIn: parent
                    text: i18n("Dashboard")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
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
                        if (rootItem.showingDashboard) {
                            rootItem.showingDashboard = false;
                            categoryRow.currentCategory = 0;
                            allAppsGrid.model = rootModel.modelForRow(0);
                            allAppsGrid.currentIndex = -1;
                            allAppsGrid.animateEntrance();
                        } else {
                            rootItem.showingDashboard = true;
                            rootItem.showingAllApps = false;
                            categoryRow.currentCategory = -1;
                        }
                    }
                }
            }

            // All Apps category button (sectioned A-Z list)
            Rectangle {
                id: allAppsCatBtn
                width: allAppsCatLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                height: allAppsCatLabel.implicitHeight + Kirigami.Units.largeSpacing
                radius: height / 2

                color: rootItem.showingAllApps
                    ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.85)
                    : allAppsCatMouse.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.25)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                Behavior on color {
                    ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                scale: allAppsCatMouse.pressed ? 0.93 : 1.0

                PlasmaComponents.Label {
                    id: allAppsCatLabel
                    anchors.centerIn: parent
                    text: i18n("All Apps")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
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
                        if (rootItem.showingAllApps) {
                            rootItem.showingAllApps = false;
                            categoryRow.currentCategory = 0;
                            allAppsGrid.model = rootModel.modelForRow(0);
                            allAppsGrid.currentIndex = -1;
                            allAppsGrid.animateEntrance();
                        } else {
                            rootItem.showingDashboard = false;
                            rootItem.showingAllApps = true;
                            categoryRow.currentCategory = -1;
                            allAppsView.populate();
                        }
                    }
                }
            }

            Repeater {
                id: categoryRepeater
                model: rootModel

                delegate: Rectangle {
                    width: catLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                    height: catLabel.implicitHeight + Kirigami.Units.largeSpacing
                    radius: height / 2

                    color: categoryRow.currentCategory === index
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.85)
                        : catMouse.containsMouse
                            ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.25)
                            : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                    Behavior on color {
                        ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                    }

                    scale: catMouse.pressed ? 0.93 : 1.0

                    PlasmaComponents.Label {
                        id: catLabel
                        anchors.centerIn: parent
                        text: model.display === "All Applications" ? i18n("Alphabetically") : model.display
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
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
                            rootItem.showingDashboard = false;
                            rootItem.showingAllApps = false;
                            if (categoryRow.currentCategory === index) {
                                categoryRow.currentCategory = 0;
                                allAppsGrid.model = rootModel.modelForRow(0);
                            } else {
                                categoryRow.currentCategory = index;
                                allAppsGrid.model = rootModel.modelForRow(index);
                            }
                            allAppsGrid.currentIndex = -1;
                            allAppsGrid.animateEntrance();
                        }
                    }
                }
            }
        }

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

        StackView {
            id: mainView
            visible: !rootItem.showingDashboard && !rootItem.showingAllApps || root.searching
            anchors.fill: parent

            initialItem: Column {
                id: allAppsColumn
                clip: true
                spacing: Kirigami.Units.largeSpacing * 2

                // Back button for letter sub-model navigation
                Rectangle {
                    id: backButton
                    visible: allAppsGrid.parentModel !== null && !root.searching
                    width: backLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                    height: visible ? backLabel.implicitHeight + Kirigami.Units.largeSpacing : 0
                    radius: height / 2
                    color: backMouse.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.3)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                    Behavior on color {
                        ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                    }

                    scale: backMouse.pressed ? 0.93 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
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
                            text: i18n("All Letters")
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                            color: Kirigami.Theme.textColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            allAppsGrid.model = allAppsGrid.parentModel;
                            allAppsGrid.parentModel = null;
                            allAppsGrid.currentIndex = -1;
                            allAppsGrid.animateEntrance();
                        }
                    }
                }

                ItemGridView {
                    id: allAppsGrid
                    width: parent.width
                    height: Math.ceil(root.height * 0.6 / cellHeight) * cellHeight
                        - (backButton.visible ? backButton.height + allAppsColumn.spacing : 0)
                    cellWidth: root.cellSize
                    cellHeight: root.cellSize
                    iconSize: root.iconSize
                    dragEnabled: false
                    dropEnabled: false
                    animatedEntrance: true

                    property var parentModel: null

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
                        systemFavoritesGrid.tryActivate(0, 0);
                        systemFavoritesGrid.forceActiveFocus();
                    }
                    onKeyNavUp: {
                        allAppsGrid.focus = false;
                        searchField.focus = true;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            allAppsGrid.focus = false;
                            systemFavoritesGrid.tryActivate(0, 0);
                            systemFavoritesGrid.forceActiveFocus();
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

            // Smooth transitions between pages
            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0; to: 1
                        duration: root.animDuration * 0.6
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "y"
                        from: 20; to: 0
                        duration: root.animDuration * 0.6
                        easing.type: Easing.OutCubic
                    }
                }
            }
            pushExit: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 1; to: 0
                        duration: root.animDuration * 0.4
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "y"
                        from: 0; to: -20
                        duration: root.animDuration * 0.4
                        easing.type: Easing.InCubic
                    }
                }
            }
            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0; to: 1
                        duration: root.animDuration * 0.6
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "y"
                        from: -20; to: 0
                        duration: root.animDuration * 0.6
                        easing.type: Easing.OutCubic
                    }
                }
            }
            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 1; to: 0
                        duration: root.animDuration * 0.4
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "y"
                        from: 0; to: 20
                        duration: root.animDuration * 0.4
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
            visible: rootItem.showingAllApps && !root.searching
            anchors.fill: parent

            property var alphaModel: null

            function populate() {
                // Find "All Applications" index in rootModel
                var idx = -1;
                for (var i = 0; i < rootModel.count; i++) {
                    if (rootModel.labelForRow(i) === "All Applications") {
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
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 4
                                    font.weight: Font.Bold
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.7
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
                                width: parent.width
                                // Calculate height based on number of rows needed
                                height: Math.ceil(modelData.model.count / Math.floor(width / root.cellSize)) * root.cellSize
                                cellWidth: root.cellSize
                                cellHeight: root.cellSize
                                iconSize: root.iconSize
                                model: modelData.model
                                dragEnabled: false
                                dropEnabled: false
                                animatedEntrance: false
                                verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff

                                onKeyNavDown: {
                                    // Move to next section or to system favorites
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
            visible: rootItem.showingDashboard && !root.searching
            anchors.fill: parent

            // Close launcher when clicking empty space in the dashboard.
            // Sits above the GridView so it intercepts events before Flickable
            // swallows them; passes through when a delegate is under the cursor.
            MouseArea {
                anchors.fill: parent
                z: 100
                acceptedButtons: Qt.LeftButton

                onPressed: mouse => {
                    var cPos = mapToItem(dashboardGrid.contentItem, mouse.x, mouse.y);
                    var idx = dashboardGrid.indexAt(cPos.x, cPos.y);
                    if (idx !== -1) {
                        mouse.accepted = false; // delegate will handle it
                    }
                }

                onReleased: {
                    closeWithAnimation();
                }
            }

            GridView {
                id: dashboardGrid
                anchors.fill: parent
                cellWidth: root.cellSize
                cellHeight: root.cellSize
                clip: true
                interactive: true

                property int dragFromIndex: -1
                property int dragToIndex: -1
                property int hoverTargetIndex: -1  // for folder merge highlight
                property bool readyToMerge: false   // armed after holding over target 600ms

                model: dashboardModel

                moveDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: dashDelegate
                    width: dashboardGrid.cellWidth
                    height: dashboardGrid.cellHeight

                    property int itemIndex: index
                    property bool isFolder: model.type === "folder"

                    // Hide the original when being dragged
                    opacity: (dashMA.dragging && dashboardGrid.dragFromIndex === index) ? 0.3 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }

                    // Highlight when another icon is held over this one (folder merge target)
                    Rectangle {
                        id: mergeHighlight
                        anchors.centerIn: parent
                        width: root.iconSize + Kirigami.Units.largeSpacing * 2
                        height: width
                        radius: width / 4
                        color: Kirigami.Theme.highlightColor
                        opacity: {
                            if (dashboardGrid.dragFromIndex === -1 || dashboardGrid.dragFromIndex === index) return 0;
                            if (dashboardGrid.hoverTargetIndex !== index) return 0;
                            return dashboardGrid.readyToMerge ? 0.55 : 0.2;
                        }
                        scale: dashboardGrid.readyToMerge && dashboardGrid.hoverTargetIndex === index ? 1.15 : 1.0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                    }

                    // === APP DELEGATE ===
                    Column {
                        id: appContent
                        visible: !dashDelegate.isFolder
                        anchors.centerIn: parent
                        spacing: 2

                        Kirigami.Icon {
                            width: root.iconSize
                            height: root.iconSize
                            source: model.icon || ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            animated: false
                        }

                        PlasmaComponents.Label {
                            text: model.name || ""
                            width: dashboardGrid.cellWidth - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // === FOLDER DELEGATE ===
                    Column {
                        id: folderContent
                        visible: dashDelegate.isFolder
                        anchors.centerIn: parent
                        spacing: 2

                        // Mini-grid preview (2x2 icons) — same outer size as app icon for alignment
                        Item {
                            width: root.iconSize
                            height: root.iconSize
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                width: root.iconSize * 0.85 + 8
                                height: root.iconSize * 0.85 + 8
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
                                        var apps = dashboardModel.get(index) ? dashboardModel.get(index).apps : null;
                                        return apps ? Math.min(apps.count, 4) : 0;
                                    }
                                    delegate: Kirigami.Icon {
                                        width: parent.miniSize
                                        height: parent.miniSize
                                        source: {
                                            var apps = dashboardModel.get(dashDelegate.itemIndex).apps;
                                            return apps.get(index).icon;
                                        }
                                        animated: false
                                    }
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            text: model.name || ""
                            width: dashboardGrid.cellWidth - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    scale: dashMA.containsMouse && !dashMA.dragging ? 1.06 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
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
                                if (dashDelegate.isFolder) {
                                    dashContextMenu.isFolder = true;
                                    dashContextMenu.folderIdx = index;
                                    dashContextMenu.desktopFile = "";
                                } else {
                                    dashContextMenu.isFolder = false;
                                    dashContextMenu.folderIdx = -1;
                                    dashContextMenu.desktopFile = model.desktopFile;
                                }
                                dashContextMenu.visualParent = dashDelegate;
                                menuOpenTimer.openMenu(dashContextMenu, mouse.x, mouse.y);
                            } else {
                                pressX = mouse.x;
                                pressY = mouse.y;
                            }
                        }

                        onReleased: mouse => {
                            folderMergeTimer.stop();
                            dashboardGrid.hoverTargetIndex = -1;

                            if (dragging) {
                                dragging = false;
                                dragGhost.visible = false;

                                if (dashboardGrid.dragFromIndex !== -1 && dashboardGrid.dragToIndex !== -1
                                    && dashboardGrid.dragFromIndex !== dashboardGrid.dragToIndex) {
                                    if (dashboardGrid.readyToMerge) {
                                        // Merge into folder — user held long enough and released
                                        rootItem.createFolder(dashboardGrid.dragFromIndex, dashboardGrid.dragToIndex);
                                    } else {
                                        // Just reorder — not held long enough for merge
                                        dashboardModel.move(dashboardGrid.dragFromIndex, dashboardGrid.dragToIndex, 1);
                                        rootItem.syncModelToConfig();
                                    }
                                }
                                dashboardGrid.readyToMerge = false;
                                dashboardGrid.dragFromIndex = -1;
                                dashboardGrid.dragToIndex = -1;
                            } else if (mouse.button === Qt.LeftButton) {
                                if (dashDelegate.isFolder) {
                                    rootItem.openFolderIndex = index;
                                } else {
                                    dashLauncher.connectSource("kioclient exec " + model.desktopFile + " #" + Date.now());
                                    closeWithAnimation();
                                }
                            }
                            pressX = -1;
                            pressY = -1;
                        }

                        onPositionChanged: mouse => {
                            if (pressX !== -1 && !dragging) {
                                var dx = mouse.x - pressX;
                                var dy = mouse.y - pressY;
                                if (dx*dx + dy*dy > 400) {
                                    dragging = true;
                                    dashboardGrid.dragFromIndex = index;
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
                                var targetIdx = dashboardGrid.indexAt(mapped.x, mapped.y);
                                if (targetIdx !== -1 && targetIdx !== dashboardGrid.dragFromIndex) {
                                    dashboardGrid.dragToIndex = targetIdx;
                                    // Reset merge readiness when target changes
                                    if (dashboardGrid.hoverTargetIndex !== targetIdx) {
                                        dashboardGrid.readyToMerge = false;
                                        dashboardGrid.hoverTargetIndex = targetIdx;
                                        folderMergeTimer.targetIndex = targetIdx;
                                        folderMergeTimer.restart();
                                    }
                                } else {
                                    dashboardGrid.hoverTargetIndex = -1;
                                    dashboardGrid.readyToMerge = false;
                                    folderMergeTimer.stop();
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            PlasmaComponents.Label {
                visible: dashboardModel.count === 0
                anchors.centerIn: parent
                text: i18n("Right-click an app and choose \"Add to Dashboard\"")
                opacity: 0.5
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
            }
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

            onFolderPopupOpenChanged: {
                if (folderPopupOpen) {
                    lastOpenedFolderIndex = rootItem.openFolderIndex;
                    folderOpenAnim.start();
                } else {
                    folderCloseAnim.start();
                }
            }

            ParallelAnimation {
                id: folderOpenAnim
                NumberAnimation { target: folderDimBg; property: "opacity"; from: 0; to: 0.4; duration: root.folderPopupDuration; easing.type: Easing.OutCubic }
                NumberAnimation { target: folderCard; property: "scale"; from: 0.8; to: 1.0; duration: root.folderPopupDuration; easing.type: Easing.OutCubic }
                NumberAnimation { target: folderCard; property: "opacity"; from: 0; to: 1.0; duration: root.folderPopupDuration; easing.type: Easing.OutCubic }
            }

            ParallelAnimation {
                id: folderCloseAnim
                NumberAnimation { target: folderDimBg; property: "opacity"; from: 0.4; to: 0; duration: root.folderPopupDuration; easing.type: Easing.InCubic }
                NumberAnimation { target: folderCard; property: "scale"; from: 1.0; to: 0.8; duration: root.folderPopupDuration; easing.type: Easing.InCubic }
                NumberAnimation { target: folderCard; property: "opacity"; from: 1.0; to: 0; duration: root.folderPopupDuration; easing.type: Easing.InCubic }
                onFinished: folderPopup.lastOpenedFolderIndex = -1
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
                opacity: 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        rootItem.openFolderIndex = -1;
                    }
                }
            }

            // Folder card
            Rectangle {
                id: folderCard
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.5, folderGrid.columns * root.cellSize + Kirigami.Units.largeSpacing * 4)
                height: folderNameEdit.height + folderGrid.height + Kirigami.Units.largeSpacing * 4
                radius: 20
                color: colorWithAlpha(Kirigami.Theme.backgroundColor, 0.85)

                visible: folderPopup.visible
                scale: 0.8
                opacity: 0

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
                    readOnly: true
                    selectByMouse: true
                    width: folderCard.width - Kirigami.Units.largeSpacing * 4

                    onAccepted: {
                        readOnly = true;
                        rootItem.renameFolder(rootItem.openFolderIndex, text);
                    }

                    Keys.onEscapePressed: {
                        readOnly = true;
                        text = dashboardModel.get(rootItem.openFolderIndex).name || "";
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

                    property int columns: {
                        if (rootItem.openFolderIndex < 0 || rootItem.openFolderIndex >= dashboardModel.count) return 3;
                        var item = dashboardModel.get(rootItem.openFolderIndex);
                        if (!item || !item.apps) return 3;
                        var cnt = item.apps.count;
                        if (cnt <= 4) return 2;
                        if (cnt <= 9) return 3;
                        return 4;
                    }

                    property int dragFromIndex: -1
                    property int dragToIndex: -1

                    width: columns * root.cellSize
                    height: {
                        var idx = folderPopup.displayedFolderIndex;
                        if (idx < 0 || idx >= dashboardModel.count) return root.cellSize;
                        var item = dashboardModel.get(idx);
                        if (!item || !item.apps) return root.cellSize;
                        return Math.ceil(item.apps.count / columns) * root.cellSize;
                    }
                    cellWidth: root.cellSize
                    cellHeight: root.cellSize
                    interactive: false

                    moveDisplaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutCubic }
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

                        opacity: (folderItemMA.dragging && folderGrid.dragFromIndex === index) ? 0.3 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

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
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        scale: folderItemMA.containsMouse && !folderItemMA.dragging ? 1.06 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                        }

                        MouseArea {
                            id: folderItemMA
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
                                    folderItemContextMenu.appDesktopFile = model.desktopFile;
                                    folderItemContextMenu.folderIdx = rootItem.openFolderIndex;
                                    folderItemContextMenu.visualParent = folderDelegate;
                                    menuOpenTimer.openMenu(folderItemContextMenu, mouse.x, mouse.y);
                                } else {
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                }
                            }

                            onReleased: mouse => {
                                if (dragging) {
                                    dragging = false;
                                    dragGhost.visible = false;

                                    // Check if released outside the folder card — move out
                                    var posInCard = mapToItem(folderCard, mouse.x, mouse.y);
                                    if (posInCard.x < 0 || posInCard.x > folderCard.width
                                        || posInCard.y < 0 || posInCard.y > folderCard.height) {
                                        rootItem.moveAppOutOfFolder(rootItem.openFolderIndex, folderGrid.dragFromIndex);
                                    } else if (folderGrid.dragFromIndex !== -1 && folderGrid.dragToIndex !== -1
                                               && folderGrid.dragFromIndex !== folderGrid.dragToIndex) {
                                        rootItem.reorderInFolder(rootItem.openFolderIndex,
                                                                 folderGrid.dragFromIndex, folderGrid.dragToIndex);
                                    }

                                    folderGrid.dragFromIndex = -1;
                                    folderGrid.dragToIndex = -1;
                                } else if (mouse.button === Qt.LeftButton) {
                                    dashLauncher.connectSource("kioclient exec " + model.desktopFile + " #" + Date.now());
                                    rootItem.openFolderIndex = -1;
                                    closeWithAnimation();
                                }
                                pressX = -1;
                                pressY = -1;
                            }

                            onPositionChanged: mouse => {
                                if (pressX !== -1 && !dragging) {
                                    var dx = mouse.x - pressX;
                                    var dy = mouse.y - pressY;
                                    if (dx*dx + dy*dy > 400) {
                                        dragging = true;
                                        folderGrid.dragFromIndex = index;
                                        dragGhost.iconSource = model.icon;
                                        dragGhost.labelText = model.name;
                                        dragGhost.visible = true;
                                    }
                                }
                                if (dragging) {
                                    var globalPos = mapToItem(rootItem, mouse.x, mouse.y);
                                    dragGhost.x = globalPos.x - dragGhost.width / 2;
                                    dragGhost.y = globalPos.y - dragGhost.height / 2;

                                    // Find reorder target within folder grid
                                    var mapped = mapToItem(folderGrid.contentItem, mouse.x, mouse.y);
                                    var targetIdx = folderGrid.indexAt(mapped.x, mapped.y);
                                    if (targetIdx !== -1 && targetIdx !== folderGrid.dragFromIndex) {
                                        folderGrid.dragToIndex = targetIdx;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        PlasmaExtras.Menu {
            id: folderItemContextMenu
            property string appDesktopFile: ""
            property int folderIdx: -1

            PlasmaExtras.MenuItem {
                text: i18n("Remove from Folder")
                icon: "edit-delete-remove"
                onClicked: {
                    var fi = folderItemContextMenu.folderIdx;
                    var df = folderItemContextMenu.appDesktopFile;
                    folderItemContextMenu.close();
                    rootItem.removeFromFolder(fi, df);
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
                animatedEntrance: false
                model: runnerModel.count > 0 ? runnerModel.modelForRow(0) : undefined

                onKeyNavDown: {
                    runnerGrid.focus = false;
                    systemFavoritesGrid.tryActivate(0, 0);
                    systemFavoritesGrid.forceActiveFocus();
                }
                onKeyNavUp: {
                    runnerGrid.focus = false;
                    searchField.focus = true;
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        runnerGrid.focus = false;
                        systemFavoritesGrid.tryActivate(0, 0);
                        systemFavoritesGrid.forceActiveFocus();
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
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
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

                            scale: runMA.pressed ? 0.88 : runMA.containsMouse ? 1.08 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                            }

                            PlasmaComponents.ToolTip.text: model.AppName || model.display || ""
                            PlasmaComponents.ToolTip.visible: runMA.containsMouse
                            PlasmaComponents.ToolTip.delay: 500

                            MouseArea {
                                id: runMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        rootItem.openDockContextMenu(runningTasksModel, index, parent, mouse.x, mouse.y, {
                                            isWindow: model.IsWindow === true,
                                            isLauncher: model.IsLauncher === true,
                                            isMinimized: model.IsMinimized === true,
                                            isMaximized: model.IsMaximized === true,
                                            isKeepAbove: model.IsKeepAbove === true,
                                            isKeepBelow: model.IsKeepBelow === true,
                                            isFullScreen: model.IsFullScreen === true
                                        });
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        var idx = runningTasksModel.index(index, 0);
                                        runningTasksModel.requestNewInstance(idx);
                                    } else {
                                        var idx = runningTasksModel.index(index, 0);
                                        runningTasksModel.requestActivate(idx);
                                        closeWithAnimation();
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

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    systemFavoritesGrid.focus = false;
                    searchField.focus = true;
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
        rootModel.refresh();
        searchField.forceActiveFocus();
    }
}
