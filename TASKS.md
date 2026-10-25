# Active Tasks

## No active phase

The Arch Linux port (plan Phases 0-10,
[arch-linux-port.md](.github/plans/arch-linux-port.md)) is delivered across
three stacked pull requests: Phases 0-4 (#1), Phases 5-8 (#2), and Phases 9-10.
No merge or release publication is authorized. Replace this file with the next
phase's tasks when one becomes active.

### Known follow-ups

- [ ] Stabilize the intermittent nested-X11 Picom test
      (`tests/test-picom-xvfb.py`).
- [ ] Stabilize the intermittent time-reconciliation scenario in
      `tests/test-quickshell-system-management-xvfb.sh`.
- [ ] Record real-hardware validation on Arch with the rolling-release record
      from `SPEC.md` Section 9.4: NVIDIA, suspend and resume, laptop power,
      radios, audio, and multi-monitor hotplug.
- [ ] Run a `--profile recommended` installation with LightDM in a virtual
      machine with a fresh Arch installation, and validate the `startx` path
      with the manual keyring PAM change.
