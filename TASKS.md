# Active Tasks

## No active phase

The Arch Linux port (Phases 0-10; decisions in
[ARCH-PORT-DECISIONS.md](docs/ARCH-PORT-DECISIONS.md)) is delivered across
three stacked pull requests: Phases 0-4 (#1), Phases 5-8 (#2), and Phases 9-10.
No merge or release publication is authorized. Replace this file with the next
phase's tasks when one becomes active.

### Known follow-ups

- [ ] Record real-hardware validation on Arch with the rolling-release record
      from `SPEC.md` Section 9.4: NVIDIA, suspend and resume, laptop power,
      radios, audio, and multi-monitor hotplug.
- [ ] Run a `--profile recommended` installation with LightDM in a virtual
      machine with a fresh Arch installation, and validate the `startx` path
      with the manual keyring PAM change.
- [ ] In a real or nested X11 session, verify that Dolphin's "Open With" menu
      lists applications outside Plasma (`XDG_MENU_PREFIX=arch-` and
      `kbuildsycoca6`), that Dolphin follows the `qt6ct` palette, and that
      `quickshell --no-duplicate` stays near idle with the launcher closed.
- [ ] Check current repositories for drift: run the gate against live Arch
      mirrors instead of the pinned archive snapshot, and record the result
      separately from snapshot evidence. No scheduled job does this yet.
