# Settings Platform Contract

<!-- markdownlint-disable MD013 -->

This document defines the architecture, safety, packaging, and validation
contracts for the unified Settings application, including the Phase 2 display
and input providers. `SPEC.md` remains the product contract, and
`docs/SETTINGS-CAPABILITIES.md` records the provider inventory.

Phase 6 system-management provider, ownership, audit, cancellation, and
delegation decisions are defined in `P6-SYSTEM-MANAGEMENT.md`. That
contract does not widen the project-owned privileged helper allowlist.

## Application Contract

The Settings application is one Quickshell `FloatingWindow` titled
`dwm settings`. It is part of the managed Quickshell process and is opened from
Control Center -> Settings, through the `settings` IPC target, or
with `dwm-settings`. It fills the selected monitor like System Health. Appearance
scrolls vertically without overscroll bounce. Cursor choices are published through
XSETTINGS and replace named cursors held by existing X11 clients immediately;
applications drawing their own custom pointer images retain those images.

The managed panel hides Blueman's redundant tray item while keeping the Bluetooth
widget and other tray applications available. Installation preserves user-owned
dwm configuration files and replaces the managed Quickshell directory.

Control Center -> Quick Actions -> Self-Heal runs the workstation's self-heal
script in a terminal, where its progress, results, and any authorization prompts
remain visible. Install an executable `dwm-self-heal` on PATH, or put the absolute
path of the existing script in
`${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/self-heal.path` (one path, no shell
arguments). `DWM_SELF_HEAL_SCRIPT` can override that path for the shell session.
The action reports an unavailable script without changing the system; it does
not download a script or elevate the Quickshell process.

### Navigation and Search

- The left navigation contains Displays, Input, Network, Bluetooth, Audio,
  Power, Defaults, Appearance, and System in stable roadmap order.
- Typing in the search field filters section names and descriptions. When the
  first match changes, Settings transitions the section-owned read/watch
  providers; search never mutates desktop state.
- Up and Down move between visible sections, Enter selects the highlighted
  section, Escape closes Settings, and clicking a section selects it.
- Opening Settings resets navigation to Displays and starts one bounded
  discovery snapshot. Refresh starts a new snapshot only when no snapshot is
  already active.
- Closing Settings stops the discovery process, clears transient search state,
  and leaves persistent panel providers untouched.

Phase 1 is intentionally read-only. Capability cards report the operation
class, provider, state, and recovery detail. Unsupported and restricted cards
stay visible when their explanation helps the user; a missing provider never
prevents another section from opening.

Autostart overrides keep `OnlyShowIn` and `NotShowIn` mutually exclusive.
When a vendor entry has `OnlyShowIn`, installation removes only the `X-DWM`
and `dwm` tokens instead of adding `NotShowIn`; other desktop choices remain
intact. Existing user overrides are preserved and require an explicit repair
if an older installation produced conflicting keys.

System updates in Settings > System are read-only discovery plus one launch
action, following the pacman contract in `SPEC.md` Sections 5.10 and 5.11:

- Discovery runs unprivileged through pyalpm in a private temporary database
  directory. Its `local` entry is a symlink to the real local database, and
  its sync databases are seeded from the system copies and a per-user cache in
  `${XDG_CACHE_HOME:-$HOME/.cache}/dwm-titus/pacman-sync`, with a remote check
  at most every 300 seconds. It never writes `/var/lib/pacman/sync` or touches
  `db.lck`. When the remote check fails, cached data is shown with a network
  warning.
- Packages held by `IgnorePkg` or `IgnoreGroup` are listed as blocked.
- The dependency preview is a pyalpm `sysupgrade` transaction that is always
  released. It is a preview only: pyalpm 0.12 does not ask replacement
  questions, so pacman's own prompts in the terminal decide replacements and
  conflicts.
- Restart guidance reports `system` when `/usr/lib/modules/$(uname -r)` is
  missing, `unknown` when that cannot be checked, and otherwise `none`.
  Pending kernel, `*-ucode`, `systemd`, `glibc`, and `nvidia*` changes are
  flagged "Restart after this change."
- Change events come from inotify watches on `/var/lib/pacman`, `local/`, and
  `sync/`. They are held until `db.lck` is gone, debounced, and re-checked
  hourly. No pacman hook or system file is installed.
