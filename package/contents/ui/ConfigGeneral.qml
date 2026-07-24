/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs

import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami 2.20 as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.plasmoid 2.0
import org.kde.kcmutils as KCM

import "code/icons.js" as Icons

KCM.SimpleKCM {
    id: configGeneral

    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
    property string cfg_customButtonImage: Plasmoid.configuration.customButtonImage

    property int cfg_defaultCategory: Plasmoid.configuration.defaultCategory
    property alias cfg_appNameFormat: appNameFormat.currentIndex
    property alias cfg_alphaSort: alphaSort.checked
    property alias cfg_showRecentApps: showRecentApps.checked
    property alias cfg_showRecentDocs: showRecentDocs.checked
    property bool cfg_showActiveApps: Plasmoid.configuration.showActiveApps
    property bool cfg_showAllAppsInDashboard: Plasmoid.configuration.showAllAppsInDashboard

    property alias cfg_appsIconSize: appsIconSize.currentIndex
    property alias cfg_favsIconSize: favsIconSize.currentIndex
    property alias cfg_systemIconSize: systemIconSize.currentIndex

    property alias cfg_categoryFontSize: categoryFontSlider.value
    property alias cfg_dashboardFontSize: dashboardFontSlider.value
    property alias cfg_allAppsFontSize: allAppsFontSlider.value
    property alias cfg_recentAppsFontSize: recentAppsFontSlider.value
    property alias cfg_recentFilesFontSize: recentFilesFontSlider.value

    property alias cfg_animationDuration: animDurationSlider.value
    property alias cfg_iconEntranceDuration: iconEntranceSlider.value
    property alias cfg_hoverEffectDuration: hoverEffectSlider.value
    property alias cfg_folderPopupDuration: folderPopupSlider.value
    property alias cfg_appLaunchDuration: appLaunchSlider.value
    property alias cfg_dragMoveDuration: dragMoveSlider.value
    property alias cfg_folderCreateDuration: folderCreateSlider.value
    property alias cfg_folderAddDuration: folderAddSlider.value
    property alias cfg_folderRemoveDuration: folderRemoveSlider.value
    property alias cfg_backgroundOpacity: bgOpacitySlider.value
    property alias cfg_useCustomBackgroundColor: useCustomBgColor.checked
    property string cfg_backgroundColor: Plasmoid.configuration.backgroundColor

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

                function localPathForUrl(url) {
                    const urlString = url.toString();
                    if (urlString.indexOf("file:///") !== 0) {
                        return "";
                    }

                    try {
                        return decodeURIComponent(urlString.substring("file://".length));
                    } catch (error) {
                        console.warn("Linexin Launcher: Could not decode dropped image URL:", error);
                        return "";
                    }
                }

                onDragEnter: {
                    const localPath = localPathForUrl(event.mimeData.url);
                    const lowerPath = localPath.toLowerCase();
                    const extensions = [".png", ".xpm", ".svg", ".svgz"];
                    containsAcceptableDrag = localPath.length > 0 && extensions.some(function(extension) {
                        return lowerPath.indexOf(extension) === lowerPath.length - extension.length;
                    });
                    if (!containsAcceptableDrag) {
                        event.ignore();
                    }
                }
                onDragLeave: containsAcceptableDrag = false

                onDrop: {
                    if (containsAcceptableDrag) {
                        const localPath = localPathForUrl(event.mimeData.url);
                        if (localPath.length > 0) {
                            iconDialog.setCustomButtonImage(localPath);
                        }
                    }
                    containsAcceptableDrag = false;
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog

                function setCustomButtonImage(image) {
                    configGeneral.cfg_customButtonImage = image || configGeneral.cfg_icon || Icons.defaultIconName;
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
                    source: configGeneral.cfg_useCustomButtonImage ? configGeneral.cfg_customButtonImage : Icons.resolve(configGeneral.cfg_icon)
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
                        configGeneral.cfg_icon = Icons.defaultIconName;
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
            model: [i18n("Dashboard"), i18n("All Apps"), i18n("Recent Apps"), i18n("Recent Files")]
            currentIndex: {
                switch (cfg_defaultCategory) {
                case -2:
                    return 0;
                case -1:
                    return 1;
                case -4:
                case 1: // Compatibility with the old root-model-row value.
                    return 3;
                case -3:
                case 0: // Compatibility with the old root-model-row value.
                    return 2;
                default:
                    return 0;
                }
            }
            onActivated: function(index) {
                const categoryValues = [-2, -1, -3, -4];
                cfg_defaultCategory = categoryValues[index];
            }
        }

        ComboBox {
            id: appNameFormat
            Kirigami.FormData.label: i18n("Application names:")
            model: [
                i18n("Name"),
                i18n("Description"),
                i18n("Name (Description)"),
                i18n("Description (Name)")
            ]
        }

        CheckBox {
            id: alphaSort
            Kirigami.FormData.label: i18n("Application sorting:")
            text: i18n("Sort applications alphabetically")
        }

        CheckBox {
            id: showRecentApps
            Kirigami.FormData.label: i18n("Recent categories:")
            text: i18n("Show Recent Apps")
        }

        CheckBox {
            id: showRecentDocs
            text: i18n("Show Recent Files")
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
            Kirigami.FormData.label: i18n("Font size")
        }

        // ---- Font sizes ----

        RowLayout {
            Kirigami.FormData.label: i18n("Category bar:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: categoryFontSlider
                from: 50
                to: 200
                stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: categoryFontSlider.value + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Dashboard:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: dashboardFontSlider
                from: 50
                to: 200
                stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: dashboardFontSlider.value + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("All apps:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: allAppsFontSlider
                from: 50
                to: 200
                stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: allAppsFontSlider.value + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Recent apps:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: recentAppsFontSlider
                from: 50
                to: 200
                stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: recentAppsFontSlider.value + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Recent files:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: recentFilesFontSlider
                from: 50
                to: 200
                stepSize: 5
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: recentFilesFontSlider.value + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Animation duration")
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
            Kirigami.FormData.label: i18n("App launch:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: appLaunchSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: appLaunchSlider.value === 0 ? i18n("Off") : appLaunchSlider.value + " ms"
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
            Kirigami.FormData.label: i18n("Move icons:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: dragMoveSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: dragMoveSlider.value === 0 ? i18n("Off") : dragMoveSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Create folder:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: folderCreateSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: folderCreateSlider.value === 0 ? i18n("Off") : folderCreateSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Add to folder:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: folderAddSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: folderAddSlider.value === 0 ? i18n("Off") : folderAddSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Remove from folder:")
            spacing: Kirigami.Units.smallSpacing

            Slider {
                id: folderRemoveSlider
                from: 0
                to: 1500
                stepSize: 50
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }

            Label {
                text: folderRemoveSlider.value === 0 ? i18n("Off") : folderRemoveSlider.value + " ms"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Background")
        }

        // ---- Background ----

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

        CheckBox {
            id: useCustomBgColor
            Kirigami.FormData.label: i18n("Background color:")
            text: i18n("Use a custom color")
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            enabled: useCustomBgColor.checked

            Button {
                implicitWidth: Kirigami.Units.gridUnit * 4
                onClicked: {
                    // Seed on open rather than binding: the dialog writes back to
                    // selectedColor while the user picks, which would break a binding.
                    bgColorDialog.selectedColor = configGeneral.cfg_backgroundColor;
                    bgColorDialog.open();
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.smallSpacing * 2
                    height: parent.height - Kirigami.Units.smallSpacing * 2
                    radius: 4
                    color: configGeneral.cfg_backgroundColor
                    border.width: 1
                    border.color: Kirigami.Theme.textColor
                    opacity: parent.enabled ? 1.0 : 0.5
                }
            }

            Label {
                text: configGeneral.cfg_backgroundColor
                Layout.minimumWidth: Kirigami.Units.gridUnit * 5
            }
        }

        ColorDialog {
            id: bgColorDialog
            title: i18n("Choose Background Color")
            onAccepted: configGeneral.cfg_backgroundColor = selectedColor.toString()
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
                cfg_icon = Icons.defaultIconName;
                cfg_useCustomButtonImage = false;
                cfg_customButtonImage = "";
                cfg_defaultCategory = -3;
                appNameFormat.currentIndex = 0;
                alphaSort.checked = false;
                showRecentApps.checked = true;
                showRecentDocs.checked = true;
                cfg_showAllAppsInDashboard = false;
                showAllAppsInDashboard.checked = false;
                cfg_showActiveApps = true;
                showActiveApps.checked = true;
                appsIconSize.currentIndex = 3;
                favsIconSize.currentIndex = 2;
                systemIconSize.currentIndex = 1;
                categoryFontSlider.value = 100;
                dashboardFontSlider.value = 100;
                allAppsFontSlider.value = 100;
                recentAppsFontSlider.value = 100;
                recentFilesFontSlider.value = 100;
                animDurationSlider.value = 350;
                iconEntranceSlider.value = 350;
                hoverEffectSlider.value = 150;
                folderPopupSlider.value = 250;
                appLaunchSlider.value = 150;
                dragMoveSlider.value = 280;
                folderCreateSlider.value = 500;
                folderAddSlider.value = 420;
                folderRemoveSlider.value = 420;
                bgOpacitySlider.value = 55;
                useCustomBgColor.checked = false;
                cfg_backgroundColor = "#000000";
                useExtraRunners.checked = true;
            }
        }
    }
}
