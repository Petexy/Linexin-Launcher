/*
    SPDX-FileCopyrightText: 2026 Petexy
    Based on Eike Hein's original work
    SPDX-License-Identifier: GPL-3.0-or-later

    ItemGridView with staggered entrance animation support
*/

import QtQuick 2.15
import QtQuick.Controls

import org.kde.kquickcontrolsaddons 2.0
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

FocusScope {
    id: itemGrid

    signal keyNavLeft
    signal keyNavRight
    signal keyNavUp
    signal keyNavDown

    signal itemActivated(int index, string actionId, string argument)
    signal itemChildActivated(int index)

    property bool dragEnabled: true
    property bool dropEnabled: false
    property bool showLabels: true
    property bool grabFocus: false
    property bool animatedEntrance: false

    // Tiles are group headings (the A-Z letters), not apps: the label *is* the
    // content, so it is drawn large and centred instead of captioning an icon.
    property bool groupLabels: false
    // Multiplier on the delegate label point size, so each view that hosts a
    // grid can follow its own font-size setting.
    property real labelFontScale: 1.0

    property alias currentIndex: gridView.currentIndex
    property alias currentItem: gridView.currentItem
    property alias contentItem: gridView.contentItem
    property alias count: gridView.count
    property alias model: gridView.model
    property alias verticalLayoutDirection: gridView.verticalLayoutDirection

    property alias cellWidth: gridView.cellWidth
    property alias cellHeight: gridView.cellHeight
    property alias iconSize: gridView.iconSize

    property var horizontalScrollBarPolicy: PlasmaComponents.ScrollBar.AlwaysOff
    property var verticalScrollBarPolicy: PlasmaComponents.ScrollBar.AsNeeded

    // Staggered entrance animation
    property bool _entranceTriggered: false

    function animateEntrance() {
        _entranceTriggered = false;
        Qt.callLater(function() {
            _entranceTriggered = true;
        });
    }

    function resetEntrance() {
        _entranceTriggered = false;
    }

    onDropEnabledChanged: {
        if (!dropEnabled && model && "dropPlaceholderIndex" in model) {
            model.dropPlaceholderIndex = -1;
        }
    }

    onFocusChanged: {
        if (!focus) {
            currentIndex = -1;
        }
    }

    // GridView can briefly be narrower than one cell (or have a zero cell
    // width during layout). Keep every navigation calculation on one safe
    // column count so it can never produce Infinity or NaN.
    function columnCount() {
        if (itemGrid.cellWidth <= 0) {
            return 1;
        }
        return Math.max(1, Math.floor(itemGrid.width / itemGrid.cellWidth));
    }

    function currentRow() {
        if (currentIndex === -1) return -1;
        return Math.floor(currentIndex / columnCount());
    }

    function currentCol() {
        if (currentIndex === -1) return -1;
        return currentIndex % columnCount();
    }

    function lastRow() {
        return Math.ceil(count / columnCount()) - 1;
    }

    function tryActivate(row, col) {
        if (count) {
            var columns = columnCount();
            var rows = Math.ceil(count / columns);
            row = Math.min(row, rows - 1);
            col = Math.min(col, columns - 1);
            currentIndex = Math.min(row ? ((Math.max(1, row) * columns) + col) : col, count - 1);
            focus = true;
        }
    }

    function forceLayout() {
        gridView.forceLayout();
    }

    DropArea {
        id: dropArea

        width: itemGrid.width
        height: itemGrid.height

        onPositionChanged: event => {
            if (!itemGrid.dropEnabled || !itemGrid.model
                    || gridView.animating || !kicker.dragSource) {
                return;
            }

            if (itemGrid.cellWidth <= 0) {
                return;
            }

            var x = Math.max(0, event.x - (width % itemGrid.cellWidth));
            var cPos = mapToItem(gridView.contentItem, x, event.y);
            var item = gridView.itemAt(cPos.x, cPos.y);

            if (item) {
                if (kicker.dragSource.parent === gridView.contentItem) {
                    if (item !== kicker.dragSource) {
                        item.GridView.view.model.moveRow(kicker.dragSource.itemIndex, item.itemIndex);
                    }
                } else if (kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model
                           && !itemGrid.model.isFavorite(kicker.dragSource.favoriteId)) {
                    var hasPlaceholder = (itemGrid.model.dropPlaceholderIndex !== -1);
                    itemGrid.model.dropPlaceholderIndex = item.itemIndex;
                    if (!hasPlaceholder) {
                        gridView.currentIndex = (item.itemIndex - 1);
                    }
                }
            } else if (kicker.dragSource.parent !== gridView.contentItem
                       && kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model
                       && !itemGrid.model.isFavorite(kicker.dragSource.favoriteId)) {
                var hasPlaceholder = (itemGrid.model.dropPlaceholderIndex !== -1);
                itemGrid.model.dropPlaceholderIndex = hasPlaceholder ? itemGrid.model.count - 1 : itemGrid.model.count;
                if (!hasPlaceholder) {
                    gridView.currentIndex = (itemGrid.model.count - 1);
                }
            } else {
                itemGrid.model.dropPlaceholderIndex = -1;
                gridView.currentIndex = -1;
            }
        }

        onExited: {
            if (itemGrid.model && "dropPlaceholderIndex" in itemGrid.model) {
                itemGrid.model.dropPlaceholderIndex = -1;
                gridView.currentIndex = -1;
            }
        }

        onDropped: {
            try {
                if (kicker.dragSource && kicker.dragSource.parent !== gridView.contentItem
                    && kicker.dragSource.GridView.view.model.favoritesModel === itemGrid.model) {
                    itemGrid.model.addFavorite(kicker.dragSource.favoriteId, itemGrid.model.dropPlaceholderIndex);
                    gridView.currentIndex = -1;
                }
            } catch(e) {
                gridView.currentIndex = -1;
            }
        }

        Timer {
            id: resetAnimationDurationTimer
            interval: 120
            repeat: false
            onTriggered: {
                gridView.animationDuration = interval - 20;
            }
        }

        GridView {
            id: gridView

            width: itemGrid.width
            height: itemGrid.height

            signal itemContainsMouseChanged(bool containsMouse)

            property int iconSize: Kirigami.Units.iconSizes.huge
            property bool animating: false
            property int animationDuration: itemGrid.dropEnabled ? resetAnimationDurationTimer.interval : 0

            focus: true
            currentIndex: -1

            // When content fits, disable interactive so wheel events propagate to parent Flickable
            interactive: contentHeight > height

            ScrollBar.horizontal: ScrollBar {
                policy: itemGrid.horizontalScrollBarPolicy
            }
            ScrollBar.vertical: ScrollBar {
                policy: itemGrid.verticalScrollBarPolicy
            }

            snapMode: GridView.NoSnap
            flickDeceleration: 1500

            WheelHandler {
                id: wheelHandler
                enabled: gridView.contentHeight > gridView.height
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    var delta = event.angleDelta.y;
                    gridView.contentY = Math.max(0,
                        Math.min(gridView.contentY - delta * 2,
                                 gridView.contentHeight - gridView.height));
                    event.accepted = true;
                }
            }

            move: Transition {
                enabled: itemGrid.dropEnabled
                SequentialAnimation {
                    PropertyAction { target: gridView; property: "animating"; value: true }
                    NumberAnimation {
                        duration: gridView.animationDuration
                        properties: "x, y"
                        easing.type: Easing.OutCubic
                    }
                    PropertyAction { target: gridView; property: "animating"; value: false }
                }
            }

            moveDisplaced: Transition {
                enabled: itemGrid.dropEnabled
                SequentialAnimation {
                    PropertyAction { target: gridView; property: "animating"; value: true }
                    NumberAnimation {
                        duration: gridView.animationDuration
                        properties: "x, y"
                        easing.type: Easing.OutCubic
                    }
                    PropertyAction { target: gridView; property: "animating"; value: false }
                }
            }

            keyNavigationWraps: false
            boundsBehavior: Flickable.StopAtBounds

            delegate: ItemGridDelegate {
                showLabel: itemGrid.showLabels
                groupLabel: itemGrid.groupLabels
                labelFontScale: itemGrid.labelFontScale
                animatedEntrance: itemGrid.animatedEntrance
                entranceTriggered: itemGrid._entranceTriggered
            }

            highlight: Rectangle {
                color: colorWithAlpha(Kirigami.Theme.highlightColor, 0.5)
                radius: 12

                // Fade + scale in on first appearance instead of teleporting,
                // then glide between cells with a slight elastic settle
                opacity: gridView.currentIndex === -1 ? 0 : 1
                scale: gridView.currentIndex === -1 ? 0.9 : 1

                Behavior on opacity {
                    NumberAnimation { duration: root.hoverEffectDuration; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root.hoverEffectDuration * 1.6
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }
                Behavior on x {
                    NumberAnimation {
                        duration: root.hoverEffectDuration * 1.3
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: root.hoverEffectDuration * 1.3
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
            }

            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0

            onCurrentIndexChanged: {
                if (currentIndex !== -1) {
                    hoverArea.hoverEnabled = false;
                    focus = true;
                }
            }

            onCountChanged: {
                animationDuration = 0;
                resetAnimationDurationTimer.start();
                if (count > 0 && itemGrid.grabFocus) {
                    currentIndex = 0;
                    focus = true;
                    forceActiveFocus();
                }
            }

            onModelChanged: {
                currentIndex = -1;
            }

            Keys.onLeftPressed: event => {
                if (itemGrid.currentCol() !== 0) {
                    event.accepted = true;
                    moveCurrentIndexLeft();
                } else {
                    itemGrid.keyNavLeft();
                }
            }

            Keys.onRightPressed: event => {
                var columns = itemGrid.columnCount();
                if (itemGrid.currentCol() !== columns - 1 && currentIndex !== count - 1) {
                    event.accepted = true;
                    moveCurrentIndexRight();
                } else {
                    itemGrid.keyNavRight();
                }
            }

            Keys.onUpPressed: event => {
                if (itemGrid.currentRow() !== 0) {
                    event.accepted = true;
                    moveCurrentIndexUp();
                    positionViewAtIndex(currentIndex, GridView.Contain);
                } else {
                    itemGrid.keyNavUp();
                }
            }

            Keys.onDownPressed: event => {
                if (itemGrid.currentRow() < itemGrid.lastRow()) {
                    event.accepted = true;
                    var columns = itemGrid.columnCount();
                    var newIndex = currentIndex + columns;
                    currentIndex = Math.min(newIndex, gridView.count - 1);
                    positionViewAtIndex(currentIndex, GridView.Visible);
                } else {
                    itemGrid.keyNavDown();
                }
            }

            onItemContainsMouseChanged: containsMouse => {
                if (!containsMouse) {
                    hoverArea.pressX = -1;
                    hoverArea.pressY = -1;
                    hoverArea.lastX = -1;
                    hoverArea.lastY = -1;
                    hoverArea.pressedItem = null;
                    hoverArea.hoverEnabled = true;
                }
            }
        }

        MouseArea {
            id: hoverArea

            width: Math.max(0, itemGrid.width - Kirigami.Units.gridUnit)
            height: itemGrid.height

            property int pressX: -1
            property int pressY: -1
            property int lastX: -1
            property int lastY: -1
            property Item pressedItem: null

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            function updatePositionProperties(x, y) {
                if (lastX === x && lastY === y) return;
                lastX = x;
                lastY = y;

                var cPos = mapToItem(gridView.contentItem, x, y);
                var item = gridView.itemAt(cPos.x, cPos.y);

                if (!item) {
                    gridView.currentIndex = -1;
                    pressedItem = null;
                } else {
                    itemGrid.focus = (item.itemIndex !== -1);
                    itemGrid.forceActiveFocus();
                    gridView.currentIndex = item.itemIndex;
                }

                return item;
            }

            onPressed: mouse => {
                mouse.accepted = true;

                // Force position update on press — bypass hover cache so
                // gridView.currentIndex is always accurate when we need it.
                lastX = -1;
                lastY = -1;
                updatePositionProperties(mouse.x, mouse.y);

                if (mouse.button === Qt.RightButton) {
                    // Don't set pressX/pressY for right-click — otherwise
                    // mouse movement after the context menu closes can
                    // inadvertently trigger a native drag (four-arrow cursor).
                    pressX = -1;
                    pressY = -1;
                    if (gridView.currentItem) {
                        var mapped = mapToItem(gridView.currentItem, mouse.x, mouse.y);
                        rootItem.openAppContextMenu(gridView.currentItem, gridView.currentItem.m, mapped.x, mapped.y);
                    }
                } else {
                    pressX = mouse.x;
                    pressY = mouse.y;
                    pressedItem = gridView.currentItem;
                }
            }

            onReleased: mouse => {
                mouse.accepted = true;

                var hadPressedItem = (pressedItem !== null);
                updatePositionProperties(mouse.x, mouse.y);

                if (!dragHelper.dragging) {
                    // Only activate if the cursor is still over the same item that was pressed
                    if (hadPressedItem && gridView.currentItem === pressedItem) {
                        if ("trigger" in gridView.model) {
                            if (gridView.model.trigger(pressedItem.itemIndex, "", null)) {
                                root.launchZoomFromItem(pressedItem);
                            } else {
                                itemGrid.itemChildActivated(pressedItem.itemIndex);
                            }
                        }
                        itemGrid.itemActivated(pressedItem.itemIndex, "", null);
                    } else if (!hadPressedItem && mouse.button === Qt.LeftButton) {
                        // Only close if the user clicked on empty space (never pressed an app)
                        root.closeWithAnimation();
                    }
                }

                pressX = pressY = -1;
                pressedItem = null;
            }

            onPositionChanged: mouse => {
                var item = pressedItem ? pressedItem : updatePositionProperties(mouse.x, mouse.y);

                if (gridView.currentIndex !== -1 && item) {
                    if (itemGrid.dragEnabled && pressX !== -1 && dragHelper.isDrag(pressX, pressY, mouse.x, mouse.y)) {
                        if (item.m && "pluginName" in item.m) {
                            dragHelper.startDrag(kicker, item.url, item.icon,
                                                 "text/x-plasmoidservicename", item.m.pluginName);
                        } else if (item.url) {
                            dragHelper.startDrag(kicker, item.url);
                        }
                        kicker.dragSource = item;
                        pressX = -1;
                        pressY = -1;
                    }
                }
            }
        }
    }
}
