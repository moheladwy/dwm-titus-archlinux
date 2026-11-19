import QtQuick
import QtQuick.Layouts
import qs.core

pragma ComponentBehavior: Bound

// The notification center, dropped down from the panel bell.
ClickAwayPopup {
    id: root

    required property var notificationModel
    required property var panelWindow

    readonly property int cardWidth: Theme.scaledSize(420)
    readonly property int edgeMargin: Theme.rowSpacing
    readonly property int screenHeight: panelWindow && panelWindow.screen ? panelWindow.screen.height : 0

    visible: panelWindow !== null && panelWindow.screen !== null && notificationModel.panelVisible
    targetWindow: panelWindow
    popupWidth: cardWidth
    popupHeight: Math.max(Theme.scaledSize(220),
        Math.min(Theme.scaledSize(640), root.screenHeight - Theme.panelHeight - edgeMargin * 2))
    popupX: panelWindow ? Math.max(edgeMargin, panelWindow.width - cardWidth - edgeMargin) : edgeMargin
    popupY: Theme.panelHeight
    onDismissed: root.notificationModel.closePanel()

    onVisibleChanged: {
        if (visible) Qt.callLater(function() { card.forceActiveFocus(); });
        else root.notificationModel.closePanel();
    }

    ShellSurface {
        id: card

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.notificationModel.closePanel();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            PanelHero {
                Layout.fillWidth: true
                iconText: root.notificationModel.doNotDisturb ? "󰂛" : "󰂚"
                title: "Notifications"
                subtitle: root.notificationModel.doNotDisturb
                    ? "Do not disturb: popups are hidden" : "Click one to go to it"

                PanelToggleSwitch {
                    objectName: "notificationDoNotDisturb"
                    checked: root.notificationModel.doNotDisturb
                    busy: !root.notificationModel.policyMutationReady
                    accessibleName: "Do not disturb"
                    onToggled: root.notificationModel.setDoNotDisturb(!root.notificationModel.doNotDisturb)
                }
            }

            NotificationCenterList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                notificationModel: root.notificationModel
                onSourceOpened: root.notificationModel.closePanel()
            }
        }
    }
}