- When the `packagekit` package is installed, a row warns that its clients can
  run `pacman -Sy` behind the user's back.
- **Open system update** (`updates-open`) runs `dwm-update-center launch
  system`, which opens the Update Center terminal: the Arch news check, then an
  interactive `sudo -- /usr/bin/pacman -Syu`. Settings never installs,
  refreshes, or cancels package operations in place; the former refresh,
  install-all, and cancel actions are removed, and there is no standalone
  database refresh. Progress, prompts, and recovery belong to that terminal
  (see `docs/DESKTOP-UPDATES.md`). Opening Settings does not install updates.

## Helper Protocol

The Phase 1 capability snapshot invokes only `dwm-settings-provider discover`
through the fixed `Commands.settingsProviderCommand()` wrapper. Phase 2 uses
equally fixed display actions (`discover`, `watch`, `save`, `preview`,
`preview-profile`, `keep`, `revert`, `install-profile`, and `rollback-system`)
plus the read-only `preview-status` recovery query,
and equally fixed input actions (`discover`, `watch`, `watch-apply`, `preview`,
`keep`, `revert`, `preview-status`, `reset`, and `apply-saved`). QML cannot
supply command strings, executables, arbitrary
paths, or elevation flags; every argument is validated by the owning helper.

The version 1 output is UTF-8, tab-separated, and line-oriented:

```text
settings-protocol<TAB>1
platform<TAB>id<TAB>family<TAB>display-name
capability<TAB>section<TAB>id<TAB>label<TAB>status<TAB>class<TAB>provider<TAB>detail
```

Fields are single-line values with tabs and line breaks replaced by spaces.
Unknown record types may be ignored. A missing or unsupported protocol record
is a provider failure, not an empty capability set.

Capability statuses are:

| Status | Meaning |
| --- | --- |
| `available` | The provider needed for the reported read path is present. |
| `partial` | Some state is readable, but the complete section contract is not available. |
| `unavailable` | A normally supported provider is missing or not usable. |
| `restricted` | Readable state remains available, but an authorization path is absent. |
| `unsupported` | The capability has no supported provider contract on this platform. |

Capability classes are `read-only`, `user-session`, `privileged`, and
`delegated`. The broader inventory also treats an operation with no provider as
unsupported; protocol records express that through the `unsupported` status.

The protocol is append-only within version 1. Changing field order, meaning,
or escaping requires a new protocol version and a compatibility test.

## UI and Operation States

All future section implementations use these states. Phase 1 exercises
`loading`, `unavailable`, `failure`, and unsupported state through discovery
and tests. Existing health tests cover restricted authorization while existing
display tests cover preview rollback. Mutation-specific Settings states become
active when the owning roadmap phase adds mutations.

| State | Required behavior |
| --- | --- |
| `loading` | Keep navigation usable, show progress, and prevent overlapping provider launches. |
| `unavailable` | Identify the missing provider or service and give the next action. |
| `permission-denied` | Preserve readable state, clear pending authorization, and allow retry. |
| `failure` | Attribute the error to one provider and leave other sections usable. |
| `dirty` | Show unapplied user changes and require Apply, Reset, or explicit navigation handling. |
| `saved` | Confirm the durable target and the successfully persisted value. |
| `preview` | Show the deadline, previous state, and explicit Keep/Revert actions. |
| `rollback` | Restore captured state automatically on timeout, rejection, close, or provider failure. |

Closing a section must stop watches and child processes that exist only for
that section. Shared event sources required by the persistent panel, such as
the existing NetworkManager and MPRIS streams, remain owned by their shared
models and must not be duplicated by Settings.

## Authorization and Safety Contract

Phase 1 Settings exposes no mutation or elevated operation. Future providers
must follow this boundary:

| Operation class | Allowed execution path |
| --- | --- |
| Read-only | Unprivileged service API or fixed helper snapshot. |
| User-session | Fixed helper action with validated argv that changes only invoking-user state. |
| Privileged | Explicit confirmation followed by an installed, root-owned, non-writable helper with an operation allowlist. |
| Delegated | Fixed launch or service request to a trusted platform tool that owns policy and authorization. |

### Privileged Allowlist Boundary

