import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.core

pragma ComponentBehavior: Bound

// The saved notifications, newest first. Clicking an entry takes you to what
// it is about; each entry can be cleared on its own, several can be selected
// and cleared together, or all can be cleared at once.
ColumnLayout {
    id: root

    required property var notificationModel
    property var selectedKeys: []
    readonly property var history: root.notificationModel.history
    readonly property int selectedCount: root.selectedKeys.length
    readonly property real scrollY: entryFlick.contentY
    // Keyboard focus may move to an entry, or a button inside it, that is
    // scrolled out of view; scroll it back in.
    readonly property Item focusedItem: root.Window.activeFocusItem
    onFocusedItemChanged: root.revealFocused()

    // Emitted after an entry was opened, so a popup can close itself.
    signal sourceOpened(string key, string result)

    spacing: Theme.popupSpacing

    // Drop selections whose entries are gone.
    onHistoryChanged: {
        const keys = root.history.map(entry => entry.key);
        const kept = root.selectedKeys.filter(key => keys.indexOf(key) >= 0);
        if (kept.length !== root.selectedKeys.length) root.selectedKeys = kept;
    }

    function isSelected(key) {
        return root.selectedKeys.indexOf(key) >= 0;
    }

    function toggleSelected(key) {
        root.selectedKeys = root.isSelected(key)
            ? root.selectedKeys.filter(selected => selected !== key)
            : root.selectedKeys.concat([key]);
    }

    function selectAll() {
        root.selectedKeys = root.history.map(entry => entry.key);
    }

    function clearSelection() {
        root.selectedKeys = [];
    }

    function clearSelected() {
        const keys = root.selectedKeys.slice();
        root.selectedKeys = [];
        root.notificationModel.removeHistory(keys);
    }

    function clearOne(key) {
        root.notificationModel.removeHistory([key]);
    }

    function clearAll() {
        root.selectedKeys = [];
        root.notificationModel.clearHistory();
    }

    function revealFocused() {
        let item = root.focusedItem;
        while (item && item.parent !== entryColumn) item = item.parent;
        if (!item) return;
        const top = item.y;
        const bottom = item.y + item.height;
        if (top < entryFlick.contentY) entryFlick.contentY = top;
        else if (bottom > entryFlick.contentY + entryFlick.height)
            entryFlick.contentY = Math.min(top, bottom - entryFlick.height);
    }

    // Gives keyboard focus to the entry at index (newest first).
    function focusEntry(index) {
        const item = entryRepeater.itemAt(index);
        if (item) item.forceActiveFocus();
        return item !== null;
    }

    function openEntry(key) {
        root.sourceOpened(key, root.notificationModel.openSource(key));
    }

    function iconFor(entry) {
        const icon = (entry.appIcon || "").toString();
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.startsWith("file://")) return icon;
        return Icons.launcherIcon(icon || entry.desktopEntry || entry.appName || "");
    }

    function timeLabel(timestamp) {
        const date = new Date(timestamp || Date.now());
        const now = new Date();
        return date.toDateString() === now.toDateString()
            ? Qt.formatTime(date, "hh:mm") : Qt.formatDateTime(date, "MMM d, hh:mm");
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.listSpacing * 2

        UiText {
            Layout.fillWidth: true
            text: root.selectedCount > 0 ? root.selectedCount + " selected"
                : root.history.length === 0 ? "No notifications"
                : root.history.length + (root.history.length === 1 ? " notification" : " notifications")
            color: Theme.menuMutedText
            font.pixelSize: Theme.smallFontSize
            elide: Text.ElideRight
        }

        ShellButton {
            objectName: "notificationSelectAll"
            visible: root.history.length > 0
            label: root.selectedCount === root.history.length ? "Select none" : "Select all"
            onActivated: {
                if (root.selectedCount === root.history.length) root.clearSelection();
                else root.selectAll();
            }
        }

        ShellButton {
            objectName: "notificationClearSelected"
            visible: root.selectedCount > 0
            label: "Clear selected"
            onActivated: root.clearSelected()
        }

        ShellButton {
            objectName: "notificationClearAll"
            enabled: root.history.length > 0
            danger: true
            label: "Clear all"
            onActivated: root.clearAll()
        }
    }

    Flickable {
        id: entryFlick

        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: entryColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: entryColumn

            width: parent.width
            spacing: Theme.spacingMd

            Repeater {
                id: entryRepeater

                model: root.history

                delegate: Rectangle {
                    id: entry

                    required property var modelData
                    readonly property string key: entry.modelData.key
                    readonly property bool critical: entry.modelData.urgencyName === "critical"
                    readonly property bool selected: root.isSelected(entry.key)
                    readonly property var liveActions: root.notificationModel.actionable[entry.key]
                        ? root.notificationModel.actionsFor(entry.key) : []

                    Layout.fillWidth: true
                    Layout.preferredHeight: entryContent.implicitHeight + Theme.spacingLg * 2
                    // Keyboard: Tab reaches each entry, Enter opens it, Space
                    // selects it, and Delete clears it.
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: (entry.modelData.appName || "Notification") + ": "
                        + (entry.modelData.summary || "")
                    Accessible.description: "Enter opens, Space selects, Delete clears"
                    Accessible.onPressAction: root.openEntry(entry.key)
                    Keys.onPressed: event => {
                        if (event.isAutoRepeat) return;
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.openEntry(entry.key);
                        else if (event.key === Qt.Key_Space) root.toggleSelected(entry.key);
                        else if (event.key === Qt.Key_Delete) root.clearOne(entry.key);
                        else return;
                        event.accepted = true;
                    }
                    radius: Theme.popupRadius
                    color: entry.selected ? Theme.controlSelectedFill
                        : entryMouse.containsMouse ? Theme.controlHoverFill
                        : entry.critical ? Theme.dangerSurface : Theme.surface
                    border.color: entry.activeFocus ? Theme.controlFocusBorder
                        : entry.selected ? Theme.controlSelectedBorder
                        : entry.critical ? Theme.danger : Theme.popupBorder
                    border.width: entry.activeFocus ? Theme.controlFocusBorderWidth : Theme.controlBorderWidth

                    // Clicking anywhere else on the entry opens its source.
                    MouseArea {
                        id: entryMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openEntry(entry.key)
                    }

                    RowLayout {
                        id: entryContent

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingLg
                        spacing: Theme.spacingLg

                        Rectangle {
                            objectName: "notificationSelect"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: Theme.spacingXxs
                            Layout.preferredWidth: Theme.scaledSize(16)
                            Layout.preferredHeight: Theme.scaledSize(16)
                            radius: Theme.smallRadius
                            color: entry.selected ? Theme.accent : Theme.transparent
                            border.color: entry.selected ? Theme.accent
                                : selectMouse.containsMouse ? Theme.controlHoverBorder : Theme.controlNormalBorder
                            border.width: Theme.controlBorderWidth
                            Accessible.role: Accessible.CheckBox
                            Accessible.name: "Select notification"
                            Accessible.checked: entry.selected

                            UiText {
                                anchors.centerIn: parent
                                visible: entry.selected
                                text: "✓"
                                color: Theme.accentText
                                font.pixelSize: Theme.smallFontSize
                                font.bold: true
                            }

                            MouseArea {
                                id: selectMouse

                                anchors.fill: parent
                                anchors.margins: -Theme.spacingSm
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSelected(entry.key)
                            }
                        }

                        IconImage {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: Theme.scaledSize(28)
                            Layout.preferredHeight: Theme.scaledSize(28)
                            source: root.iconFor(entry.modelData)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.tightSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.listSpacing * 2

                                UiText {
                                    Layout.fillWidth: true
                                    text: entry.modelData.appName || "Notification"
                                    color: entry.critical ? Theme.danger : Theme.menuActionText
                                    font.pixelSize: Theme.fontCaptionSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                UiText {
                                    text: root.timeLabel(entry.modelData.timestamp)
                                    color: Theme.menuMutedText
                                    font.pixelSize: Theme.smallFontSize
                                }
                            }

                            UiText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: entry.modelData.summary || ""
                                color: Theme.popupText
                                font.pixelSize: Theme.bodyFontSize
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            UiText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: entry.modelData.body || ""
                                color: Theme.menuText
                                font.pixelSize: Theme.smallFontSize
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            // Clicking the entry already runs the default
                            // action; the other actions get buttons while the
                            // notification is still open.
                            NotificationActions {
                                Layout.topMargin: Theme.tightSpacing
                                actions: entry.liveActions
                                critical: entry.critical
                                onInvoked: identifier => root.notificationModel.invokeAction(entry.key, identifier)
                            }
                        }

                        Rectangle {
                            objectName: "notificationClearOne"
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: Theme.closeButtonSize - Theme.listSpacing
                            Layout.preferredHeight: Theme.closeButtonSize - Theme.listSpacing
                            radius: Theme.controlRadius
                            color: clearMouse.containsMouse ? Theme.controlHoverFill : Theme.transparent
                            border.color: clearMouse.containsMouse ? Theme.controlHoverBorder : Theme.controlNormalBorder
                            border.width: Theme.controlBorderWidth
                            Accessible.role: Accessible.Button
                            Accessible.name: "Clear notification"

                            UiText {
                                anchors.centerIn: parent
                                text: "x"
                                color: clearMouse.containsMouse ? Theme.controlHoverText : Theme.menuMutedText
                                font.pixelSize: Theme.panelFontSize
                                font.bold: true
                            }

                            MouseArea {
                                id: clearMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearOne(entry.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
