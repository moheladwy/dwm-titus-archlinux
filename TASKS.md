# Active Tasks

## Arch Linux port, Phases 0-4

Decisions: [ARCH-PORT-DECISIONS.md](docs/ARCH-PORT-DECISIONS.md). This pull request
covers plan Phases 0-4 only. No merge or release publication is authorized.
Tests that install packages or change system state run only in the Arch
container or a VM, never on the host.

### Phase 0: Contract change

- [ ] Rewrite `SPEC.md` for Arch: `ID=arch` only, no images or hosting, no
      gaming, Dolphin, up-front `pacman -Syu`, AUR policy, Qt 6 `qmllint`,
      Arch dependency map, and the rolling-release validation record.
- [ ] Replace the Fedora rules in `AGENTS.md` and update `CLAUDE.md`,
      `README.md`, `CONTRIBUTING.md`, `ROADMAP.md`, `TASKS.md`, and
      `CHANGELOG.md`.

### Phase 1: Fork endpoints and identity

- [ ] Point `scripts/dwm-desktop-update` and `scripts/dwm-update-center` at
      this fork, and update the pinned URLs in the desktop-update tests.
- [ ] Update `.github/CODEOWNERS`, `.github/FUNDING.yml`, `SECURITY.md`, the
      installer docs URL, the docs-site repository guard, and the bug report
      template fields (kernel, pacman, and Quickshell versions).

### Phase 2: Platform identity and package map

- [ ] Add `dwm_platform_family` (exact `ID=arch`, `ID_LIKE` ignored) and the
      pacman install and query commands in `scripts/dwm-utils.sh`.
- [ ] Add `arch:<profile>` entries and the `aur-optional` profile to
      `scripts/dwm-packages.sh`; drop PackageKit, `dnfdragora`, Path, Thunar,
      gaming, and image profiles for Arch.
- [ ] Replace hardcoded `dwm-packages.sh fedora` callers and the provider
      guards (`pacman -T power-profiles-daemon`, `pulseaudio` conflict).
- [ ] Add the platform and package tests (`check-arch-platform`,
      `check-arch-packages`).

### Phase 3: Test container, CI, and QML lint

- [ ] Add `tests/containers/arch/Containerfile`, pinned by digest and to an
      Arch Linux Archive snapshot.
- [ ] Switch `scripts/run-tests-podman` to `localhost/dwm-titus-tests:arch` and
      update its contract test.
- [ ] Move CI and CodeQL to the Arch container and the package map.
- [ ] Make `scripts/quickshell-qmllint` prefer `/usr/lib/qt6/bin/qmllint` and
      reject a Qt 5 `qmllint`.

### Phase 4: Existing-system installer and runtime

- [ ] Accept Arch in `install.sh`, run one visible `sudo pacman -Syu` before
      any package step (listed in `--dry-run`), and abort if it fails.
- [ ] Remove gaming and `dwm-dnf-defaults` from the install path; add
      `--enable-aur` for an already-installed `paru` or `yay`, run as the user.
- [ ] Replace Thunar and Path with Dolphin (default apps, menu integration,
      theming), and remove the Path window rule from the shipped defaults.
- [ ] Add a LightDM drop-in for `lightdm-slick-greeter` and the `dwm`
      session without rewriting `/etc/lightdm/lightdm.conf`.
- [ ] Check `gnome-keyring` and its PAM module; treat `xkbset` as optional.
- [ ] Port `dev-sync-install.sh`, power, screensaver, health, diagnostics, and
      Quickshell version and wording helpers to Arch.
- [ ] Rename the user portal configuration to `dwm-portals.conf` with a safe
      migration.
- [ ] Update the affected tests and installer, runtime, and user docs.

### Validation

- [ ] `scripts/run-tests make clean all` and `scripts/run-tests`.
- [ ] `scripts/run-tests-podman make clean all` and `scripts/run-tests-podman`
      on the pinned Arch image (Docker if Podman is unavailable).
- [ ] Installer `--dry-run` and a real `--profile core` run in a clean Arch
      container; a staged `DESTDIR` install.
- [ ] `--profile recommended` with LightDM in a VM with a fresh Arch install.
- [ ] Nested X11 dwm smoke and a `quickshell --no-duplicate` idle check.
- [ ] Record the rolling-release evidence and every untested path in the PR.

### Follow-ups

- [ ] Check current repositories for drift: run the gate against live Arch
      mirrors instead of the pinned archive snapshot, and record the result
      separately from snapshot evidence. No scheduled job does this yet.
