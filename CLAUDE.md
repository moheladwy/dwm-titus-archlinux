# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

`AGENTS.md` (imported above) is the binding rule set for engineering, Git/PR
workflow, Arch platform and pacman policy, Settings safety, and validation. `SPEC.md` is the
source of truth for scope and acceptance criteria. This file adds only
commands and cross-file architecture notes.

This fork is **Arch Linux-only** (`ID=arch`; derivatives are rejected). It is
mid-port from Fedora per `.github/plans/arch-linux-port.md`; Fedora code that
is still in the tree (Kickstarts, image tooling, DNF/PackageKit update paths)
is legacy awaiting removal, not a support path. Never run tests, installers, or
package operations on the host; use the Arch container or a VM.

## Commands

All tests must run through the managed workspace wrapper. It creates a
token-guarded temp dir under `${DWM_TEST_TMP_ROOT:-$HOME/tmp}`, exports
`TMPDIR`/`DWM_TEST_WORKSPACE`, and removes it on exit. Makefile `check-*`
targets re-enter `scripts/run-tests` automatically if invoked outside it.

```sh
make                                   # build dwm (copies config.def.h -> config.h if missing)
make native                            # -O3 -march=native build for local use
scripts/run-tests make clean all       # clean build in the managed workspace
scripts/run-tests                      # full gate (= make check)
scripts/run-tests make check-status    # one Makefile check target
scripts/run-tests tests/test-dwm-status.sh   # one test script directly
scripts/run-tests make check-shell check-format   # shellcheck + shfmt
scripts/run-tests make check-quickshell-qml       # Qt6 qmllint with correct import roots
scripts/quickshell-qmllint --root config/quickshell   # same, directly
scripts/run-tests make check-arch-platform check-arch-packages   # os-release gate + package map
scripts/run-tests make check-xvfb-runtime check-monitor-tags   # nested X11 dwm smoke
scripts/run-tests-podman [make <target>]          # same, inside localhost/dwm-titus-tests:arch
scripts/dev-sync-install.sh [--check]  # build + sync this checkout into the live install
./install.sh --dry-run --non-interactive --profile recommended   # inspect install plan
```

`CONTRIBUTING.md` has the change-type -> required-validation table; use it to
pick focused targets. `grep -n '^check-' Makefile` lists every target, and each
usually wraps a single `tests/test-*.{sh,py}` file. Docs site: `npm --prefix docs ci && npm --prefix docs run build`.

## Architecture

Three layers, deliberately separated: a small C window manager, a set of shell
helpers that own all desktop policy and system access, and a Quickshell (QML)
UI that never touches the system directly.

**C window manager** (`dwm.c`, `drw.c`, `util.c`, `tomlparser.c`). Compile-time
defaults live in `config.def.h`; `config.h` is user-owned. Hotkeys, themes, and
window rules are loaded at runtime from TOML in
`${XDG_CONFIG_HOME:-$HOME/.config}/dwm-titus/` (defaults shipped from
`config/*.toml`) and hot-reloaded via a non-blocking inotify fd polled in the
event loop, or via `SIGUSR1`. dwm exports state as X root properties: EWMH
atoms plus custom `_DWM_MONITOR_DESKTOPS`, `_DWM_SELECTED_MONITOR`, and
`_DWM_FULLSCREEN_MONITORS`. The bar status comes from root `WM_NAME`.

**dwm <-> Quickshell bridge.** There is no custom IPC socket in dwm.
- Shell -> dwm state: `scripts/dwm-quickshell-state watch` reads root
  properties (`xprop`) and streams them to `config/quickshell/state/DwmState.qml`.
- dwm -> shell commands: `hotkeys.toml` entries `spawn` either
  `quickshell ipc --path "$XDG_CONFIG_HOME/quickshell/shell.qml" call <target> <fn>`
  or a `dwm-quickshell-*` helper. The `--path` must be the installed path, which is
  why the shell must never be started from a repo-local path.

**Quickshell shell** (`config/quickshell/`). `shell.qml` is the root. Each
subdirectory is a `qs.<name>` module (`core` holds shared widgets, `Commands`,
and `Icons`). Feature areas usually pair a `*Model.qml`, which runs `Process`
calls to a helper script, with a `*Window.qml`/`*Pane.qml` for the view. Install
replaces the whole user `quickshell/` directory from this tree.

**Helper scripts** (`scripts/`). These are the backend for every UI feature:
`dwm-settings-*` providers (discovered by `dwm-settings-provider`),
`dwm-quickshell-*` adapters, the update center, diagnostics, and session
startup (`autostart.sh` / `dwm-session-launch`). Privileged operations live in
separate `*-root` helpers (`PRIVILEGED_HELPERS` in the Makefile). These are
installed root-owned to `${PREFIX}/libexec/dwm-titus` and invoked via polkit.
The unprivileged script validates input and calls them; never elevate the repo copy.

**Packages and install.** `scripts/dwm-packages.sh` (`dwm_packages <family>
<profile>`, family `arch`) is the single package map, used by `install.sh`,
`check-deps.sh`, `dev-sync-install.sh`, and the CI container. AUR-only names
live only in the `aur-optional` profile. `install.sh` runs one `sudo pacman
-Syu` before any package step.
`install.sh` builds, then runs `sudo make install` with `OWNER`/`USER_HOME`/XDG
paths. It builds as the owner via `runuser` and installs `install-system-files`
as root. It then installs `install-user-files` as the owner, never as root, and
preserves user TOML. The `install-system`/`install-user` targets run each half
alone, and `DESTDIR` stages an install. All of these go through
`dwm-desktop-update guard-*-install`.
The Fedora Kickstarts and `scripts/build-dwm-fedora-*` are legacy; there are
no Arch images.

## Gotchas

- Adding an installed helper script means updating `INSTALL_COMMANDS` (or
  `PRIVILEGED_HELPERS`) in the Makefile. For extensionless scripts, also add
  them to the explicit file lists in `check-shell` and `check-format`; only
  `scripts/*.sh` and `tests/*.sh` are globbed.
- Plain `qmllint` reports false `Quickshell`/`qs.*` import errors, and on Arch
  `/usr/bin/qmllint` may be Qt5. Use
  `scripts/quickshell-qmllint --root config/quickshell`.
- Never `pacman -Sy` alone or `pacman -S` while updates are pending; never run
  an AUR helper or `makepkg` as root.
- To relaunch the shell after QML changes, use
  `dwm-quickshell-controlcenter action restart-quickshell` (after syncing with
  `scripts/dev-sync-install.sh`), not `quickshell --path config/quickshell`.
- `TASKS.md` holds only the active roadmap phase; replace its contents rather
  than appending.
