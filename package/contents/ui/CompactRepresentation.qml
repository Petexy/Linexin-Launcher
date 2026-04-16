/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

import org.kde.plasma.private.kicker 0.1 as Kicker

Item {
    id: root

    readonly property bool vertical: (Plasmoid.formFactor === PlasmaCore.Types.Vertical)
    readonly property bool useCustomButtonImage: (Plasmoid.configuration.useCustomButtonImage
        && Plasmoid.configuration.customButtonImage.length !== 0)

    property Component dashWindowComponent: null
    property var dashWindow: null

    Component.onCompleted: {
        if (kicker.isDash) {
            dashWindowComponent = Qt.createComponent(Qt.resolvedUrl("./DashboardRepresentation.qml"));
            if (dashWindowComponent.status === Component.Ready) {
                dashWindow = dashWindowComponent.createObject(root, { visualParent: root });
            } else if (dashWindowComponent.status === Component.Error) {
                console.error("Linexin Launcher: Failed to load DashboardRepresentation:", dashWindowComponent.errorString());
            } else {
                dashWindowComponent.statusChanged.connect(function() {
                    if (dashWindowComponent.status === Component.Ready) {
                        dashWindow = dashWindowComponent.createObject(root, { visualParent: root });
                    } else if (dashWindowComponent.status === Component.Error) {
                        console.error("Linexin Launcher: Failed to load DashboardRepresentation:", dashWindowComponent.errorString());
                    }
                });
            }
        }
    }

    onWidthChanged: updateSizeHints()
    onHeightChanged: updateSizeHints()

    function updateSizeHints() {
        if (useCustomButtonImage) {
            if (vertical) {
                const scaledHeight = Math.floor(parent.width * (buttonIcon.implicitHeight / buttonIcon.implicitWidth));
                root.Layout.minimumWidth = -1;
                root.Layout.minimumHeight = scaledHeight;
                root.Layout.maximumWidth = Kirigami.Units.iconSizes.huge;
                root.Layout.maximumHeight = scaledHeight;
            } else {
                const scaledWidth = Math.floor(parent.height * (buttonIcon.implicitWidth / buttonIcon.implicitHeight));
                root.Layout.minimumWidth = scaledWidth;
                root.Layout.minimumHeight = -1;
                root.Layout.maximumWidth = scaledWidth;
                root.Layout.maximumHeight = Kirigami.Units.iconSizes.huge;
            }
        } else {
            if (vertical) {
                root.Layout.minimumWidth = -1;
                root.Layout.minimumHeight = parent.width;
                root.Layout.maximumWidth = -1;
                root.Layout.maximumHeight = parent.width;
            } else {
                root.Layout.minimumWidth = parent.height;
                root.Layout.minimumHeight = -1;
                root.Layout.maximumWidth = parent.height;
                root.Layout.maximumHeight = -1;
            }
        }
    }

    Kirigami.Icon {
        id: buttonIcon

        anchors.fill: parent

        readonly property double aspectRatio: root.vertical
            ? implicitHeight / implicitWidth
            : implicitWidth / implicitHeight

        active: mouseArea.containsMouse && !justOpenedTimer.running
        source: root.useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon
        roundToIconSize: !root.useCustomButtonImage || aspectRatio === 1

        onSourceChanged: root.updateSizeHints()
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        activeFocusOnTab: true
        hoverEnabled: !root.dashWindow || !root.dashWindow.visible

        Keys.onPressed: {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Enter:
            case Qt.Key_Return:
            case Qt.Key_Select:
                Plasmoid.activated();
                break;
            }
        }

        Accessible.name: Plasmoid.title
        Accessible.role: Accessible.Button

        onClicked: {
            if (kicker.isDash && root.dashWindow) {
                root.dashWindow.toggle();
                justOpenedTimer.start();
            } else {
                console.warn("Linexin Launcher: dashWindow is not available");
            }
        }
    }

    Connections {
        target: Plasmoid
        enabled: kicker.isDash && root.dashWindow !== null

        function onActivated() {
            if (root.dashWindow) {
                root.dashWindow.toggle();
                justOpenedTimer.start();
            }
        }
    }
}