- No Phase 1 Settings operation is on the privileged allowlist.
- Existing health actions remain limited to failed-service actions,
  NetworkManager, Bluetooth, and time synchronization as specified in
  `SPEC.md`; they are not automatically Settings actions.
- Phase 2 display persistence allows only validated generated-fragment install
  and rollback operations. It does not accept arbitrary paths, Xorg text,
  commands, or environment-selected executables.
- Repository, XDG, home-directory, symlinked, group-writable, and
  other-user-writable helper copies must never be elevated.
- A trusted helper must resolve outside user-writable paths, be owned by root,
  and have no group or other write bits before polkit or sudo executes it.
- Broad passwordless sudo, a generic command runner, arbitrary service names,
  and arbitrary file writes are forbidden.

### Confirmation, Cancellation, Audit, and Rollback

- The UI must describe the exact target, new value, impact, authorization need,
  and recovery path before a privileged or destructive request.
- Closing the confirmation surface, pressing Escape, rejecting polkit, or
  timing out cancels the request and preserves readable state.
- Previewable display changes default to a 15-second rollback deadline. A
  provider must capture the prior state before applying the preview.
- Helpers return a typed operation ID, result, and bounded diagnostic. They
  must not log secrets, passwords, environment dumps, or unbounded command
  output.
- Success is reported only after the provider confirms the mutation. A failed
  persist step after a live preview triggers rollback and reports both results.

The Control Center's legacy terminal `sudo systemctl restart NetworkManager`
action and `dwm-display-setup` terminal sudo flow remain compatibility paths;
neither is a Settings provider contract.

## Arch Linux Packaging Plan

Package ownership stays centralized in `scripts/dwm-packages.sh`
(`dwm_packages arch <profile>`). Settings adds no runtime dependency beyond
capabilities already present in the installer profiles, and every required
package comes from the official Arch repositories.

| Capability | Arch source | Current map status | Missing behavior |
| --- | --- | --- | --- |
| Settings window | Quickshell 0.3 or newer | `quickshell` in `arch:desktop` (`recommended`) | Settings is unavailable without Quickshell. |
| Capability helper | POSIX shell and base utilities | Installed as a project command; no new package | Individual missing tools produce unavailable records. |
| Display/default state | RandR and XDG utilities | `xorg-xrandr` in `arch:x11` and `xdg-utils` in `arch:runtime-required` (`core`) | Missing tools disable only their controls. |
| Network/Bluetooth/audio/power state | NetworkManager, BlueZ, PipeWire/WirePlumber, X11 tools, light-locker | `arch:desktop` (`recommended`); `networkmanager` in `arch:desktop-optional` (`full`) | Missing optional providers produce unavailable or partial cards. |
| Authorization discovery | Polkit agent and trusted installed helper | `mate-polkit` in `arch:desktop`; helper installation remains project-owned | Missing authorization leaves read-only state available. |
| System updates | pyalpm and pacman-contrib | `arch:system-management` (`recommended`) | Missing pyalpm disables only the update rows. |
| QML development | Qt 6 declarative tools | `arch:qml-development` maps `qt6-declarative`; not in any install profile | Developer tooling is opt-in. |

The `qml-development` profile is opt-in developer tooling and is not part of
`core`, `recommended`, or `full`. This avoids expanding the installed desktop
for users who do not develop QML while keeping the Arch package name in one
map. AUR-only packages appear only in `aur-optional`; no Settings provider
requires them.

## Validation Plan

| Exit criterion | Automated evidence | Manual or runtime evidence |
| --- | --- | --- |
| Settings opens and navigates without idle polling | `make check-settings check-quickshell-settings-xvfb check-quickshell-qml` | Open from Control Center, search, use keyboard/mouse navigation, close, and record the closed CPU/process sample. |
| Arch discovery and clean fallback | `make check-settings` exercises the `arch` platform family plus unavailable service fixtures; `scripts/run-tests-podman` runs it in the pinned Arch container | Run `dwm-settings-provider discover` on an Arch qualification host and record platform/provider rows. |
| Privilege, rollback, errors, unsupported state | `make check-settings check-system-health check-display-setup` plus source assertions for the no-elevation boundary | Cancel or deny an authorization prompt; verify readable state remains. |
| Existing desktop compatibility | Existing launcher, Control Center, controls, network, health, runtime, install, and preservation checks in `make check` | Verify existing Control Center and hotkeys in the qualification session. |
| Packaging and ownership | `make check-install check-install-manifest check-arch-packages` | Verify installed helper ownership for every privileged Settings helper. |

