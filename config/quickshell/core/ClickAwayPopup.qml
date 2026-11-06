import QtQuick
import Quickshell
import qs.core

PopupWindow {
    id: root

    default property alias popupContent: popupHost.data
    required property var targetWindow
    property int popupX: 0
    property int popupY: Theme.panelHeight
    property int popupWidth: 320
    property int popupHeight: 320

    signal dismissed

    // On X11 a popup is override-redirect, so it never gets the keyboard on
    // its own. Ask for activation: dwm focuses panel popups on that request,
    // so Escape and keyboard navigation reach the popup, and it hands focus
    // back to the selected client when the popup closes.
    function takeKeyboardFocus() {
        const backing = root._backingWindow;
        if (root.visible && root.grabFocus && backing) backing.requestActivate();
    }

    onVisibleChanged: if (visible) Qt.callLater(root.takeKeyboardFocus)

    color: Theme.transparent
    grabFocus: true
    implicitWidth: targetWindow ? targetWindow.width : 0
    // Keep the transparent click-away surface below the panel so compositors
    // cannot blur the bar through this popup. Content coordinates stay panel-relative.
    readonly property int panelOffset: targetWindow ? targetWindow.height : 0
    implicitHeight: targetWindow && targetWindow.screen ? Math.max(0, targetWindow.screen.height - panelOffset) : 0

    anchor {
        window: targetWindow
        rect.x: 0
        rect.y: root.panelOffset
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Flickable {
        id: viewport
        objectName: "popupViewport"

        x: Math.max(0, Math.min(root.popupX, root.width - width))
        y: Math.max(0, Math.min(root.popupY - root.panelOffset, root.height - height))
        width: Math.min(root.popupWidth, root.width)
        height: Math.min(root.popupHeight, root.height)
        contentWidth: root.popupWidth
        contentHeight: root.popupHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickIfNeeded
        z: 1
        onVisibleChanged: if (visible) { contentX = 0; contentY = 0; }

        Item {
            id: popupHost

            width: root.popupWidth
            height: root.popupHeight
            opacity: 1.0

            MouseArea {
                anchors.fill: parent
            }
        }
    }
}
