/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.core as PlasmaCore

PlasmaCore.Dialog {
    id: itemListDialog

    property alias model: itemListView.model
    property alias visualParent: itemListView.visualParent

    flags: Qt.WindowStaysOnTopHint | Qt.Popup

    hideOnWindowDeactivate: true

    location: PlasmaCore.Types.Floating

    mainItem: ItemListView {
        id: itemListView
    }
}
