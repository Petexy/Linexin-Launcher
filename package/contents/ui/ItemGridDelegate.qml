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

    // =============================================
    //     STAGGERED ENTRANCE ANIMATION
    // =============================================

    // Start invisible if animated entrance is enabled
    opacity: (animatedEntrance && root.iconEntranceDuration > 0) ? 0 : 1
    scale: (animatedEntrance && root.iconEntranceDuration > 0) ? 0.7 : 1.0

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
            entranceTimer.interval = Math.min(itemIndex * 12, 400);
            entranceTimer.start();
        } else {
            // Reset to hidden state so the next entrance animates properly
            entranceAnim.stop();
            entranceTimer.stop();
            opacity = 0;
            scale = 0.7;
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
            duration: root.iconEntranceDuration * 0.875
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: item
            property: "scale"
            from: 0.7; to: 1.0
            duration: root.iconEntranceDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
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
                easing.type: Easing.OutCubic
            }
        }

        transformOrigin: Item.Center

        Kirigami.Icon {
            id: iconItem

            y: item.showLabel ? (2 * highlightItemSvg.margins.top) : null

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: item.showLabel ? undefined : parent.verticalCenter

            width: iconSize
            height: width

            animated: false
            source: model.decoration

            // Subtle bounce on press
            scale: pressedScale ? 0.88 : 1.0
            property bool pressedScale: false

            Behavior on scale {
                NumberAnimation {
                    duration: root.hoverEffectDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        PlasmaComponents3.Label {
            id: label

            visible: item.showLabel

            anchors {
                top: iconItem.bottom
                topMargin: Kirigami.Units.smallSpacing
                left: parent.left
                leftMargin: highlightItemSvg.margins.left
                right: parent.right
                rightMargin: highlightItemSvg.margins.right
            }

            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 2
            elide: Text.ElideMiddle
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 0.5

            text: ("name" in model ? model.name : model.display)
            textFormat: Text.PlainText

            // Fade in label smoothly
            opacity: item.opacity
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
        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
            event.accepted = true;

            // Press animation
            iconItem.pressedScale = true;
            pressReleaseTimer.start();

            if ("trigger" in GridView.view.model) {
                GridView.view.model.trigger(index, "", null);
                root.closeWithAnimation();
            }

            itemGrid.itemActivated(index, "", null);
        }
    }

    Timer {
        id: pressReleaseTimer
        interval: 150
        repeat: false
        onTriggered: iconItem.pressedScale = false
    }
}
