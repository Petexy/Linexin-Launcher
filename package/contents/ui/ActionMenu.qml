/*
    SPDX-FileCopyrightText: 2013 Aurélien Gâteau <agateau@kde.org>
    SPDX-FileCopyrightText: 2014-2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property Item visualParent
    property var actionList
    property bool opened: menu.status !== PlasmaExtras.Menu.Closed

    signal actionClicked(string actionId, var actionArgument)
    signal closed

    onActionListChanged: refreshMenu();

    onOpenedChanged: {
        if (!opened) {
            closed();
        }
    }

    function open(x, y) {
        if (!actionList) return;
        if (x !== undefined && y !== undefined) {
            menu.open(x, y);
        } else {
            menu.open();
        }
    }

    // Use a persistent static Menu — on Wayland + DashboardWindow,
    // dynamically created PlasmaExtras.Menu objects (via createObject)
    // fail to acquire proper popup/window context and never display.
    PlasmaExtras.Menu {
        id: menu
        visualParent: root.visualParent
    }

    // Track nested menus so refreshes can clear them from the leaves upward.
    // QMenuProxy.clearMenuItems() owns and deletes its MenuItem wrappers, so
    // they must not also be destroyed manually from QML.
    property var __submenus: []

    function clearDynamicItems() {
        // A model can refresh while a menu is open. Close and clear the nested
        // menus first so none of their native QActions retain a dead wrapper.
        for (var menuIndex = __submenus.length - 1; menuIndex >= 0; --menuIndex) {
            var submenu = __submenus[menuIndex];
            if (submenu) {
                submenu.close();
                submenu.clearMenuItems();
            }
        }

        menu.close();
        menu.clearMenuItems();

        __submenus = [];
    }

    function refreshMenu() {
        clearDynamicItems();

        if (!actionList) return;
        fillMenu(menu, actionList);
    }

    function fillMenu(targetMenu, items) {
        items.forEach(function(actionItem) {
            if (actionItem.subActions) {
                var submenuItem = contextSubmenuItemComponent.createObject(
                    targetMenu, { "actionItem": actionItem });
                if (!submenuItem) {
                    return;
                }

                targetMenu.addMenuItem(submenuItem);
                __submenus.push(submenuItem.submenu);
                fillMenu(submenuItem.submenu, actionItem.subActions);
            } else {
                var item = contextMenuItemComponent.createObject(
                    targetMenu, { "actionItem": actionItem });
                if (!item) {
                    return;
                }

                targetMenu.addMenuItem(item);
            }
        });
    }

    Component {
        id: contextSubmenuItemComponent
        PlasmaExtras.MenuItem {
            id: submenuItem
            property var actionItem
            text: actionItem.text ? actionItem.text : ""
            icon: actionItem.icon ? actionItem.icon : null
            property PlasmaExtras.Menu submenu: PlasmaExtras.Menu {
                // A QMenuProxy whose visual parent is a MenuItem's QAction is
                // registered by Plasma as that action's native submenu.
                visualParent: submenuItem.action
                placement: PlasmaExtras.Menu.RightPosedTopAlignedPopup
            }
        }
    }

    Component {
        id: contextMenuItemComponent
        PlasmaExtras.MenuItem {
            property var actionItem
            text: actionItem.text ? actionItem.text : ""
            enabled: actionItem.type !== "title" && ("enabled" in actionItem ? actionItem.enabled : true)
            separator: actionItem.type === "separator"
            section: actionItem.type === "title"
            icon: actionItem.icon ? actionItem.icon : null
            checkable: actionItem.checkable ? actionItem.checkable : false
            checked: actionItem.checked ? actionItem.checked : false
            onClicked: {
                root.actionClicked(actionItem.actionId, actionItem.actionArgument);
            }
        }
    }
}
