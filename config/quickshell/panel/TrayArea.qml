import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.core

RowLayout {
    id: root

    // Apps with an open window already have a running-app button, which opens
    // the app's tray menu on right-click, so their tray icon is hidden until
    // the last window closes.
    property var runningApps: []

    function hasRunningApp(item) {
        for (let i = 0; i < root.runningApps.length; i++) {
            if (Icons.trayItemMatchesApp(item, root.runningApps[i].appClass)) {
                return true;
            }
        }

        return false;
    }

    readonly property var visibleItems: SystemTray.items.values.filter(function(item) {
        return item.id !== "blueman" && item.id !== "blueman-applet" && !root.hasRunningApp(item);
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
