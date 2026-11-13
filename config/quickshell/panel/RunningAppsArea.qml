pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.core

RowLayout {
    id: root

    required property var desktopState
    spacing: Theme.panelGap

    // The tray item of the same app, if any, so the button can offer its menu.
    function trayItemFor(appClass) {
        const items = SystemTray.items.values;

        for (let i = 0; i < items.length; i++) {
            if (Icons.trayItemMatchesApp(items[i], appClass)) {
                return items[i];
            }
        }

        return null;
    }

    Repeater {
        model: root.desktopState.runningApps

        delegate: RunningAppItem {
            required property var modelData
            app: modelData
            active: modelData.appClass === root.desktopState.activeWindowClass
            trayItem: root.trayItemFor(modelData.appClass)
            onFocusRequested: windowId => root.desktopState.focusWindow(windowId)
        }
    }
}