The nested-X11 test must record window geometry, IPC navigation, keyboard and
mouse selection, Escape close, provider cleanup, and a two-second CPU sample
with Settings closed. A passing sample requires less than 10 percent of one CPU
for the managed Quickshell process and no remaining Settings provider process.

Real Arch evidence must record the rolling-release validation record from
`SPEC.md` Section 9.4 (test date, archive snapshot for container runs, and the
pacman, Quickshell, Qt, and kernel versions), architecture, session type,
Settings entry path, discovered provider states, CPU/process sample, and
limitations. Nested X11 does not prove real hardware providers.

The qualification evidence below was recorded on Fedora before the Arch Linux
port. It is retained as history and is not a claim about Arch behavior.

## Phase 1 Qualification Evidence (Fedora, pre-port)

Evidence recorded on 2026-07-21:

- Fedora Linux 44, x86_64, X11 reported the `fedora` provider family. RandR,
  NetworkManager, BlueZ, PipeWire Pulse, DPMS, light-locker, XDG defaults,
  themes, system health, and the trusted authorization path were discovered as
  available. Phase 2 display/input mutations and later accessibility/system
  administration remained explicitly unsupported.
- Nested X11 at 1280x800 opened the 980x620 Settings window, exercised IPC,
  keyboard, mouse, search, Escape close, and provider cleanup. The two-second
  closed-window sample measured 0.00 percent of one CPU for Quickshell.
- Fedora 44 fixtures validated available and unavailable provider records.
- The live Fedora check was read-only. No settings mutation, authorization
  prompt, hardware change, session restart, or managed-shell replacement was
  performed.

## Phase 2 Provider and Qualification Evidence

`dwm-settings-display` and `dwm-settings-input` use append-only, version 1,
tab-separated protocols. Display records describe outputs, modes, current and
preferred rates, rotation, primary state, TearFree and NVIDIA Full Composition
Pipeline capability, profiles, and persistence. Input records describe stable
devices, supported settings, and device-scoped unsupported settings. Tabs and
line breaks in external names are sanitized. QML passes complete structured
argv to fixed helper actions and does not implement RandR, Xorg, XInput, or
libinput policy.

Both sections own event-driven udev discovery watches only while active. A
separate session input watcher debounces add/change events and reapplies saved
values when stable devices return. Display and input previews capture prior
state, expose Keep and Revert, and run an external
watchdog so timeout recovery does not depend on the QML process. Closing
Settings requests immediate rollback; the watchdog remains the final recovery
path if the action process is busy or the shell exits. Display finalization is
atomically claimed so Keep cannot race the watchdog. A failed automatic
rollback retains the captured profile, reports the failure in Settings, and
keeps Revert available for retry.

Input persistence requires a udev serial, physical path, or stable physical
sysfs identity. A device without one remains configurable for the current
session, but Settings reports persistence as unsupported and does not save an
event-node-based identity.

The Displays page numbers every connected monitor card and shows enabled
monitors in a proportional layout preview. Select a reference monitor in a
card, then choose **Left of**, **Right of**, **Above**, or **Below**. Horizontal
placements align top edges; vertical placements align left edges. Each action
moves that monitor and normalizes the active layout origin. Other monitors
retain their relative positions. Resolution and rotation determine tile size;
after changing either, use a placement button again to align the edges.
Discovery appends `mode-size` records (output, mode name, rate, pixel width,
pixel height) so custom RandR names such as `native` remain positionable.
Older discovery responses fall back to conventional mode names or the active
output geometry where available.
Disabled monitors keep their numbered cards but do not appear in the preview
or reference selector. The highlighted button reflects the current geometry.
Apply changes starts the existing 15-second confirmation; the diagram itself
does not change the live layout. Existing saved coordinate profiles still load.
The separate **Automatic layouts** cards manage autorandr's `mobile` (Undocked)
and `docked` profiles. They show saved monitor geometry and modes, detected
hardware matches, currently applied matches, and the default fallback. A
custom live layout may match the hardware without matching the saved settings.
**Edit saved** copies a profile into the pending editor, without applying it;
**Create draft** seeds built-in-only Undocked or the current Docked draft.
**Save draft as ...** requires confirmation and does not apply the draft.
Use **Apply changes** and **Keep changes** to test it first. Saved enabled
monitors must be connected to edit, and all selected modes must be available
on the currently connected hardware before saving.

