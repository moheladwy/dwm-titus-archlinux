import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.settings
import qs.systemmanagement

// Settings opens the Update Center terminal flow; it never installs packages
// in place. This fixture checks the single launch origin and its guards.
ShellRoot {
    id: root
    property int stage: 0
    property int assertions: 0
    property bool done: false
    property bool manual: Quickshell.env("DWM_UPDATE_UI_MANUAL") === "1"

    function check(condition, detail) {
        root.assertions++;
        if (!condition) {
            console.error("Update UI FAILED: " + detail);
            Qt.callLater(function() { Qt.quit(); });
            throw new Error(detail);
        }
    }
    function find(name, parent) {
        if (parent.objectName === name) return parent;
        for (const child of parent.children || []) {
            const found = root.find(name, child);
            if (found !== null) return found;
        }
        return null;
    }
    function click(name) {
        const target = root.find(name, window.contentItem);
        root.check(target !== null && target.enabled && target.visible, "Visible enabled control: " + name);
        target.requestActivation();
    }
    function control(value, next) {
        root.stage = next;
        controlProcess.command = Commands.systemManagementCommand("fixture-control", [value]);
        controlProcess.running = true;
    }
    function ready() { return model.updateActionReason("updates-open") === ""; }

    function advance() {
        if (root.done || controlProcess.running) return;
        if (root.stage === 0 && model.snapshotState === "ready" && !model.busy) {
            root.check(!model.openSystemUpdate() && !model.updateLaunching, "Closed Settings cannot open the system update");
            model.openSettings();
            root.stage = 1;
        } else if (root.stage === 1 && root.ready()) {
            if (root.manual) {
                root.stage = -1;
                console.info("Update UI manual fixture ready");
                return;
            }
            for (const removed of ["prepareRefresh", "prepareInstall", "confirmUpdate", "declineUpdate", "cancelUpdate"])
                root.check(root.find(removed, window.contentItem) === null, "In-place update control is gone: " + removed);
            root.check(model.updateConfirmation === undefined, "The model exposes no package confirmation");
            root.check(model.actions.filter(item => item.owner === "updates").map(item => item.id).join(",") === "updates-open",
                "The provider offers only the terminal-flow update action");
            root.check(model.packageChanges.length === 3 && model.packageChanges[2].action === "remove",
                "The read-only preview keeps dependency additions and removals");
            root.check(model.updateRestart.value === "none" && model.updateRestart.detail.indexOf("linux") >= 0,
                "Restart guidance names restart-relevant pending packages");
            root.check(!model.operation.busy && model.operation.result === null, "Opening Settings starts nothing");
            root.click("openSystemUpdate");
            root.check(model.updateLaunching && !model.openSystemUpdate(), "One launch at a time");
            root.check(root.find("openSystemUpdate", window.contentItem).enabled === false, "The button is disabled while opening");
            root.stage = 2;
        } else if (root.stage === 2 && !model.updateLaunching) {
            root.check(!model.updateLaunchFailed && model.updateLaunchMessage.indexOf("opened in a terminal") >= 0,
                "A confirmed launch reports the terminal, not a package result");
            root.check(root.find("systemUpdateLaunchMessage", window.contentItem).visible, "The launch result is visible");
            root.check(!model.operation.busy && model.operation.result === null, "The journal owner is not involved");
            root.control("reject", 3);
        } else if (root.stage === 3 && root.ready()) {
            root.click("openSystemUpdate");
            root.stage = 4;
        } else if (root.stage === 4 && !model.updateLaunching) {
            root.check(model.updateLaunchFailed
                && model.updateLaunchMessage === "The Update Center did not open the system update: fixture rejection",
                "A rejected launch shows the provider's bounded detail");
            root.control("unavailable", 5);
        } else if (root.stage === 5) {
            model.refresh();
            root.stage = 6;
        } else if (root.stage === 6 && !model.busy && model.actions.length > 0
                && model.actions[0].availability === "unavailable") {
            const reason = model.updateActionReason("updates-open");
            root.check(reason === "The system is up to date as of this check", "An unavailable action explains itself");
            root.check(!root.find("openSystemUpdate", window.contentItem).enabled && !model.openSystemUpdate(),
                "An unavailable action cannot be launched");
            root.check(root.find("systemUpdateReason", window.contentItem).text === reason, "The reason is shown");
            root.control("quiet", 7);
        } else if (root.stage === 7) {
            model.refresh();
            root.stage = 8;
        } else if (root.stage === 8 && root.ready()) {
            model.desktopUpdateBusy = true;
            root.check(!model.openSystemUpdate() && model.updateActionReason("updates-open").indexOf("desktop update") >= 0,
                "An active desktop update blocks the system update");
            model.desktopUpdateBusy = false;
            model.desktopUpdateInterrupted = true;
            root.check(!model.openSystemUpdate(), "An interrupted desktop update blocks the system update");
            model.desktopUpdateInterrupted = false;
            root.click("openSystemUpdate");
            root.stage = 9;
        } else if (root.stage === 9 && !model.updateLaunching) {
            root.check(!model.updateLaunchFailed, "A fresh launch succeeds after the guards clear");
            root.done = true;
            console.info("Update UI native tests: PASS (" + root.assertions + " assertions)");
            Qt.quit();
        }
    }

    SystemManagementModel { id: model }
    Window {
        id: window
        visible: true
        title: "System update launch fixture"
        width: 780
        height: 580
        color: Theme.menuBackground
        SystemSettingsPane { anchors.fill: parent; anchors.margins: 12; systemManagementModel: model; capabilities: [] }
    }
    Process { id: controlProcess; onExited: (code, status) => root.check(code === 0 && status === 0, "Private control succeeded") }
    Timer { interval: 25; repeat: true; running: true; onTriggered: root.advance() }
    Timer {
        interval: 30000
        running: !root.manual
        onTriggered: root.check(false, "Timed out at stage " + root.stage + ": " + model.message
            + " / " + model.updateActionReason("updates-open") + " / discovery=" + model.discovery.phase
            + " / launch=" + model.updateLaunchMessage)
    }
}
