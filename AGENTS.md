# AGENTS.md

## Purpose

This repository is an Arch Linux-only X11 desktop environment built around a
heavily patched fork of suckless dwm and a managed Quickshell shell. It is a
fork of `ChrisTitusTech/dwm-titus` that replaces Fedora with Arch Linux. The
product is a complete desktop installed onto an existing Arch Linux system with
`./install.sh`. Arch Linux is the sole supported distribution.

The approved port plan is `.github/plans/arch-linux-port.md`. Its decisions
D1-D14 are final unless the owner changes them.

Read `SPEC.md` before making product, platform, installer, dependency, or
packaging changes. Treat `SPEC.md` as the source of truth for project scope and
acceptance criteria.

## Priorities

1. Preserve dwm stability and existing user workflows.
2. Keep the C window-manager core small, understandable, and dependency-light.
3. Build a cohesive Arch Linux desktop without moving desktop policy into the
   C event loop.
4. Preserve the Arch install and session contract, and never leave the system
   in a partial-upgrade state.
5. Keep installation and settings changes safe, repeatable, reversible, and
   explicit.
6. Prefer focused changes that can be reviewed and tested independently.

## Arch Linux Support Contract

The sole supported platform is Arch Linux x86_64. Only `ID=arch` from
`/etc/os-release` is accepted; `ID_LIKE` is ignored. Every derivative
(EndeavourOS, CachyOS, Manjaro, Arch Linux ARM) and every other
operating-system identity must fail clearly before any package installation or
system change, with no override flag. Users install Arch Linux themselves from
the official ISO or `archinstall`, then run `./install.sh`. The project ships
no installer images, hosts no package repository or download server, and holds
no signing keys. Fedora is not supported by this fork.

## Repository Map

- `dwm.c`, `drw.c`, `util.c`, `tomlparser.c`: window-manager sources.
- `config.def.h`: version-controlled default compile-time configuration.
- `config.h`: local build configuration. Do not overwrite user changes.
- `config.mk`: compiler, include, library, and installation settings.
- `Makefile`: build, install, uninstall, and release targets.
- `config/`: application configuration and default TOML runtime settings.
- `scripts/`: session startup, dependency checks, desktop helpers, and
  operational scripts.
- `install.sh`: supported installer for an existing Arch Linux system.
- `scripts/dwm-packages.sh`: the single package capability map
  (`dwm_packages arch <profile>`).
- `tests/containers/arch/`: the pinned Arch test container.
- `dwm-fedora.ks`, `dwm-fedora-nvidia.ks`, `scripts/build-dwm-fedora-*`,
  `scripts/image/`, and remaining `fedora:*` map entries: legacy Fedora code.
  It is not part of the product and remains in the tree only until a later
  port phase removes it. Do not extend it.
- `dwm.desktop`: display-manager X session entry.
- `AGENTS.md`: durable engineering and agent-execution rules.
- `SPEC.md`: product scope, interfaces, and acceptance criteria.
- `ROADMAP.md`: ordered desktop-environment outcomes.
- `TASKS.md`: implementation work for the active roadmap phase only.
- `docs/`: user, contributor, and release documentation.
- `.github/plans/`: approved multi-phase plans, such as the Arch port.

## Planning Workflow

- Use `SPEC.md` for durable product requirements and compatibility contracts.
- Use `ROADMAP.md` for ordered phase objectives and exit criteria.
- Use `TASKS.md` only for detailed work in the active phase. Replace its task
  set when a phase completes instead of accumulating historical checklists.
- Record completed user-visible behavior in `CHANGELOG.md` and releases.
- Do not mark a task or phase complete without its required validation or a
  precise statement of what could not be tested.
- Treat phase boundaries as review and rollback points. Do not begin the next
  phase in a change that was scoped only to complete the current one.

## Git and Review Workflow

- Before implementation work, determine the intended pull request base
  (`main` unless the work is explicitly stacked), verify the current branch's
  ancestry and divergence, and create a valid `codex/<short-topic>` branch from
  that base. Use that topic branch in the current worktree or place it in a
  separate worktree when isolation is needed; never use the base branch itself
  as the task worktree. If the name already exists, add a distinct short
  suffix; never build the pull request from an unrelated or unexpectedly
  diverged branch.
