import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

pragma ComponentBehavior: Bound

FloatingWindow {
    id: root

    required property var notificationModel

    title: "dwm notification history"
    visible: notificationModel.historyVisible
    implicitWidth: 560
    implicitHeight: 600
    color: Theme.transparent

    onVisibleChanged: {
        if (visible) Qt.callLater(historySurface.forceActiveFocus);
    }

    ShellSurface {
        id: historySurface

        anchors.fill: parent
        margin: Theme.largeSurfaceMargin
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.notificationModel.closeHistory();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            LargeSurfaceHeader {
                Layout.fillWidth: true
                eyebrow: "Recent desktop activity"
                title: "Notifications"
                subtitle: root.notificationModel.history.length + " saved / newest first"
                status: root.notificationModel.history.length > 0 ? "history" : "empty"
                statusColor: root.notificationModel.history.length > 0 ? Theme.accent : Theme.menuMutedText

                ShellButton {
                    label: "Close"
                    onActivated: root.notificationModel.closeHistory()
                }
            }

            NotificationCenterList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                notificationModel: root.notificationModel
                onSourceOpened: root.notificationModel.closeHistory()
            }
        }
    }
}
