#!/usr/bin/python3
"""Private Settings update fixture; no platform service, pacman, privilege or host journal."""

import os
from pathlib import Path
import signal
import sys

# These fixtures reuse one projection for the fixed bounded snapshot modes.
if sys.argv[1:] in (["snapshot-core"], ["snapshot-without-storage"]):
    sys.argv[1] = "snapshot"


DIRECTORY = Path(os.environ["DWM_UPDATE_UI_FIXTURE"])
GENERATION = "c" * 64


def row(*fields):
    print("\t".join(fields), flush=True)


def mode():
    path = DIRECTORY / "mode"
    return path.read_text() if path.exists() else "quiet"


def snapshot():
    row("system-management-protocol", "1", "0")
    row("snapshot-generation", GENERATION)
    row("provider", "updates", "available", "delegated", "pacman", "Private UI fixture")
    row("provider", "recovery", "available", "user-session", "dwm-system-management", "Private recovery fixture")
    row("state", "update-summary", "available", "1", "One update")
    row("state", "update-last-refresh", "available", "10", "Recent synchronization")
    row("state", "update-restart", "available", "none", "No restart is pending now. Restart after updating: linux")
    available = mode() != "unavailable"
    row("action", "updates-open", "available" if available else "unavailable", "user-session", "updates",
        "Open system update", "Opens the Update Center terminal" if available else "The system is up to date as of this check")
    row("update", "linux;6.18.2.arch1-1;x86_64;core", "unknown", "installable", "linux", "6.18.2.arch1-1", "Kernel")
    for name, action, version in (("linux", "update", "6.18.2.arch1-1"), ("dependency", "install", "1-1"),
                                  ("legacy", "remove", "1-1")):
        row("package-change", f"{name};{version};x86_64;core", action, name, version, "Complete fixture preview")
    row("complete", "snapshot")


def main():
    if tuple(sys.argv[1:]) in (("watch-time",), ("watch-regional", "locale"),
                              ("watch-accounts",), ("watch-units", "printers"), ("watch-units", "security"), ("watch-mounts",)):
        prefix = "time-event" if sys.argv[1] == "watch-time" else "regional-event" if sys.argv[1] == "watch-regional" else (
            "accounts-event" if sys.argv[1] == "watch-accounts" else "units-event")
        if sys.argv[1] == "watch-mounts":
            row("mount-monitor-ready")
        else:
            row(prefix, "ready")
        signal.pause()
        return 0
    command = sys.argv[1]
    if command == "fixture-control" and len(sys.argv) == 3:
        value = sys.argv[2]
        if value == "event":
            with os.fdopen(os.open(DIRECTORY / "events", os.O_WRONLY | os.O_NONBLOCK), "w") as stream:
                stream.write("update-event\tchanged\n")
        elif value in ("quiet", "unavailable", "reject", "monitorfail"):
            (DIRECTORY / "mode").write_text(value)
        else:
            return 2
        return 0
    if command == "watch-updates" and len(sys.argv) == 2:
        if mode() == "monitorfail":
            return 1
        fifo = DIRECTORY / "events"
        if not fifo.exists():
            os.mkfifo(fifo, 0o600)
        with os.fdopen(os.open(fifo, os.O_RDWR), "r") as stream:
            row("update-event", "ready")
            for line in stream:
                print(line, end="", flush=True)
        return 0
    if command == "snapshot" and len(sys.argv) == 2:
        snapshot()
        return 0
    if command != "updates-open" or len(sys.argv) != 2:
        (DIRECTORY / "invalid-arguments").touch()
        return 2
    lock = DIRECTORY / "launching"
    if lock.exists():
        (DIRECTORY / "overlap").touch()
        return 1
    lock.touch()
    try:
        count = DIRECTORY / "origins"
        count.write_text(str(int(count.read_text()) + 1 if count.exists() else 1))
        row("system-management-protocol", "1", "0")
        if mode() == "reject":
            row("error", "updates", "conflict", "The Update Center did not open the system update: fixture rejection")
            row("complete", "update-launch")
            return 1
        row("update-launch", "op-" + count.read_text().strip().rjust(32, "0"), "launched", "unknown")
        row("complete", "update-launch")
        return 0
    finally:
        lock.unlink()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    sys.exit(main())