- Automatically make small coherent commits, push the branch, and open a
  ready-for-review pull request after the available applicable local gates
  pass. If a required local gate cannot run because the environment or tooling
  is unavailable, document the exact gap and limitation in the pull request
  and complete the missing coverage locally or with an explicitly dispatched
  hosted run before merging; do not claim unrun coverage passed. Do not pause
  for repeated Git-action approval unless the user requests local-only work
  or sets an explicit stop point.
- Run `git status --short` before editing, preserve all pre-existing worktree
  changes, and inspect the exact staged files before every commit. When
  unrelated changes cannot be isolated safely, use a separate worktree or ask
  the user for direction. Never stage or publish credentials, tokens, private
  keys, secret files, or other sensitive data.
- Keep each pull request to one independently testable review boundary. Split
  larger work into ordered pull requests, and avoid mixing unrelated code,
  tests, documentation, or cleanup.
- When a pull request depends on unmerged work, base it on the prerequisite
  branch and state the dependency in the pull request. After the prerequisite
  merges, rebase the dependent branch onto updated `main` or merge updated
  `main` into it. Publish a rebase with `git push --force-with-lease`, or
  publish a merge with a normal push; verify the remote head and that the pull
  request diff contains only its intended review boundary, and then retarget it
  to `main`.
- Before publishing, run focused validation, the full relevant repository
  gates, the built-in Codex review loop, and an independent review when the
  review tooling is available. Address valid findings and repeat affected
  checks until the local review loop is clean.
- Use local validation and a completed independent built-in Codex review as
  the merge gate. For an existing PR, review the complete diff with
  `codex review --base origin/main` (or its verified stacked base); use
  `codex review --uncommitted` for unpublished edits. Review instances must
  report findings directly and never launch nested reviews.
- Fix actionable findings locally, rerun affected checks, and repeat review
  until clean before pushing. Reuse passing checks for unchanged code; rerun
  the full relevant gate after base integration or changes that invalidate it.
  Record the reviewed commit, commands, results, and manual evidence in the PR.
- Give each review invocation a local evidence file with the base, reviewed
  tree/commit, command results, log paths, and explicitly reused coverage. Use
  the custom prompt in `CONTRIBUTING.md` when supplying this context. Reviewers
  should repeat long tests only for invalidated evidence or a concrete concern.
- After publishing, verify the remote head matches the locally validated
  content and inspect unresolved review threads. Resolve actionable feedback
  before merging. Hosted CI runs on `main` as a post-merge safety net, with
  manual dispatch for additional coverage; do not wait for optional hosted
  checks or hosted review bots when the local gate is complete. Existing
  branch-protection requirements still apply, and known failures must be
  investigated rather than ignored.
- Open ready pull requests by default, not drafts. Never merge, release,
  deploy, or send external announcements without explicit user authorization.

## Arch Package Management Rules

- Arch supports only full upgrades. Never run `pacman -Sy` on its own, and
  never use a component that refreshes the sync databases behind the user's
  back (for example a PackageKit client).
- Never run `pacman -S <package>` while `pacman -Qu` is non-empty. Install
  packages only after a full upgrade, or block with "Update system packages
  first".
- The installer runs one visible `sudo pacman -Syu` before any package step.
  It is listed in `--dry-run`, uses pacman's own prompt, adds `--noconfirm`
  only for `--non-interactive`, and aborts the install if it fails.
- Install official packages with `pacman -S --needed --`. Validate package
  names before passing them to pacman, and never delete the pacman lock.
- Ship no `pacman.conf` changes and do not enable `multilib` or third-party
  repositories.
- AUR use is opt-in through `--enable-aur`. Use only an AUR helper that is
  already installed (`paru` or `yay`); never bootstrap one. Run it as the
  invoking user, never as root. Official packages never go through it.
- Root-owned and pkexec helpers never call an AUR helper or `makepkg`.
- AUR-only packages belong only in the `aur-optional` profile and must never
  be required. Features that use them must degrade cleanly without them.
- Do not add installer images, project package repositories, signing keys, or
  gaming integrations. They are out of scope (plan D10, D11).
- Arch configures no LSM by default. The installer must never change host
  SELinux, AppArmor, or other LSM state.

## Desktop Settings Rules

