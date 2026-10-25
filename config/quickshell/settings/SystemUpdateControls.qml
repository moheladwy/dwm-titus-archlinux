import QtQuick
import QtQuick.Layouts
import qs.core

pragma ComponentBehavior: Bound

// Settings never installs packages in place. The only update action opens the
// Update Center terminal flow, where pacman shows its own prompts (replacements,
// conflicts, provider choices and .pacnew notices) and asks for authorization.
ColumnLayout {
    id: root
    required property var model
    signal revealRequested(var target)
    readonly property string reason: model.updateActionReason("updates-open")
    Layout.fillWidth: true
    spacing: Theme.spacingMd

    component PlainText: UiText {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.fillWidth: true
        ShellButton {
            id: openButton
            objectName: "openSystemUpdate"
            label: root.model.updateLaunching ? "Opening..." : "Open system update"
            enabled: root.reason === ""
            onActivated: root.model.openSystemUpdate()
            onActiveFocusChanged: { if (activeFocus) root.revealRequested(openButton); }
        }
        Item { Layout.fillWidth: true }
    }
    PlainText {
        objectName: "systemUpdateReason"
        visible: text.length > 0
        text: root.reason.length > 0 && !root.model.updateLaunching ? root.reason : ""
        color: Theme.menuMutedText
    }
    PlainText {
        text: "The update runs as one full upgrade (sudo pacman -Syu) in a terminal after an Arch news check. "
            + "The preview below is read-only; pacman may resolve differently and explains any decision in the terminal."
        color: Theme.menuMutedText
    }
    PlainText {
        objectName: "systemUpdateLaunchMessage"
        visible: text.length > 0
        text: root.model.updateLaunchMessage
        color: root.model.updateLaunchFailed ? Theme.danger : Theme.menuText
    }
}
