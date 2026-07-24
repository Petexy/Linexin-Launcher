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

import "code/icons.js" as Icons

Item {
    id: root

    readonly property bool vertical: (Plasmoid.formFactor === PlasmaCore.Types.Vertical)
    readonly property bool useCustomButtonImage: (Plasmoid.configuration.useCustomButtonImage
        && Plasmoid.configuration.customButtonImage.length !== 0)

    property Component dashWindowComponent: null
    property var dashWindow: null

    Component.onCompleted: {
        Qt.callLater(updateSizeHints);

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
    onParentChanged: Qt.callLater(updateSizeHints)
    onUseCustomButtonImageChanged: updateSizeHints()
    onVerticalChanged: updateSizeHints()

    function updateSizeHints() {
        // parent is null while the item is being created or reparented, and
        // onWidthChanged / onHeightChanged / buttonIcon.onSourceChanged can all
        // fire in that window. Reading parent.width/height then throws
        // "Cannot read property 'height' of null" and aborts the sizing
        // half-applied — bail until we're parented into the panel layout.
        if (!parent) {
            return;
        }

        const panelThickness = vertical ? parent.width : parent.height;
        if (panelThickness <= 0 || !isFinite(panelThickness)) {
            return;
        }

        if (useCustomButtonImage) {
            const imageWidth = buttonIcon.implicitWidth;
            const imageHeight = buttonIcon.implicitHeight;
            const validImageSize = imageWidth > 0 && imageHeight > 0
                && isFinite(imageWidth) && isFinite(imageHeight);

            if (vertical) {
                const aspectRatio = validImageSize ? imageHeight / imageWidth : 1;
                const scaledHeight = Math.max(1, Math.floor(panelThickness * aspectRatio));
                root.Layout.minimumWidth = -1;
                root.Layout.minimumHeight = scaledHeight;
                root.Layout.maximumWidth = Kirigami.Units.iconSizes.huge;
                root.Layout.maximumHeight = scaledHeight;
            } else {
                const aspectRatio = validImageSize ? imageWidth / imageHeight : 1;
                const scaledWidth = Math.max(1, Math.floor(panelThickness * aspectRatio));
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
            ? (implicitWidth > 0 ? implicitHeight / implicitWidth : 1)
            : (implicitHeight > 0 ? implicitWidth / implicitHeight : 1)

        active: mouseArea.containsMouse && !justOpenedTimer.running
        source: root.useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Icons.resolve(Plasmoid.configuration.icon)
        roundToIconSize: !root.useCustomButtonImage || aspectRatio === 1

        onSourceChanged: root.updateSizeHints()
        onImplicitWidthChanged: root.updateSizeHints()
        onImplicitHeightChanged: root.updateSizeHints()
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        activeFocusOnTab: true
        hoverEnabled: !root.dashWindow || !root.dashWindow.visible

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Enter:
            case Qt.Key_Return:
            case Qt.Key_Select:
                event.accepted = true;
                Plasmoid.activated();
                break;
            }
        }

        Accessible.name: Plasmoid.title
        Accessible.role: Accessible.Button
        Accessible.onPressAction: Plasmoid.activated()

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