- Keep the Settings frontend and all QML unprivileged.
- Read state through stable service APIs, D-Bus, signals, subscriptions, or
  bounded helpers. Do not parse human-oriented output when a machine interface
  exists.
- Separate read-only state, user-session changes, privileged system changes,
  delegated tools, and unsupported capabilities.
- Privileged helpers must be installed root-owned and non-writable, expose only
  allowlisted operations, validate every argument, and require explicit user
  intent through polkit or an equally narrow authorization path.
- Repository or user-writable helper copies must never be elevated.
- Risky changes require preview, confirmation, rollback, or recovery behavior
  appropriate to their impact. Authorization denial must not hide readable
  state.
- Unsupported hardware capabilities must be hidden or explained without
  breaking the rest of Settings.

## Arch Platform Rules

- Detect Arch through `/etc/os-release` with an exact `ID=arch` match, ignore
  `ID_LIKE`, and reject every other identity before package installation or
  system changes. Do not require `VERSION_ID`; Arch does not set it.
- Keep Arch package capability names in the shared dependency map. Do not
  scatter package-name lists across multiple scripts.
- Query packages through pacman's machine interfaces (`pacman -T`, `-Q`,
  `-Si`, `-Sp --print-format`) or pyalpm rather than parsing human output.
- Use `pkg-config` for X11 and library discovery where available. Avoid legacy
  hardcoded paths such as `/usr/X11R6`.
- Respect `CC`, `CFLAGS`, `CPPFLAGS`, `LDFLAGS`, `PREFIX`, `DESTDIR`,
  `XDG_CONFIG_HOME`, and the invoking user's home directory.
- Do not assume `/usr/lib` versus `/usr/lib64`. Search known executable paths
  only when no stable command or package interface exists.
- Support both display-manager sessions and `startx`.
- Treat Xorg as required. Wayland-native support is outside the current scope.
- Keep optional desktop components optional. The absence of Picom, a wallpaper,
  or a preferred terminal must not crash dwm.
- Use ASCII punctuation in source, scripts, and new documentation unless a
  file's established format requires otherwise.

## Configuration and Compatibility

- Preserve `config.def.h` as the default template.
- Never replace an existing `config.h`, user TOML file, `.xinitrc`, or
  application configuration without explicit user consent or a backup.
- Runtime TOML files live under
  `${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/`.
- Preserve hot reload behavior for `hotkeys.toml`, `themes.toml`, and
  `window-rules.toml`.
- `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/` is managed exclusively by
  dwm-titus. Unlike user-owned dwm TOML files, install/update flows may replace
  this directory from tracked `config/quickshell/` to prevent stale shell code.
- Relaunch the managed Quickshell instance through
  `dwm-quickshell-controlcenter action restart-quickshell` or the normal
  autostart path. Do not manually start it with a repo-local `--path`, because
  hotkeys target `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml` and
  Quickshell treats different config paths as different IPC instances.
- Quickshell integration must be event-driven whenever the underlying state has
  a signal, subscription, watch, IPC, or service API. Prefer `xprop -spy`,
  D-Bus/service notifications, process stdout streams, or Quickshell service
  APIs over QML polling timers. Polling is allowed only for inherently sampled
  values such as a clock or CPU load, or when a documented fallback has no
  event source.
- Quickshell must not be an idle resource hog. Avoid resident hidden launcher
  models, overlapping `Process` launches from timers, and duplicate shell
  providers such as running DMS alongside the dwm-titus managed shell. On X11,
  avoid per-screen `Variants { model: Quickshell.screens }` panels unless a
  live CPU sample proves they idle cleanly; prefer a single `PanelWindow` for
  the managed shell. After Quickshell changes, validate `quickshell --no-duplicate`
  in a real or nested X11 session and confirm the Quickshell process is near
  idle when the launcher is closed.
- For Quickshell QML linting, stock `qmllint` must be given explicit Qt and
  Quickshell QML import roots (on Arch, `/usr/lib/qt6/qml`) and a lint-only `qs.core/qmldir` module map when checking
  files that import this repository's `qs.core` helpers. `QMLLS_BUILD_DIRS`
  and `QML_IMPORT_PATH` should mirror those roots for language-server tooling.
  Do not treat plain `qmllint` import failures as runtime failures until the
  configured import paths have been verified. Use the Qt 6 linter
  (`/usr/lib/qt6/bin/qmllint`); on Arch `/usr/bin/qmllint` may be the Qt 5
  tool and must be rejected.
