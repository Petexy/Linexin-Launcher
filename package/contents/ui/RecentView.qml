/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later

    Recent Apps / Recent Files view — purpose-built around Plasma's 15-entry
    usage-history cap. Apps render as a responsive hero grid of up to five
    columns; files render as roomy detail rows with their location, since a
    file is identified by its name, not its icon.
*/

import QtQuick 2.15

import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: recentView

    // Same animated hand-off as dashboardView: fade while zooming slightly
    // toward the viewer, matching the search push underneath
    readonly property bool shown: root.showingRecent && !root.searching
    visible: opacity > 0.01
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 1.05

    Behavior on opacity {
        NumberAnimation { duration: root.animDuration * 0.6; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: root.animDuration * 0.8; easing.type: Easing.OutCubic }
    }

    // Active recent model. currentCategory is untouched while searching, so
    // this stays alive during the search exit animation.
    readonly property var recentModel: (categoryRow.currentCategory >= 0
                                        && categoryRow.currentCategory < root.recentRowCount)
                                       ? rootModel.modelForRow(categoryRow.currentCategory)
                                       : null

    // RootModel orders the recent groups apps-first, so the files tab is
    // row 1 when recent apps are enabled and row 0 otherwise. Checking row
    // indices keeps this locale-independent.
    readonly property bool filesTab: categoryRow.currentCategory === (rootModel.showRecentApps ? 1 : 0)

    readonly property int itemCount: recentModel ? recentModel.count : 0

    // Header, counter and empty state are shared chrome: they follow whichever
    // tab is on screen.
    readonly property real fontScale: filesTab ? root.recentFilesFontScale : root.recentAppsFontScale

    // ---- Apps layout: at most 5 columns, wrapping further on narrow screens ----
    // Non-icon part of a cell (label + padding); grows with the Recent Apps
    // font setting so bigger names still fit under the hero icons.
    readonly property int cellOverhead: Math.round((root.cellSize - root.iconSize)
                                                   * Math.max(1, root.recentAppsFontScale))
    readonly property int availableAppWidth: Math.max(1, width - Kirigami.Units.largeSpacing * 4)
    readonly property int appCols: Math.max(1, Math.min(5, appsGrid.count,
        Math.floor(availableAppWidth / (Kirigami.Units.iconSizes.medium + cellOverhead))))
    readonly property int appRows: Math.max(1, Math.ceil(appsGrid.count / appCols))

    // Icons grow up to 1.6× to own the stage, bounded by what actually fits.
    // The row divisor never drops below 2 so a near-empty history doesn't
    // produce comically large icons.
    readonly property int heroIconSize: {
        var availH = height - headerArea.height - contentColumn.spacing * 2;
        var byH = availH / Math.max(appRows, 2) - cellOverhead;
        var byW = availableAppWidth / appCols - cellOverhead;
        return Math.round(Math.max(Kirigami.Units.iconSizes.small,
                                   Math.min(root.iconSize * 1.6, byH, byW)));
    }
    readonly property int heroCellSize: heroIconSize + cellOverhead

    // ---- Files layout: one roomy column up to 8 entries, two beyond ----
    readonly property int fileCols: itemCount > 8 ? 2 : 1
    readonly property int fileRows: Math.max(1, Math.ceil(itemCount / fileCols))
    // Two stacked labels live in each row, so the row has to grow with them.
    readonly property int fileRowHeight: Math.round(Kirigami.Units.gridUnit * 2.8
                                                    * Math.max(1, root.recentFilesFontScale))
    readonly property int fileColWidth: Math.min(Kirigami.Units.gridUnit * 26,
                                                 Math.floor((width - Kirigami.Units.largeSpacing * 2) / Math.max(1, fileCols)))

    readonly property int blockWidth: itemCount === 0
        ? Kirigami.Units.gridUnit * 24
        : (filesTab ? fileCols * fileColWidth : appCols * heroCellSize)
    readonly property int headerWidth: Math.min(width, Math.max(blockWidth, Kirigami.Units.gridUnit * 24))

    // KActivities fills the recent models asynchronously, so the rows can land
    // after the view is already on screen — and every layout number above is
    // derived from the count. An entrance started before the history settles
    // gets re-laid-out under itself on each insertion: the cells resize while
    // the icons are mid-animation, which reads as the entrance stuttering or
    // playing several times over. Latch the request instead and play it once,
    // after the count has stopped moving. Until then the icons sit hidden, so
    // the resizing costs nothing visually.
    property bool _entrancePending: false

    function animateEntrance() {
        _entrancePending = true;
        appsGrid.resetEntrance();
        filesGrid.resetEntrance();
        entranceSettleTimer.restart();
    }

    function resetEntrance() {
        _entrancePending = false;
        entranceSettleTimer.stop();
        appsGrid.resetEntrance();
        filesGrid.resetEntrance();
    }

    function resetScrollPosition() {
        // These signals can fire while the component is still being built.
        // Defer the id lookup until the Flickable is guaranteed to exist.
        Qt.callLater(function() {
            recentScroller.contentY = 0;
        });
    }

    function closeFileActionMenu() {
        fileActionMenu.actionList = null;
        fileActionMenu.visualParent = null;
        fileActionMenu.itemIndex = -1;
        fileActionMenu.itemUrl = "";
    }

    onItemCountChanged: {
        if (fileActionMenu.opened) {
            closeFileActionMenu();
        }
        if (_entrancePending) {
            entranceSettleTimer.restart();
        }
    }

    Timer {
        id: entranceSettleTimer
        // One frame of quiet is enough: the model inserts its rows in a burst
        // of consecutive event-loop cycles, not spread over time.
        interval: 16
        repeat: false
        onTriggered: {
            recentView._entrancePending = false;
            appsGrid.animateEntrance();
            filesGrid.animateEntrance();
        }
    }

    function tryActivate() {
        if (itemCount <= 0) {
            root.focusSystemActionsOrFallback();
            return;
        }
        if (filesTab) {
            if (filesGrid.count > 0) {
                filesGrid.currentIndex = 0;
                filesGrid.forceActiveFocus();
            }
        } else {
            appsGrid.tryActivate(0, 0);
            appsGrid.forceActiveFocus();
        }
    }

    // Everything the history knows about a file lives in its URL
    function prettyPath(u) {
        var s = String(u);
        try { s = decodeURIComponent(s); } catch (e) { /* malformed escape — show raw */ }
        if (s.indexOf("file://") === 0) {
            s = s.substring(7);
        }
        var slash = s.lastIndexOf("/");
        if (slash <= 0) {
            return "";
        }
        return s.substring(0, slash).replace(/^\/home\/[^\/]+/, "~");
    }

    onShownChanged: {
        if (!shown) {
            clearButton.armed = false;
            clearDisarmTimer.stop();
        } else {
            resetScrollPosition();
        }
    }

    onFilesTabChanged: resetScrollPosition()

    // Switching between the two recent tabs disarms the clear button
    Connections {
        target: categoryRow
        function onCurrentCategoryChanged() {
            clearButton.armed = false;
            clearDisarmTimer.stop();
            recentView.closeFileActionMenu();
        }
    }

    // Close launcher when clicking empty space
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.closeWithAnimation()
    }

    ActionMenu {
        id: fileActionMenu
        property int itemIndex: -1
        property string itemUrl: ""

        onActionClicked: (actionId, actionArgument) => {
            if (!filesGrid.model || itemIndex < 0 || itemIndex >= filesGrid.count) {
                return;
            }

            // A recent model can reorder while its native action menu is open.
            // Never apply the stored row number to a different file.
            var delegateItem = filesGrid.itemAtIndex(itemIndex);
            if (!delegateItem || delegateItem.itemUrl !== itemUrl) {
                return;
            }

            var closeRequested = filesGrid.model.trigger(itemIndex, actionId, actionArgument);
            if (closeRequested === true) {
                root.closeWithAnimation();
            }
        }
    }

    Flickable {
        id: recentScroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, contentColumn.y + contentColumn.height)
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        PlasmaComponents.ScrollBar.vertical: PlasmaComponents.ScrollBar {
            policy: recentScroller.contentHeight > recentScroller.height
                ? PlasmaComponents.ScrollBar.AsNeeded
                : PlasmaComponents.ScrollBar.AlwaysOff
        }

        function ensureItemVisible(item) {
            if (!item || contentHeight <= height) {
                return;
            }

            var position = item.mapToItem(contentItem, 0, 0);
            var margin = Kirigami.Units.largeSpacing;
            var itemTop = Math.max(0, position.y - margin);
            var itemBottom = position.y + item.height + margin;
            if (itemTop < contentY) {
                contentY = itemTop;
            } else if (itemBottom > contentY + height) {
                contentY = Math.min(contentHeight - height, itemBottom - height);
            }
        }

        Column {
            id: contentColumn
            width: recentScroller.width
            y: Math.max(0, (recentScroller.height - height) / 2)
            spacing: Kirigami.Units.largeSpacing * 2

        // =============================================
        //                  HEADER
        // =============================================
        Item {
            id: headerArea
            width: recentView.headerWidth
            readonly property bool stacked: titleRow.implicitWidth + clearButton.width
                + Kirigami.Units.largeSpacing * 2 > width
            height: stacked
                ? titleRow.implicitHeight + clearButton.height + Kirigami.Units.largeSpacing
                : Math.max(titleRow.implicitHeight, clearButton.height)
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                id: titleRow
                x: headerArea.stacked
                    ? Math.max(0, (headerArea.width - implicitWidth) / 2)
                    : Kirigami.Units.smallSpacing
                y: headerArea.stacked ? 0 : (headerArea.height - height) / 2
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: recentView.filesTab ? "document-open-recent" : "chronometer"
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 0.7
                }

                PlasmaComponents.Label {
                    text: recentView.filesTab ? i18n("Recent Files") : i18n("Recent Apps")
                    font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize + 3, recentView.fontScale)
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                PlasmaComponents.Label {
                    visible: recentView.itemCount > 0
                    text: i18np("%1 item", "%1 items", recentView.itemCount)
                    font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 0.5, recentView.fontScale)
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Click once to arm, again to confirm — forgetting the usage
            // history cannot be undone.
            Rectangle {
                id: clearButton

                x: headerArea.stacked
                    ? Math.max(0, (headerArea.width - width) / 2)
                    : headerArea.width - width - Kirigami.Units.smallSpacing
                y: headerArea.stacked
                    ? titleRow.implicitHeight + Kirigami.Units.largeSpacing
                    : (headerArea.height - height) / 2
                width: clearLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                height: clearLabel.implicitHeight + Kirigami.Units.largeSpacing
                radius: height / 2

                enabled: recentView.itemCount > 0
                opacity: enabled ? 1.0 : 0.4
                activeFocusOnTab: enabled
                Accessible.role: Accessible.Button
                Accessible.name: clearLabelText.text
                Accessible.onPressAction: activate(true)

                property bool armed: false

                color: armed
                    ? colorWithAlpha(Kirigami.Theme.negativeTextColor,
                                     (clearMouseArea.containsMouse || activeFocus) ? 0.55 : 0.35)
                    : (clearMouseArea.containsMouse || activeFocus)
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.3)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)
                border.width: activeFocus ? 2 : 0
                border.color: Kirigami.Theme.focusColor
                onActiveFocusChanged: {
                    if (activeFocus) {
                        recentScroller.ensureItemVisible(clearButton);
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                scale: clearMouseArea.pressed ? 0.93 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                }

                function activate(restoreFocus) {
                    if (!enabled) {
                        return;
                    }

                    if (armed) {
                        var shouldRestoreFocus = restoreFocus === true || activeFocus;
                        clearDisarmTimer.stop();
                        armed = false;
                        root.clearRecentHistory();
                        if (shouldRestoreFocus) {
                            Qt.callLater(function() {
                                root.focusCurrentCategory();
                            });
                        }
                    } else {
                        armed = true;
                        clearDisarmTimer.restart();
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                        event.accepted = true;
                        activate(true);
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        recentView.tryActivate();
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        event.accepted = true;
                        root.focusCurrentCategory();
                    }
                }

                Row {
                    id: clearLabel
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: clearButton.armed ? "dialog-warning" : "edit-clear-history"
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PlasmaComponents.Label {
                        id: clearLabelText
                        text: clearButton.armed ? i18n("Click again to confirm") : i18n("Clear History")
                        font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 0.5, recentView.fontScale)
                        color: Kirigami.Theme.textColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Timer {
                    id: clearDisarmTimer
                    interval: 3000
                    repeat: false
                    onTriggered: clearButton.armed = false
                }

                MouseArea {
                    id: clearMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: clearButton.activate(false)
                }
            }
        }

        // =============================================
        //          RECENT APPS — HERO GRID
        // =============================================
        ItemGridView {
            id: appsGrid
            labelFontScale: root.recentAppsFontScale
            visible: !recentView.filesTab && recentView.itemCount > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: recentView.appCols * recentView.heroCellSize + Kirigami.Units.gridUnit
            height: recentView.appRows * recentView.heroCellSize
            cellWidth: recentView.heroCellSize
            cellHeight: recentView.heroCellSize
            iconSize: recentView.heroIconSize
            model: (!recentView.filesTab && recentView.recentModel) ? recentView.recentModel : null
            dragEnabled: false
            dropEnabled: false
            animatedEntrance: true
            verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff
            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    Qt.callLater(function() {
                        recentScroller.ensureItemVisible(appsGrid.currentItem);
                    });
                }
            }

            onKeyNavUp: {
                appsGrid.focus = false;
                searchField.focus = true;
            }
            onKeyNavDown: {
                appsGrid.focus = false;
                root.focusSystemActionsOrFallback();
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                    appsGrid.focus = false;
                    clearButton.forceActiveFocus();
                } else if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    appsGrid.focus = false;
                    root.focusSystemActionsOrFallback();
                } else if (event.key === Qt.Key_Backspace) {
                    event.accepted = true;
                    searchField.forceActiveFocus();
                    searchField.backspace();
                } else if (event.text !== "" && !(event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true;
                    searchField.forceActiveFocus();
                    searchField.appendText(event.text);
                }
            }
        }

        // =============================================
        //         RECENT FILES — DETAIL ROWS
        // =============================================
        GridView {
            id: filesGrid
            visible: recentView.filesTab && recentView.itemCount > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: recentView.fileCols * recentView.fileColWidth
            height: recentView.fileRows * recentView.fileRowHeight
            cellWidth: recentView.fileColWidth
            cellHeight: recentView.fileRowHeight

            // Fill top-to-bottom so recency reads down the column, not zig-zag
            flow: GridView.FlowTopToBottom
            interactive: false
            currentIndex: -1
            keyNavigationWraps: false

            model: (recentView.filesTab && recentView.recentModel) ? recentView.recentModel : null

            property bool _entranceTriggered: false
            function animateEntrance() {
                _entranceTriggered = false;
                Qt.callLater(function() { _entranceTriggered = true; });
            }
            function resetEntrance() {
                _entranceTriggered = false;
            }

            onActiveFocusChanged: {
                if (!activeFocus) {
                    currentIndex = -1;
                }
            }
            onCurrentIndexChanged: {
                if (currentIndex >= 0) {
                    Qt.callLater(function() {
                        recentScroller.ensureItemVisible(filesGrid.currentItem);
                    });
                }
            }
            onModelChanged: currentIndex = -1

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) {
                    event.accepted = true;
                    if (currentIndex % recentView.fileRows === 0) {
                        filesGrid.focus = false;
                        searchField.focus = true;
                    } else {
                        moveCurrentIndexUp();
                    }
                } else if (event.key === Qt.Key_Down) {
                    event.accepted = true;
                    if ((currentIndex % recentView.fileRows) === recentView.fileRows - 1
                        || currentIndex === count - 1) {
                        filesGrid.focus = false;
                        root.focusSystemActionsOrFallback();
                    } else {
                        moveCurrentIndexDown();
                    }
                } else if (event.key === Qt.Key_Left) {
                    event.accepted = true;
                    moveCurrentIndexLeft();
                } else if (event.key === Qt.Key_Right) {
                    event.accepted = true;
                    moveCurrentIndexRight();
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
                } else if (event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                    filesGrid.focus = false;
                    clearButton.forceActiveFocus();
                } else if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    filesGrid.focus = false;
                    root.focusSystemActionsOrFallback();
                } else if (event.key === Qt.Key_Backspace) {
                    event.accepted = true;
                    searchField.forceActiveFocus();
                    searchField.backspace();
                } else if (event.text !== "" && !(event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true;
                    searchField.forceActiveFocus();
                    searchField.appendText(event.text);
                }
            }

            delegate: Item {
                id: fileRow
                width: filesGrid.cellWidth
                height: filesGrid.cellHeight

                property int itemIndex: index
                property string itemUrl: String(model.url || "")
                Accessible.role: Accessible.Button
                Accessible.name: model.display || ""
                Accessible.description: recentView.prettyPath(model.url)
                Accessible.onPressAction: activate()

                function activate() {
                    if (filesGrid.model && "trigger" in filesGrid.model
                            && filesGrid.model.trigger(itemIndex, "", null)) {
                        root.launchZoomFromItem(fileRow);
                    }
                }

                function openContextMenu(x, y) {
                    if (("hasActionList" in model) && model.hasActionList) {
                        fileActionMenu.visualParent = fileRow;
                        fileActionMenu.itemIndex = itemIndex;
                        fileActionMenu.itemUrl = fileRow.itemUrl;
                        fileActionMenu.actionList = model.actionList;
                        fileActionMenu.open(x === undefined ? width / 2 : x,
                                            y === undefined ? height / 2 : y);
                    }
                }

                // Staggered entrance: fade + short slide-in from the left
                opacity: root.iconEntranceDuration > 0 ? 0 : 1

                Component.onCompleted: {
                    if (filesGrid._entranceTriggered || root.iconEntranceDuration <= 0) {
                        opacity = 1;
                    }
                }

                Connections {
                    target: filesGrid
                    function on_EntranceTriggeredChanged() {
                        if (root.iconEntranceDuration <= 0) {
                            fileRow.opacity = 1;
                            return;
                        }
                        if (filesGrid._entranceTriggered) {
                            // Single column of rows, so the wave is purely vertical.
                            rowEntranceTimer.interval = root.entranceDelay(fileRow.itemIndex, 0);
                            rowEntranceTimer.start();
                        } else {
                            rowEntranceAnim.stop();
                            rowEntranceTimer.stop();
                            fileRow.opacity = 0;
                        }
                    }
                }

                Timer {
                    id: rowEntranceTimer
                    repeat: false
                    onTriggered: rowEntranceAnim.start()
                }

                ParallelAnimation {
                    id: rowEntranceAnim
                    NumberAnimation {
                        target: fileRow
                        property: "opacity"
                        from: 0; to: 1
                        duration: Math.round(root.iconEntranceDuration * 0.5)
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: rowContent
                        property: "x"
                        from: Kirigami.Units.gridUnit; to: 0
                        duration: Math.round(root.iconEntranceDuration * 0.75)
                        easing.type: Easing.OutQuint
                    }
                }

                // Hover / keyboard highlight pill
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing / 2
                    radius: 12
                    color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.5)
                    opacity: (rowMouse.containsMouse || filesGrid.currentIndex === fileRow.itemIndex) ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                    }
                }

                scale: rowMouse.pressed ? 0.97 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                }

                Item {
                    id: rowContent
                    width: parent.width
                    height: parent.height

                    Kirigami.Icon {
                        id: fileIcon
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.largeSpacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        source: model.decoration
                        animated: false
                    }

                    Column {
                        anchors.left: fileIcon.right
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.largeSpacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        PlasmaComponents.Label {
                            width: parent.width
                            text: model.display || ""
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize + 0.5, root.recentFilesFontScale)
                        }

                        PlasmaComponents.Label {
                            width: parent.width
                            visible: text !== ""
                            text: recentView.prettyPath(model.url)
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize - 1.5, root.recentFilesFontScale)
                            opacity: 0.55
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            fileRow.openContextMenu(mouse.x, mouse.y);
                        } else {
                            fileRow.activate();
                        }
                    }
                }
            }
        }

        // =============================================
        //                EMPTY STATE
        // =============================================
        Column {
            visible: recentView.itemCount === 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: recentView.filesTab ? "document-open-recent" : "chronometer"
                width: Kirigami.Units.iconSizes.huge
                height: width
                opacity: 0.25
                anchors.horizontalCenter: parent.horizontalCenter
            }

            PlasmaComponents.Label {
                text: recentView.filesTab
                    ? i18n("Files you open will show up here")
                    : i18n("Apps you launch will show up here")
                opacity: 0.5
                font.pointSize: root.scaledFont(Kirigami.Theme.defaultFont.pointSize + 1, recentView.fontScale)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        }
    }
}