The optional `autorandr` package from the official Arch repositories supplies
login and DRM hotplug hooks. It is not part of an installation profile.
Without it, automatic-profile controls explain that dependency while normal
display controls remain usable. Saving Undocked sets `default -> mobile` and
stores only the built-in monitor identity; Docked stores the connected monitor
identity set. Unrecognized hardware uses the default fallback. Existing XDG
autostart disablement is respected; Settings does not enable system services.
Profile replacements preserve hooks and create backups under
`~/.config/dwm-titus/display-profile-backups/` (respecting `XDG_CONFIG_HOME`).
An existing `~/.autorandr` directory takes precedence, matching autorandr;
its backups are stored in `~/dwm-titus/display-profile-backups/`.
Confirmed saves merge `set,crtc` into autorandr's `skip-options`, preserving
other settings and backing up the original settings file. This prevents
session-specific assignments and properties from invalidating layout matches.
Saved configs omit CRTC numbers and output properties because those are not
portable between X sessions. Unsupported existing profile options are reported
instead of silently removed. The one Docked slot matches one connected monitor
set; advanced multi-dock and transformed profiles remain managed in autorandr.
Named dwm-titus layouts and privileged **Use at next login** remain separate
from these automatic, per-user layouts.

![Separate saved dock and built-in layouts with a live draft](evidence/display-dock-profiles.png)

![Numbered display placement preview](evidence/display-relative-layout.png)

The screenshot uses a nested X11 fixture with the built-in monitor disabled
and two dock monitors enabled. All four buttons were exercised in that
fixture and their resulting coordinates checked through the Settings model.

Persistent display installation requires a second UI confirmation and
`pkexec`. The helper must be exactly under an installed project libexec path,
root-owned, non-symlinked, and not writable by group or others. Its installed
`dwm-display-setup` dependency has the same ownership checks. It accepts a
validated X11 display, a caller-owned Xauthority file, and structured profile
records only, then writes only
`/etc/X11/xorg.conf.d/90-dwm-titus-display.conf`. Root-container tests cover
repository copies, wrong ownership, writable files, symlinks, injected input,
and authorization denial.

Evidence recorded on Fedora before the Arch Linux port, on 2026-08-15:

- Fedora Linux 44 x86_64 X11 discovered HDMI-0 and DP-0. A complete current
  two-monitor layout preview timed out and restored the exact captured layout.
- A Logitech G502 pointer acceleration preview and a Glorious GMMK3 keyboard
  layout preview changed the selected stable device and restored its prior
  value after timeout. No touchpad was connected; touchpad discovery and
  supported-property behavior are fixture- and nested-X11-tested only.
- Nested X11 at 1280x800 discovered one display and two virtual input devices,
  verified both section states and lifecycle, and measured 0.00 percent of one
  CPU for Quickshell after Settings closed.
- Fedora 44 container validation resolved dependencies, built, validated
  staged install/uninstall, and passed privilege tests.
- Generated display persistence, backup, rollback, and input startup reapply
  are automated. A disposable Fedora 44 UEFI VM with LightDM verified a
  root-owned mode-0644 managed fragment through real Xorg restarts. A
  non-default single-output mode persisted, followed by a two-output
  1024x768 plus 800x600 layout. The Xorg log confirmed the managed OutputClass
  and both monitor sections were applied after restart.
- That restart test exposed and fixed a virtio driver-name mismatch: generated
  OutputClass rules use Xorg's `virtio_gpu` DRM name instead of the
  `virtio-pci` bus driver name.
- An NVIDIA GeForce RTX 4070 SUPER using driver 610.43.03 reported the NVIDIA
  fallback available on both active outputs. The active MetaMode confirmed
  ForceFullCompositionPipeline enabled, and generated persistence emits the
  documented NVIDIA option only for a compatible NVIDIA kernel and Xorg
  driver. Unsupported drivers remain unchanged; explicitly forcing the option
  on an incompatible driver fails before installation.
