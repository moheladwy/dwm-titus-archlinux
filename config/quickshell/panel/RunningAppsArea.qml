pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.core

RowLayout {
    id: root

    required property var desktopState
    spacing: Theme.panelGap

    Repeater {
        model: root.desktopState.runningApps

        delegate: RunningAppItem {
            required property var modelData
            app: modelData
            active: modelData.appClass === root.desktopState.activeWindowClass
            // The same item TrayArea hides, so its menu stays reachable here.
            trayItem: Icons.trayItemForApp(SystemTray.items.values, modelData.appClass)
            onFocusRequested: windowId => root.desktopState.focusWindow(windowId)
        }
    }
}
