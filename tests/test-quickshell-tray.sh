#!/bin/sh
set -eu

repo=$(
	unset CDPATH
	cd -- "$(dirname -- "$0")/.." && pwd
)

panel=$repo/config/quickshell/panel/DwmPanel.qml
tray_area=$repo/config/quickshell/panel/TrayArea.qml
tray_item=$repo/config/quickshell/panel/TrayItem.qml
running_area=$repo/config/quickshell/panel/RunningAppsArea.qml
running_item=$repo/config/quickshell/panel/RunningAppItem.qml
shell=$repo/config/quickshell/shell.qml

grep -Fq 'required property bool primaryPanel' "$panel"
grep -Fq 'active: root.primaryPanel' "$panel"
grep -Fq 'sourceComponent: TrayArea { runningApps: root.state.runningApps }' "$panel"
grep -Fq 'primaryPanel: modelData === Quickshell.screens[0]' "$shell"
grep -Fq 'model: root.visibleItems' "$tray_area"
grep -Fq 'trayItem: modelData' "$tray_area"
grep -Fq 'property var iconSources: Icons.trayIconSources(root.trayItem)' "$tray_item"
grep -Fq 'status === Image.Error' "$tray_item"
grep -Fq 'root.iconSourceIndex += 1;' "$tray_item"
grep -Fq 'visible: !trayIcon.visible' "$tray_item"
grep -Fq 'Qt.LeftButton | Qt.MiddleButton | Qt.RightButton' "$tray_item"
grep -Fq 'import Quickshell.Services.SystemTray' "$shell"
grep -Fq 'target: "tray"' "$shell"
grep -Fq 'return SystemTray.items.values.length;' "$shell"
grep -Fq 'item.status === undefined || item.status === null ? "" : item.status' "$shell"

# The tray stays independent: it hides only items whose app has a running-app
# button (which then offers the tray menu), so tray-only apps stay visible.
# tests/test-quickshell-tray-dedupe-xvfb.sh checks the behavior.
grep -Fq 'root.claimedItems.indexOf(item) === -1' "$tray_area"
grep -Fq 'return Icons.trayItemForApp(SystemTray.items.values, app.appClass);' "$tray_area"
grep -Fq 'trayItem: Icons.trayItemForApp(SystemTray.items.values, modelData.appClass)' "$running_area"
grep -Fq 'menu: root.trayItem ? root.trayItem.menu : null' "$running_item"
if grep -Fq 'Repeater' "$running_item" || grep -Fq 'SystemTray.items' "$running_item"; then
	printf 'Running-window buttons must not render tray items themselves.\n' >&2
	exit 1
fi

printf 'Quickshell system tray: PASS\n'
