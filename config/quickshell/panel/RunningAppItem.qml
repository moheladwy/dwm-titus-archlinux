import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.core

Rectangle {
    id: root

    required property var app
    required property bool active
    // The app's tray item, when it has one; its icon is hidden from the tray
    // while this button is shown, so right-click opens its menu here.
    property var trayItem: null
    signal focusRequested(string windowId)

    Layout.preferredWidth: Theme.pillHeight
    Layout.preferredHeight: Theme.pillHeight
    radius: Theme.pillRadius
    color: active ? Theme.controlSelectedFill
        : appMouse.containsMouse ? Theme.controlHoverFill : Theme.transparent
    border.color: active ? Theme.controlSelectedBorder
        : appMouse.containsMouse ? Theme.controlHoverBorder : Theme.transparent
    border.width: active || appMouse.containsMouse ? Theme.pillBorderWidth : 0

    QsMenuAnchor {
        id: trayMenu

        menu: root.trayItem ? root.trayItem.menu : null
        anchor.item: root
    }

    IconImage {
        anchors.centerIn: parent
        width: Theme.trayIconSize
        height: Theme.trayIconSize
        source: Icons.launcherIcon(root.app.appClass)
    }

    MouseArea {
        id: appMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.trayItem && root.trayItem.hasMenu
            ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                trayMenu.open();
                mouse.accepted = true;
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.focusRequested(root.app.windowId);
            }
        }
    }
}
