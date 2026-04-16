/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami 2.20 as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configGeneral

    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
    property string cfg_customButtonImage: Plasmoid.configuration.customButtonImage

    property int cfg_defaultCategory: Plasmoid.configuration.defaultCategory
    property bool cfg_showActiveApps: Plasmoid.configuration.showActiveApps
    property bool cfg_showAllAppsInDashboard: Plasmoid.configuration.showAllAppsInDashboard

    property alias cfg_appsIconSize: appsIconSize.currentIndex
    property alias cfg_favsIconSize: favsIconSize.currentIndex
    property alias cfg_systemIconSize: systemIconSize.currentIndex

    property alias cfg_animationDuration: animDurationSlider.value
    property alias cfg_iconEntranceDuration: iconEntranceSlider.value
    property alias cfg_hoverEffectDuration: hoverEffectSlider.value
    property alias cfg_folderPopupDuration: folderPopupSlider.value
    property alias cfg_backgroundOpacity: bgOpacitySlider.value

    property alias cfg_useExtraRunners: useExtraRunners.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        // ---- Icon ----

        Button {
            id: iconButton

            Kirigami.FormData.label: i18n("Panel icon:")

            implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
            implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2

            checkable: true
            checked: dropArea.containsAcceptableDrag

            onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

            DragDrop.DropArea {
                id: dropArea

                property bool containsAcceptableDrag: false

                anchors.fill: parent

                onDragEnter: {
                    var urlString = event.mimeData.url.toString();
                    var extensions = [".png", ".xpm", ".svg", ".svgz"];
                    containsAcceptableDrag = urlString.indexOf("file:///") === 0 && extensions.some(function(extension) {
                        return urlString.indexOf(extension) === urlString.length - extension.length;
                    });
                    if (!containsAcceptableDrag) {
                        event.ignore();
                    }
                }
                onDragLeave: containsAcceptableDrag = false

                onDrop: {
                    if (containsAcceptableDrag) {
                        iconDialog.setCustomButtonImage(event.mimeData.url.toString().substr("file://".length));
                    }
                    containsAcceptableDrag = false;
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog

                function setCustomButtonImage(image) {
                    configGeneral.cfg_customButtonImage = image || configGeneral.cfg_icon || "start-here-kde-symbolic";
                    configGeneral.cfg_useCustomButtonImage = true;
                }

                onIconNameChanged: setCustomButtonImage(iconName);
            }

            KSvg.FrameSvgItem {
                id: previewFrame
                anchors.centerIn: parent
                imagePath: Plasmoid.location === PlasmaCore.Types.Vertical || Plasmoid.location === PlasmaCore.Types.Horizontal
                    ? "widgets/panel-background" : "widgets/background"
                width: Kirigami.Units.iconSizes.large + fixedMargins.left + fixedMargins.right
                height: Kirigami.Units.iconSizes.large + fixedMargins.top + fixedMargins.bottom

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.large
                    height: width
                    source: configGeneral.cfg_useCustomButtonImage ? configGeneral.cfg_customButtonImage : configGeneral.cfg_icon
                }
            }

            Menu {
                id: iconMenu
                y: +parent.height
                onClosed: iconButton.checked = false;

                MenuItem {
                    text: i18nc("@item:inmenu Open icon chooser dialog", "Choose…")
                    icon.name: "document-open-folder"
                    onClicked: iconDialog.open()
                }
                MenuItem {
                    text: i18nc("@item:inmenu Reset icon to default", "Clear Icon")
                    icon.name: "edit-clear"
                    onClicked: {
                        configGeneral.cfg_icon = "start-here-kde-symbolic";
                        configGeneral.cfg_useCustomButtonImage = false;
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        // ---- Behavior ----

        ComboBox {
            id: defaultCategory
            Kirigami.FormData.label: i18n("Starting category:")
            model: {
                var items = [i18n("Dashboard"), i18n("All Apps"), i18n("Recent Apps")];
                return items;
            }
            currentIndex: {
                if (cfg_defaultCategory === -2) return 0;
                if (cfg_defaultCategory === -1) return 1;
                return cfg_defaultCategory + 2;
            }
            onActivated: function(index) {
                if (index === 0) cfg_defaultCategory = -2;
                else if (index === 1) cfg_defaultCategory = -1;
                else cfg_defaultCategory = index - 2;
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        // ---- Icon Sizes ----

        ComboBox {
            id: appsIconSize
            Kirigami.FormData.label: i18n("Apps icon size:")
            model: [i18n("Small"), i18n("Medium"), i18n("Large"), i18n("Huge"), i18n("Very Large"), i18n("Enormous")]
        }

        CheckBox {
            id: showAllAppsInDashboard
            Kirigami.FormData.label: i18n("Dashboard:")
            text: i18n("Show all applications instead of only pinned")
            checked: cfg_showAllAppsInDashboard
            onCheckedChanged: cfg_showAllAppsInDashboard = checked
        }

        CheckBox {
            id: showActiveApps
            Kirigami.FormData.label: i18n("Active apps dock:")
            text: i18n("Show active apps dock")
            checked: cfg_showActiveApps
            onCheckedChanged: cfg_showActiveApps = checked
        }

        ComboBox {
            id: favsIconSize
            Kirigami.FormData.label: i18n("Active apps icon size:")
            model: [i18n("Small"), i18n("Medium"), i18n("Large"), i18n("Huge"), i18n("Enormous")]
            enabled: cfg_showActiveApps
        }

        ComboBox {
            id: systemIconSize
            Kirigami.FormData.label: i18n("System actions icon size:")
            model: [i18n("Small"), i18n("Medium"), i18n("Large"), i18n("Huge"), i18n("Enormous")]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        // ---- Animations ----

        RowLayout {
            Kirigami.FormData.label: i18n("Open/Close:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: animDurationSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: animDurationSlider.value === 0 ? i18n("Off") : animDurationSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Icon entrance:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: iconEntranceSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: iconEntranceSlider.value === 0 ? i18n("Off") : iconEntranceSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Hover effects:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: hoverEffectSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: hoverEffectSlider.value === 0 ? i18n("Off") : hoverEffectSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Folder popup:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: folderPopupSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: folderPopupSlider.value === 0 ? i18n("Off") : folderPopupSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: bgOpacitySlider
                from: 10
                to: 95
                stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: bgOpacitySlider.value + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        // ---- Search ----

        CheckBox {
            id: useExtraRunners
            Kirigami.FormData.label: i18n("Search:")
            text: i18n("Expand search to bookmarks, files, and emails")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        Button {
            icon.name: "edit-undo"
            text: i18n("Restore Defaults")
            onClicked: {
                cfg_icon = "start-here-kde-symbolic";
                cfg_useCustomButtonImage = false;
                cfg_customButtonImage = "";
                cfg_defaultCategory = 0;
                cfg_showAllAppsInDashboard = false;
                showAllAppsInDashboard.checked = false;
                cfg_showActiveApps = true;
                showActiveApps.checked = true;
                appsIconSize.currentIndex = 3;
                favsIconSize.currentIndex = 2;
                systemIconSize.currentIndex = 1;
                animDurationSlider.value = 350;
                iconEntranceSlider.value = 400;
                hoverEffectSlider.value = 150;
                folderPopupSlider.value = 250;
                bgOpacitySlider.value = 40;
                useExtraRunners.checked = true;
            }
        }
    }
}
