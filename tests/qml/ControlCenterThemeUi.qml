import QtQuick
import Quickshell
import qs.controlcenter

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0
    readonly property var steps: [
        { "theme": "dracula", "message": "Theme applied: dracula" },
        { "theme": "broken", "message": "Theme change failed: dwm-settings-theme: unsafe theme integration file: /fixture/kitty/active-theme.conf" },
        { "theme": "liar", "message": "Theme change failed: liar" }
    ]

    function check(condition, detail) {
        if (!condition) {
            console.error("Control Center theme UI FAILED: " + detail);
            Qt.quit();
            throw new Error(detail);
        }
    }

    function startStep() {
        model.themeRows = [];
        model.setTheme(root.steps[root.stage].theme);
    }

    ControlCenterModel {
        id: model
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.ticks++;
            root.check(root.ticks < 200, "timed out at stage " + root.stage + " with message: " + model.message);
            if (model.busy || model.themeRows.length === 0) return;
            if (root.stage < root.steps.length) {
                const step = root.steps[root.stage];
                // The reloaded theme list must not replace the change result.
                root.check(model.page === "appearance", "theme change did not return to the theme list");
                root.check(model.message === step.message,
                    step.theme + " reported \"" + model.message + "\" instead of \"" + step.message + "\"");
                root.stage++;
                if (root.stage < root.steps.length) {
                    root.startStep();
                } else {
                    model.themeRows = [];
                    model.openAppearance();
                }
                return;
            }
            root.check(model.message === "3 themes", "reopening the list kept a stale result: " + model.message);
            console.log("Control Center theme UI: PASS");
            Qt.quit();
        }
    }

    Component.onCompleted: root.startStep()
}