- Keep existing keybindings, window rules, EWMH behavior, multi-monitor
  behavior, and autostart behavior unless the task explicitly changes them.
- When changing defaults, update the relevant documentation and migration
  notes in the same change.

## Shell and Installer Standards

- Use Bash only when Bash features are needed; otherwise use POSIX `sh`.
- For Bash scripts, use `set -euo pipefail` unless a documented reason prevents
  it. For POSIX scripts, use `set -eu`.
- Quote variable expansions, use `command -v`, and avoid parsing human-oriented
  command output when a stable machine interface exists.
- Privilege escalation must be limited to package installation and system-wide
  file installation. Do not run the full installer as root.
- Installation must be idempotent. Re-running it must not duplicate services,
  corrupt configuration, or reset user choices.
- Package installation and service enablement must be visible to the user.
  Do not silently alter bootloader, display-manager, firewall, PAM, LSM, or
  security policy settings.
- Network downloads must be optional, clearly reported, and failure-tolerant
  unless the downloaded artifact is explicitly required.
- Run ShellCheck and shfmt on changed shell scripts when available.

## Build and Code Standards

- Keep the existing C99 style and compile with warnings enabled.
- Avoid adding a new library dependency unless it materially improves a
  required feature. Required dependencies must be available in the official
  Arch repositories.
- Check allocation, file, Xlib/XCB, parser, and process-launch failures.
- Do not introduce blocking work into the X event loop.
- Keep Linux-specific functionality, such as inotify, explicit and documented.
- Do not commit generated objects, binaries, release archives, or local
  configuration changes unless the task specifically requires release assets.

## Required Validation

Run the smallest applicable set first, then the full relevant set through the
managed test workspace:

```sh
scripts/run-tests make clean all
scripts/run-tests
```

For shell changes:

```sh
shellcheck install.sh scripts/*.sh tests/*.sh
shfmt -d install.sh scripts/*.sh tests/*.sh
```

For Quickshell QML changes, run `scripts/quickshell-qmllint --root config/quickshell`
(or `scripts/run-tests make check-quickshell-qml`) with the explicit Qt 6 QML
module root documented in `SPEC.md`, and validate the managed shell in a real
or nested X11 session before declaring runtime behavior verified.

For platform, package-map, installer, or packaging changes, also run the
pinned Arch container and the platform and package checks:

```sh
scripts/run-tests-podman make clean all
scripts/run-tests-podman
scripts/run-tests make check-arch-platform check-arch-packages
```

`scripts/run-tests-podman` builds `localhost/dwm-titus-tests:arch` from
`tests/containers/arch/Containerfile`, pinned to an Arch Linux Archive
snapshot. Docker may run the same container when Podman is unavailable.
Installer changes additionally need a real installer run in a clean Arch
container or a virtual machine with a fresh Arch installation.

Tests that install packages, run the real installer, or change system state
must run in an isolated container or virtual machine, never on a developer's
host system. This includes real `install.sh` runs, `pacman` transactions, and
privileged helper tests.

At minimum, verify dependency resolution, a clean build, staged installation
with `DESTDIR`, installed file paths, and script syntax. A real X11 session or
nested X server is required before declaring runtime behavior fully validated.

Use `${DWM_TEST_TMP_ROOT:-$HOME/tmp}` for test workspaces and clear the exact
run directory after success, failure, or interruption. If a required Arch path
cannot be tested, state exactly what was not tested.

Arch is a rolling release. Runtime evidence must include the rolling-release
record from [SPEC.md Section 9.4](SPEC.md#94-rolling-release-validation-record):
the test date, the archive snapshot for container runs, and the pacman,
Quickshell, Qt, and kernel versions.

## Change Discipline

- Inspect `git status` and relevant files before editing.
- Preserve unrelated user changes.
- Keep commits and patches narrowly scoped.
- Update `SPEC.md` only when requirements intentionally change.
- Update README and user-facing docs when commands, dependencies, defaults, or
  the supported platform or architectures change.
- Do not perform destructive Git or filesystem operations without explicit
  authorization.
- Never expose credentials, tokens, private keys, or secret file contents.
