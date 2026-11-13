import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.core

RowLayout {
    id: root

    // Apps with an open window already have a running-app button, which opens
    // the menu of the app's tray item on right-click, so that one item is
    // hidden until the last window closes (see Icons.trayItemForApp).
    property var runningApps: []

    readonly property var claimedItems: root.runningApps.map(function(app) {
        return Icons.trayItemForApp(SystemTray.items.values, app.appClass);
    })

    readonly property var visibleItems: SystemTray.items.values.filter(function(item) {
        return item.id !== "blueman" && item.id !== "blueman-applet"
            && root.claimedItems.indexOf(item) === -1;
    })
    visible: visibleItems.length > 0
    spacing: Theme.compactSpacing

    // After a restart the tray watcher starts empty, and apps that registered
    // with the previous one stay unlisted. Re-register them once at startup.
    Timer {
        interval: 2000
        running: true
        onTriggered: trayResyncProcess.running = true
    }

    Process {
        id: trayResyncProcess

        command: Commands.trayHelperCommand("resync")
        running: false
    }

    Repeater {
        model: root.visibleItems

        delegate: TrayItem {
            required property var modelData

            trayItem: modelData
        }
    }
}
