"""Notification center on a private D-Bus session and X server.

Real notify-send clients talk to the real NotificationModel; the real
NotificationCenterList and NotificationCenterPopup render it. A stand-in
desktop state lists one running window and records focus requests.
"""
import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time

if "--inside" not in sys.argv:
    session = subprocess.Popen(["dbus-run-session", "--", sys.executable,
                                __file__, "--inside"], start_new_session=True)
    try:
        raise SystemExit(session.wait(timeout=240))
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        os.killpg(session.pid, signal.SIGTERM)
        try:
            session.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(session.pid, signal.SIGKILL)
            session.wait()
        raise SystemExit("notification center test timed out")


def terminate_test(*_):
    raise SystemExit("notification center test terminated")


signal.signal(signal.SIGTERM, terminate_test)

SHELL = '''import QtQuick
import Quickshell
import Quickshell.Io
import "notifications" as Notifications
import qs.core
ShellRoot {
    QtObject {
        id: desktop
        property var runningApps: [{ "windowId": "0x42", "appClass": "Fixture-App" }]
        property var focused: []
        function focusWindow(windowId) { desktop.focused = desktop.focused.concat([windowId]); }
    }
    Notifications.NotificationModel { id: model; desktopState: desktop }
    PanelWindow { id: panel; anchors { top: true; left: true; right: true } implicitHeight: 30 }
    Notifications.NotificationCenterPopup { notificationModel: model; panelWindow: panel }
    FloatingWindow {
        title: "notification center list test"
        visible: true
        implicitWidth: 420
        implicitHeight: 520
        Notifications.NotificationCenterList {
            id: list
            anchors.fill: parent
            notificationModel: model
        }
    }
    IpcHandler {
        target: "test"
        function state(): string {
            return JSON.stringify({policy: model.policyState,
                visible: model.notifications.map(n => n.key),
                live: Object.keys(model.actionable),
                history: model.history.map(e => ({key: e.key, summary: e.summary,
                    appName: e.appName, timestamp: e.timestamp})),
                unread: model.unreadCount, selected: list.selectedKeys,
                focused: desktop.focused, panel: model.panelVisible});
        }
        function dnd(enabled: bool): void { model.setDoNotDisturb(enabled); }
        function open(key: string): string { return model.openSource(key); }
        function select(key: string): void { list.toggleSelected(key); }
        function clearSelected(): void { list.clearSelected(); }
        function clearOne(key: string): void { list.clearOne(key); }
        function clearAll(): void { list.clearAll(); }
        function focusEntry(index: int): bool { return list.focusEntry(index); }
        function scrollY(): real { return list.scrollY; }
        function openPanel(): void { model.openPanel(); }
        function closePanel(): void { model.closePanel(); }
        function capture(path: string): void { list.grabToImage(result => result.saveToFile(path)); }
    }
}
'''

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as directory:
    work = Path(directory)
    qml = work / "qml"
    shutil.copytree(repo / "config/quickshell", qml)
    (qml / "shell.qml").write_text(SHELL)
    env = {**os.environ, "HOME": str(work / "home"), "XDG_CONFIG_HOME": str(work / "config"),
           "XDG_DATA_HOME": str(work / "data"), "XDG_CACHE_HOME": str(work / "cache"),
           "XDG_STATE_HOME": str(work / "state"), "XDG_RUNTIME_DIR": str(work / "r"),
           "QT_QPA_PLATFORMTHEME": "", "QT_QUICK_BACKEND": "software"}
    Path(env["XDG_RUNTIME_DIR"]).mkdir(mode=0o700)
    history_path = Path(env["XDG_CACHE_HOME"]) / "dwm-titus/notification-history.json"
    processes = []
    read_fd, write_fd = os.pipe()
    log_path = work / "shell.log"
    log = log_path.open("w")
    try:
        server = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0",
                                   "1024x768x24", "-nolisten", "tcp"],
                                  pass_fds=(write_fd,), stdout=log, stderr=log)
        processes.append(server)
        os.close(write_fd)
        assert select.select([read_fd], [], [], 10)[0], "Xvfb did not report a display"
        env["DISPLAY"] = ":" + os.read(read_fd, 32).decode().strip()
        os.close(read_fd)

        def start_shell():
            shell = subprocess.Popen(["quickshell", "--no-duplicate", "--path", str(qml / "shell.qml")],
                                     env=env, stdout=log, stderr=log)
            processes.append(shell)
            return shell

        def ipc(*args):
            return subprocess.run(["quickshell", "ipc", "--path", str(qml / "shell.qml"),
                                   "call", "test", *args], env=env, capture_output=True,
                                  text=True, timeout=5, check=True).stdout.strip()

        def state():
            return json.loads(ipc("state"))

        def wait_for(predicate, what, seconds=10):
            deadline = time.monotonic() + seconds
            while time.monotonic() < deadline:
                try:
                    if predicate():
                        return
                except (subprocess.CalledProcessError, json.JSONDecodeError):
                    pass
                time.sleep(0.1)
            log.flush()
            raise AssertionError("Timed out: " + what + "\n" + log_path.read_text()[-3000:])

        def notify(*args):
            client = subprocess.Popen(["notify-send", *args], env=env,
                                      stdout=subprocess.PIPE, text=True)
            processes.append(client)
            return client

        def key_of(summary):
            wait_for(lambda: any(e["summary"] == summary for e in state()["history"]),
                     "history entry " + summary)
            return next(e["key"] for e in state()["history"] if e["summary"] == summary)

        shell = start_shell()
        wait_for(lambda: state()["policy"] in ("available", "defaults"), "notification policy")

        # Popups stay out of the way: with Do Not Disturb on, nothing pops up,
        # but notifications with actions stay open for the center.
        ipc("dnd", "true")
        wait_for(lambda: state()["policy"] == "available", "Do Not Disturb saved")
        chat = notify("--app-name=Fixture App", "--action=default=Open", "Chat message")
        chat_key = key_of("Chat message")
        wait_for(lambda: chat_key in state()["live"], "default action kept open")
        assert chat_key not in state()["visible"]
        time.sleep(1)
        assert chat.poll() is None, "A notification with actions was closed with its popup"
        transient = notify("--transient", "--action=default=Open", "Transient offer")
        key_of("Transient offer")
        transient.wait(timeout=5)
        assert not any(e["summary"] == "Transient offer" and e["key"] in state()["live"]
                       for e in state()["history"]), "A transient notification was kept open"
        print("Notifications with actions stay open after their popup; transient ones close PASS")

        # Opening a live entry runs its default action and brings its window up.
        assert ipc("open", chat_key) == "action"
        assert chat.communicate(timeout=5)[0].strip() == "default"
        assert state()["focused"] == ["0x42"]
        assert any(e["key"] == chat_key for e in state()["history"]), "Opening cleared the entry"
        # Once the app has answered, opening the entry only focuses its window.
        wait_for(lambda: chat_key not in state()["live"], "answered notification closed")
        assert ipc("open", chat_key) == "window"
        assert state()["focused"] == ["0x42", "0x42"]
        notify("--app-name=Elsewhere", "No window")
        assert ipc("open", key_of("No window")) == "none"
        print("Opening an entry: default action, window focus, nothing to open PASS")

        # Clearing one live entry dismisses it, so its client stops waiting.
        one = notify("--app-name=Fixture App", "--action=default=Open", "Clear me")
        one_key = key_of("Clear me")
        wait_for(lambda: one_key in state()["live"], "live entry")
        ipc("clearOne", one_key)
        one.wait(timeout=5)
        snapshot = state()
        assert one_key not in snapshot["live"]
        assert not any(e["key"] == one_key for e in snapshot["history"])

        # Clearing a selection removes only the selected entries.
        for name in ("Keep A", "Drop B", "Drop C", "Keep D"):
            notify(name)
            key_of(name)
        drop_b, drop_c = key_of("Drop B"), key_of("Drop C")
        ipc("select", drop_b)
        ipc("select", drop_c)
        ipc("select", drop_c)
        ipc("select", drop_c)
        assert state()["selected"] == [drop_b, drop_c]
        ipc("clearSelected")
        summaries = [e["summary"] for e in state()["history"]]
        assert "Drop B" not in summaries and "Drop C" not in summaries, summaries
        assert "Keep A" in summaries and "Keep D" in summaries, summaries
        assert state()["selected"] == []
        wait_for(lambda: drop_b not in history_path.read_text(), "cleared entries saved")
        print("Clearing one entry and a selection of entries PASS")

        # Unread entries: opening the center marks everything seen, and that
        # survives a restart together with the history.
        assert state()["unread"] == len(state()["history"]) > 0
        ipc("openPanel")
        wait_for(lambda: state()["unread"] == 0 and state()["panel"], "center marks entries seen")
        ipc("closePanel")
        notify("After opening")
        wait_for(lambda: state()["unread"] == 1, "new entry is unread")
        kept = [e["key"] for e in state()["history"]]
        wait_for(lambda: '"After opening"' in history_path.read_text(), "history saved")
        shell.terminate()
        shell.wait(timeout=5)
        shell = start_shell()
        wait_for(lambda: [e["key"] for e in state()["history"]] == kept, "history after restart")
        assert state()["unread"] == 1
        # Saved entries have no live actions; opening one focuses its window.
        notify("--app-name=Fixture App", "Saved fixture")
        saved = key_of("Saved fixture")
        assert ipc("open", saved) == "window"
        print("Unread count and history persist across a restart PASS")

        # Keyboard: Space selects the focused entry, Delete clears it, and
        # Enter opens it.
        window = subprocess.run(["xdotool", "search", "--name", "^notification center list test$"],
                                env=env, capture_output=True, text=True, check=True,
                                timeout=5).stdout.split()[0]
        subprocess.run(["xdotool", "windowfocus", "--sync", window], env=env, check=True, timeout=5)

        def key(name):
            subprocess.run(["xdotool", "key", "--window", window, name], env=env, check=True, timeout=5)

        notify("--app-name=Fixture App", "Keyboard delete")
        notify("--app-name=Fixture App", "Keyboard open")
        open_key = key_of("Keyboard open")
        delete_key = key_of("Keyboard delete")
        assert ipc("focusEntry", "0") == "true"
        key("space")
        wait_for(lambda: state()["selected"] == [open_key], "Space selects the entry")
        key("space")
        wait_for(lambda: state()["selected"] == [], "Space deselects the entry")
        focused_before = len(state()["focused"])
        key("Return")
        wait_for(lambda: len(state()["focused"]) == focused_before + 1, "Enter opens the entry")
        assert ipc("focusEntry", "1") == "true"
        key("Delete")
        wait_for(lambda: not any(e["key"] == delete_key for e in state()["history"]),
                 "Delete clears the entry")
        # Tab past the visible entries scrolls the focused one into view.
        for index in range(12):
            notify("Overflow " + str(index))
            key_of("Overflow " + str(index))
        assert ipc("focusEntry", "0") == "true"
        wait_for(lambda: float(ipc("scrollY")) == 0, "list scrolled to the top")
        for _ in range(len(state()["history"]) - 1):
            key("Tab")
        wait_for(lambda: float(ipc("scrollY")) > 0, "Tab scrolls the focused entry into view")
        assert ipc("focusEntry", "0") == "true"
        wait_for(lambda: float(ipc("scrollY")) == 0, "focusing the first entry scrolls back up")
        print("Keyboard: select, open and clear an entry; focus stays in view PASS")

        # Optional screenshot of the center list for manual review.
        capture = os.environ.get("DWM_NOTIFICATION_CENTER_CAPTURE")
        if capture:
            notify("--app-name=Fixture App", "--action=default=Open", "--action=reply=Reply",
                   "A message with actions", "This one is still open, so its Reply button works.")
            key_of("A message with actions")
            ipc("select", saved)
            time.sleep(0.5)
            ipc("capture", capture)
            wait_for(lambda: Path(capture).exists(), "center screenshot")

        live = notify("--app-name=Fixture App", "--action=default=Open", "Live at clear")
        wait_for(lambda: key_of("Live at clear") in state()["live"], "live entry before clear all")
        ipc("clearAll")
        live.wait(timeout=5)
        assert state()["history"] == [] and state()["live"] == []
        print("Clear all dismisses open notifications and empties the history PASS")
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        log.close()
