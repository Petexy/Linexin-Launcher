/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later

    Recent Apps / Recent Files view — purpose-built around Plasma's 15-entry
    usage-history cap. Apps render as a hero grid of at most 5×3 (a full
    history is exactly one complete block); files render as roomy detail rows
    with their location, since a file is identified by its name, not its icon.
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

    // ---- Apps layout: at most 5 columns × 3 rows = the 15-entry cap ----
    readonly property int appCols: Math.max(1, Math.min(5, appsGrid.count))
    readonly property int appRows: Math.max(1, Math.ceil(appsGrid.count / 5))
    readonly property int cellOverhead: root.cellSize - root.iconSize

    // Icons grow up to 1.6× to own the stage, bounded by what actually fits.
    // The row divisor never drops below 2 so a near-empty history doesn't
    // produce comically large icons.
    readonly property int heroIconSize: {
        var availH = height - headerArea.height - contentColumn.spacing * 2;
        var byH = availH / Math.max(appRows, 2) - cellOverhead;
        var byW = (width * 0.85) / 5 - cellOverhead;
        return Math.round(Math.max(root.iconSize, Math.min(root.iconSize * 1.6, byH, byW)));
    }
    readonly property int heroCellSize: heroIconSize + cellOverhead

    // ---- Files layout: one roomy column up to 8 entries, two beyond ----
    readonly property int fileCols: itemCount > 8 ? 2 : 1
    readonly property int fileRows: Math.max(1, Math.ceil(itemCount / fileCols))
    readonly property int fileRowHeight: Math.round(Kirigami.Units.gridUnit * 2.8)
    readonly property int fileColWidth: Math.min(Kirigami.Units.gridUnit * 26,
                                                 Math.floor((width - Kirigami.Units.largeSpacing * 2) / Math.max(1, fileCols)))

    readonly property int blockWidth: itemCount === 0
        ? Kirigami.Units.gridUnit * 24
        : (filesTab ? fileCols * fileColWidth : appCols * heroCellSize)
    readonly property int headerWidth: Math.min(width, Math.max(blockWidth, Kirigami.Units.gridUnit * 24))

    function animateEntrance() {
        appsGrid.animateEntrance();
        filesGrid.animateEntrance();
    }

    function resetEntrance() {
        appsGrid.resetEntrance();
        filesGrid.resetEntrance();
    }

    function tryActivate() {
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
        }
    }

    // Switching between the two recent tabs disarms the clear button
    Connections {
        target: categoryRow
        function onCurrentCategoryChanged() {
            clearButton.armed = false;
            clearDisarmTimer.stop();
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

        onActionClicked: (actionId, actionArgument) => {
            var closeRequested = filesGrid.model.trigger(itemIndex, actionId, actionArgument);
            if (closeRequested === true) {
                root.closeWithAnimation();
            }
        }
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing * 2

        // =============================================
        //                  HEADER
        // =============================================
        Item {
            id: headerArea
            width: recentView.headerWidth
            height: Math.max(titleRow.implicitHeight, clearButton.height)
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
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
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                PlasmaComponents.Label {
                    visible: recentView.itemCount > 0
                    text: i18np("%1 item", "%1 items", recentView.itemCount)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Click once to arm, again to confirm — forgetting the usage
            // history cannot be undone.
            Rectangle {
                id: clearButton

                anchors.right: parent.right
                anchors.rightMargin: Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + Kirigami.Units.largeSpacing * 3
                height: clearLabel.implicitHeight + Kirigami.Units.largeSpacing
                radius: height / 2

                enabled: recentView.itemCount > 0
                opacity: enabled ? 1.0 : 0.4

                property bool armed: false

                color: armed
                    ? colorWithAlpha(Kirigami.Theme.negativeTextColor, clearMouseArea.containsMouse ? 0.55 : 0.35)
                    : clearMouseArea.containsMouse
                        ? colorWithAlpha(Kirigami.Theme.highlightColor, 0.3)
                        : colorWithAlpha(Kirigami.Theme.backgroundColor, 0.4)

                Behavior on color {
                    ColorAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }

                scale: clearMouseArea.pressed ? 0.93 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
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
                        text: clearButton.armed ? i18n("Click again to confirm") : i18n("Clear History")
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
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

                    onClicked: {
                        if (clearButton.armed) {
                            clearDisarmTimer.stop();
                            clearButton.armed = false;
                            root.clearRecentHistory();
                        } else {
                            clearButton.armed = true;
                            clearDisarmTimer.restart();
                        }
                    }
                }
            }
        }

        // =============================================
        //          RECENT APPS — HERO GRID
        // =============================================
        ItemGridView {
            id: appsGrid
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

            onKeyNavUp: {
                appsGrid.focus = false;
                searchField.focus = true;
            }
            onKeyNavDown: {
                appsGrid.focus = false;
                systemFavoritesGrid.tryActivate(0, 0);
                systemFavoritesGrid.forceActiveFocus();
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    appsGrid.focus = false;
                    systemFavoritesGrid.tryActivate(0, 0);
                    systemFavoritesGrid.forceActiveFocus();
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
                        systemFavoritesGrid.tryActivate(0, 0);
                        systemFavoritesGrid.forceActiveFocus();
                    } else {
                        moveCurrentIndexDown();
                    }
                } else if (event.key === Qt.Key_Left) {
                    event.accepted = true;
                    moveCurrentIndexLeft();
                } else if (event.key === Qt.Key_Right) {
                    event.accepted = true;
                    moveCurrentIndexRight();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    if (currentIndex >= 0 && "trigger" in model) {
                        if (model.trigger(currentIndex, "", null)) {
                            root.closeWithAnimation();
                        }
                    }
                } else if (event.key === Qt.Key_Tab) {
                    event.accepted = true;
                    filesGrid.focus = false;
                    systemFavoritesGrid.tryActivate(0, 0);
                    systemFavoritesGrid.forceActiveFocus();
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
                            rowEntranceTimer.interval = Math.min(fileRow.itemIndex * 30, 400);
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
                        duration: root.iconEntranceDuration * 0.875
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: rowContent
                        property: "x"
                        from: Kirigami.Units.gridUnit; to: 0
                        duration: root.iconEntranceDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
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
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 0.5
                        }

                        PlasmaComponents.Label {
                            width: parent.width
                            visible: text !== ""
                            text: recentView.prettyPath(model.url)
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1.5
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
                            if (("hasActionList" in model) && model.hasActionList) {
                                fileActionMenu.visualParent = fileRow;
                                fileActionMenu.itemIndex = fileRow.itemIndex;
                                fileActionMenu.actionList = model.actionList;
                                fileActionMenu.open(mouse.x, mouse.y);
                            }
                        } else if ("trigger" in filesGrid.model) {
                            if (filesGrid.model.trigger(fileRow.itemIndex, "", null)) {
                                root.closeWithAnimation();
                            }
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
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
