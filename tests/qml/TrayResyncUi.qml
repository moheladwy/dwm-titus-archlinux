import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.panel

ShellRoot {
    id: root
    property string last: ""

    FloatingWindow {
        visible: true
        implicitWidth: 200
        implicitHeight: 40
        TrayArea {}
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            const ids = SystemTray.items.values.map(item => item.id).sort().join(",");
            const line = "TRAY_ITEMS " + SystemTray.items.values.length + " " + ids;
            if (line !== root.last) {
                root.last = line;
                console.log(line);
            }
        }
    }
}
