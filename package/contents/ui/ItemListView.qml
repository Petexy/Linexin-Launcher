/*
    SPDX-FileCopyrightText: 2013-2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15

import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

FocusScope {
    id: itemListView

    property alias model: listView.model
    property alias count: listView.count
    property Item visualParent

    width: Kirigami.Units.gridUnit * 14
    height: listView.contentHeight

    signal itemActivated(int index, string actionId, string argument)

    ActionMenu {
        id: actionMenu
        onActionClicked: {
            visualParent.actionTriggered(actionId, actionArgument);
        }
    }

    ListView {
        id: listView

        anchors.fill: parent
        focus: true
        keyNavigationWraps: true
        boundsBehavior: Flickable.StopAtBounds

        highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: 0

        delegate: ItemListDelegate {}
    }
}
