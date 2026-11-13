import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.panel

ShellRoot {
    id: root

    property string last: ""
    // Stands in for DwmState.runningApps: one Lark window and one Zen window.
    property var apps: [
        { "windowId": "0x1", "appClass": "lark" },
        { "windowId": "0x2", "appClass": "zen" }
    ]

    function matches(item, appClass) {
        return Icons.trayItemMatchesApp(item, appClass) ? "yes" : "no";
    }

    Component.onCompleted: {
        // Name matching on its own, with plain objects in place of tray items.
        console.log("MATCH"
            + " lark:" + root.matches({ "id": "lark_status_icon_1" }, "lark")
            + " timedoctor:" + root.matches({ "id": "timedoctor2", "title": "timedoctor2" }, "timedoctor2")
            + " title:" + root.matches({ "id": "tray-icon tray app 4931-1", "title": "handy" }, "handy")
            + " dns:" + root.matches({ "id": "zed" }, "dev.zed.zed")
            + " prefix:" + root.matches({ "id": "zenity" }, "zen")
            + " empty:" + root.matches({ "id": "" }, "")
            + " none:" + root.matches(null, "lark"));
    }

    IpcHandler {
        target: "test"

        function closeWindows(): void {
            root.apps = [];
        }
    }

    FloatingWindow {
        visible: true
        implicitWidth: 300
        implicitHeight: 40

        TrayArea {
            id: tray
            runningApps: root.apps
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            const line = "VISIBLE " + tray.visibleItems.map(item => item.id).sort().join(",");
            if (line !== root.last) {
                root.last = line;
                console.log(line);
            }
        }
    }
}
