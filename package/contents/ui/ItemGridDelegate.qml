/*
    SPDX-FileCopyrightText: 2026 Petexy
    Based on Eike Hein's original work
    SPDX-License-Identifier: GPL-3.0-or-later

    ItemGridDelegate with macOS-style hover scale and staggered entrance animation
*/

import QtQuick 2.15

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: item

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    enabled: !model.disabled

    property bool showLabel: true
    // Set by the grid when this tile is an A-Z group rather than an app.
    property bool groupLabel: false
    property real labelFontScale: 1.0
    property bool animatedEntrance: false
    property bool entranceTriggered: false

    property int itemIndex: model.index
    property string favoriteId: model.favoriteId !== undefined ? model.favoriteId : ""
    property url url: model.url !== undefined ? model.url : ""
    property variant icon: model.decoration !== undefined ? model.decoration : ""
    property var m: model
    property bool hasActionList: ((model.favoriteId !== null)
        || (("hasActionList" in model) && (model.hasActionList === true)))

    Accessible.role: Accessible.MenuItem
    Accessible.name: model.display
    Accessible.onPressAction: activate()

    function activate() {
        // Press animation
        iconItem.pressedScale = true;
        pressReleaseTimer.start();

        var view = GridView.view;
        if (view && view.model && "trigger" in view.model) {
            if (view.model.trigger(item.itemIndex, "", null)) {
                root.launchZoomFromItem(item);
            } else {
                itemGrid.itemChildActivated(item.itemIndex);
            }
        }

        itemGrid.itemActivated(item.itemIndex, "", null);
    }

    // =============================================
    //     STAGGERED ENTRANCE ANIMATION
    // =============================================

    // Start invisible if animated entrance is enabled
    opacity: (animatedEntrance && root.iconEntranceDuration > 0) ? 0 : 1
    scale: (animatedEntrance && root.iconEntranceDuration > 0) ? 1.22 : 1.0

    // Diagonal wave delay for this item's entrance. A flat index * step ramp
    // walks the grid one icon at a time, so the last icon of a 40-slot page
    // waited out the whole cap before it even began; row + col makes the
    // leading diagonal move together. Timing lives in root.entranceDelay().
    function entranceDelay() {
        var view = GridView.view;
        var cols = (view && view.cellWidth > 0) ? Math.max(1, Math.floor(view.width / view.cellWidth)) : 1;
        return root.entranceDelay(Math.floor(itemIndex / cols), itemIndex % cols);
    }

    Component.onCompleted: {
        if (animatedEntrance && entranceTriggered) {
            opacity = 1;
            scale = 1.0;
        } else if (!animatedEntrance) {
            opacity = 1;
            scale = 1.0;
        }
    }

    onEntranceTriggeredChanged: {
        if (!animatedEntrance || root.iconEntranceDuration <= 0) return;
        if (entranceTriggered) {
            entranceTimer.interval = entranceDelay();
            entranceTimer.start();
        } else {
            // Reset to hidden state so the next entrance animates properly
            entranceAnim.stop();
            entranceTimer.stop();
            opacity = 0;
            scale = 1.22;
        }
    }

    Timer {
        id: entranceTimer
        repeat: false
        onTriggered: {
            entranceAnim.start();
        }
    }

    ParallelAnimation {
        id: entranceAnim

        NumberAnimation {
            target: item
            property: "opacity"
            from: 0; to: 1
            duration: Math.round(root.iconEntranceDuration * 0.5)
            easing.type: Easing.OutCubic
        }
        // Settles down from oversized, matching the board's zoom-out. Growing
        // from 0.7 with an OutBack overshoot meant every icon crossed 1.0 from
        // below and bounced back — 40 of those firing on a ramp is the "boiling
        // grid" that read as unfluid. Coming down from 1.22 the icon dips a
        // couple of percent under 1.0 near the end and settles, which keeps the
        // springy character without the collective bounce.
        NumberAnimation {
            target: item
            property: "scale"
            from: 1.22; to: 1.0
            duration: Math.round(root.iconEntranceDuration * 0.75)
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.12, 0.8, 0.24, 1.04, 1.0, 1.0]
        }
    }

    // =============================================
    //       CONTENT WITH HOVER ANIMATIONS
    // =============================================

    Item {
        id: contentWrapper
        anchors.fill: parent

        // Smooth hover scale effect (macOS style)
        scale: {
            if (item.GridView.isCurrentItem && hoverScaleEnabled) {
                return 1.08;
            }
            return 1.0;
        }

        property bool hoverScaleEnabled: true

        Behavior on scale {
            NumberAnimation {
                duration: root.hoverEffectDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }
        }

        transformOrigin: Item.Center

        Kirigami.Icon {
            id: iconItem

            // A-Z group rows carry no icon of their own, so the tile would be a
            // blank square with a caption under it. Drop the icon there and let
            // the letter have the whole cell.
            visible: !item.groupLabel || String(model.decoration) !== ""

            y: item.showLabel ? (2 * highlightItemSvg.margins.top) : null

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: item.showLabel ? undefined : parent.verticalCenter

            width: iconSize
            height: width

            animated: false
            source: model.decoration

            // Squash on press, springy pop back on release
            scale: pressedScale ? 0.88 : 1.0
            property bool pressedScale: false

            Behavior on scale {
                NumberAnimation {
                    duration: root.hoverEffectDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.5
                }
            }
        }

        PlasmaComponents3.Label {
            id: label

            visible: item.showLabel

            anchors {
                top: iconItem.visible ? iconItem.bottom : undefined
                topMargin: Kirigami.Units.smallSpacing
                verticalCenter: iconItem.visible ? undefined : parent.verticalCenter
                left: parent.left
                leftMargin: highlightItemSvg.margins.left
                right: parent.right
                rightMargin: highlightItemSvg.margins.right
            }

            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 2
            elide: Text.ElideMiddle
            wrapMode: Text.Wrap
            font.pointSize: root.scaledFont(item.groupLabel
                ? Kirigami.Theme.defaultFont.pointSize + 14
                : Kirigami.Theme.defaultFont.pointSize + 0.5, item.labelFontScale)
            font.weight: item.groupLabel ? Font.Bold : Font.Normal

            text: ("name" in model ? model.name : model.display)
            textFormat: Text.PlainText

            // Fade in label smoothly. Group letters are held back a little so
            // they read as signposts rather than competing with the app tiles.
            opacity: item.groupLabel ? item.opacity * 0.85 : item.opacity
        }
    }

    PlasmaCore.ToolTipArea {
        id: toolTip

        property string text: model.display

        anchors.fill: parent

        active: root.visible && (!item.showLabel || label.truncated)
        mainItem: toolTipDelegate
        onContainsMouseChanged: item.GridView.view.itemContainsMouseChanged(containsMouse)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Menu) {
            event.accepted = true;
            rootItem.openAppContextMenu(item, model, 0, 0);
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return
                   || event.key === Qt.Key_Space) {
            event.accepted = true;
            activate();
        }
    }

    Timer {
        id: pressReleaseTimer
        interval: 150
        repeat: false
        onTriggered: iconItem.pressedScale = false
    }
}
