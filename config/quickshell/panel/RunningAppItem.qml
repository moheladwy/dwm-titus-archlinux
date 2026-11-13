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
    // while this button is shown, so the button forwards its actions:
    // right-click opens its menu (or activates an item without one) and
    // middle-click sends its secondary activation. Left-click focuses the
    // window, which is what a tray icon's own activation usually does.
    property var trayItem: null
    signal focusRequested(string windowId)

    function trayAction(button) {
        if (!root.trayItem) {
            return;
        }

        if (button === Qt.MiddleButton) {
            root.trayItem.secondaryActivate();
        } else if (root.trayItem.hasMenu) {
            trayMenu.open();
        } else {
            root.trayItem.activate();
        }
    }

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
        acceptedButtons: root.trayItem
            ? Qt.LeftButton | Qt.MiddleButton | Qt.RightButton : Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.trayAction(mouse.button);
                mouse.accepted = true;
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.focusRequested(root.app.windowId);
            } else if (mouse.button === Qt.MiddleButton) {
                root.trayAction(mouse.button);
            }
        }
    }
}
