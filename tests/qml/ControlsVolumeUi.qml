import QtQuick
import Quickshell
import Quickshell.Io
import qs.controls

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0

    function check(condition, detail) {
        if (!condition) {
            console.error("Controls volume UI FAILED: " + detail);
            Qt.quit();
            throw new Error(detail);
        }
    }

    ControlsModel {
        id: model
        visible: true
    }

    Process {
        id: lowerVolume
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.40"]
        running: false
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.ticks++;
            root.check(root.ticks < 300, "timed out at stage " + root.stage + " with " + model.volumeText);
            if (root.stage === 0) {
                // The fixture sink starts boosted to 115%.
                if (model.volumePercent !== 115) return;
                root.check(model.volumeText === "VOL 115%", "native text was " + model.volumeText);
                root.stage = 1;
                lowerVolume.running = true;
            } else if (root.stage === 1) {
                // A change made outside the shell arrives through PipeWire.
                if (model.volumePercent !== 40) return;
                // The text fallback parser keeps boosted values as well.
                model.parseVolume("VOL 130%");
                root.check(model.volumePercent === 130, "fallback parsed " + model.volumePercent);
                model.parseVolume("VOL muted 0%");
                root.check(model.volumePercent === 0 && model.volumeMuted, "fallback mute parsed " + model.volumeText);
                console.log("Controls volume UI: PASS");
                Qt.quit();
            }
        }
    }
}
