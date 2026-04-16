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

    // Track dynamically-created items so we can clean them up
    property var __menuItems: []

    function refreshMenu() {
        // Remove old dynamic items
        for (var i = 0; i < __menuItems.length; i++) {
            __menuItems[i].destroy();
        }
        __menuItems = [];
        menu.clearMenuItems();

        if (!actionList) return;
        fillMenu(menu, actionList);
    }

    function fillMenu(menu, items) {
        items.forEach(function(actionItem) {
            if (actionItem.subActions) {
                var submenuItem = contextSubmenuItemComponent.createObject(
                    menu, { "actionItem": actionItem });
                menu.addMenuItem(submenuItem);
                __menuItems.push(submenuItem);
                fillMenu(submenuItem.submenu, actionItem.subActions);
            } else {
                var item = contextMenuItemComponent.createObject(
                    menu, { "actionItem": actionItem });
                menu.addMenuItem(item);
                __menuItems.push(item);
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
                visualParent: submenuItem.action
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
