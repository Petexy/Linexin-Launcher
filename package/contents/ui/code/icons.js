/*
    SPDX-FileCopyrightText: 2026 Petexy
    SPDX-License-Identifier: GPL-3.0-or-later
*/

.pragma library

// The panel button's default icon. A copy of it is shipped in contents/icons/,
// so the button keeps this exact look even if the system icon theme renames,
// restyles or drops the icon later on.
var defaultIconName = "windowshuffler-symbolic";

// Turns a configured icon name into something Kirigami.Icon can show, mapping
// the default name onto the bundled file instead of the icon theme's copy.
function resolve(iconName) {
    if (!iconName || iconName === defaultIconName) {
        return Qt.resolvedUrl("../../icons/" + defaultIconName + ".svg");
    }

    return iconName;
}
