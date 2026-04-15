/*
    SPDX-FileCopyrightText: 2013-2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

import "code/tools.js" as Tools

Item {
    id: item

    height: row.height + (2 * Kirigami.Units.smallSpacing)

    property int itemIndex: model.index
    property string favoriteId: model.favoriteId !== undefined ? model.favoriteId : ""
    property url url: model.url !== undefined ? model.url : ""
    property var m: model
    property bool hasActionList: ((model.favoriteId !== null)
        || (("hasActionList" in model) && (model.hasActionList === true)))
    property bool isSeparator: (model.isSeparator === true)

    Accessible.role: Accessible.MenuItem
    Accessible.name: model.display

    function openActionMenu(x, y) {
        var actionList = hasActionList ? model.actionList : [];
        Tools.fillActionMenu(i18n, actionMenu, actionList, ListView.view.model.favoritesModel, model.favoriteId);
        actionMenu.visualParent = item;
        actionMenu.open(x, y);
    }

    function actionTriggered(actionId, actionArgument) {
        var close = (Tools.triggerAction(ListView.view.model, model.index, actionId, actionArgument) === true);
        if (close) {
            root.closeWithAnimation();
        }
    }

    RowLayout {
        id: row

        anchors {
            left: parent.left
            right: parent.right
            leftMargin: Kirigami.Units.smallSpacing * 2
            rightMargin: Kirigami.Units.smallSpacing * 2
            verticalCenter: parent.verticalCenter
        }

        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            source: model.decoration
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: model.display
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onClicked: {
            if ("trigger" in ListView.view.model) {
                ListView.view.model.trigger(index, "", null);
                root.closeWithAnimation();
            }
        }

        onContainsMouseChanged: {
            if (containsMouse) {
                listView.currentIndex = index;
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Menu && hasActionList) {
            event.accepted = true;
            openActionMenu(item);
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            event.accepted = true;
            if ("trigger" in ListView.view.model) {
                ListView.view.model.trigger(index, "", null);
                root.closeWithAnimation();
            }
        }
    }
}
