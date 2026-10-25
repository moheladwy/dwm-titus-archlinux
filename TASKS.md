# Active Tasks

## Arch Linux port, Phase 9

Plan: [arch-linux-port.md](.github/plans/arch-linux-port.md). Phases 0-4 are
delivered in the first pull request (#1), and Phases 5-8 (the native pacman
update stack, the optional AUR provider, and the remaining Settings platform
work) in the update-stack pull request stacked on it. This file covers plan
Phase 9 only. Phase 10 (retiring Fedora-only, image, and gaming code) must not
start in the same change. No merge or release publication is authorized.

### Phase 9: Documentation site and user docs

- [ ] Sweep the site pages for Fedora wording:
      `docs/src/content/{install,dependencies,getting-started,settings,troubleshooting,configuration}.md`,
      `DocsLayout.astro`, and `pages/development-progress.astro`.
- [ ] Sweep the reference docs for Fedora wording: `docs/DESKTOP-UPDATES.md`,
      `docs/SETTINGS-PLATFORM.md`, `docs/SETTINGS-CAPABILITIES.md`, and
      `lightdm/README.md`.
- [ ] Add user docs for installing base Arch with the official ISO or
      `archinstall`, then running `./install.sh`.
- [ ] Document the AUR policy and how to enable it (`--enable-aur` with an
      already-installed `paru` or `yay`).
- [ ] Document the PAM keyring setup for `startx`.
- [ ] Document the never-partial-upgrade rule.
- [ ] Add the `CHANGELOG.md` entry for the platform change, with migration
      notes, covering anything Phases 1-8 did not already record.

### Validation

- [ ] `npm --prefix docs ci && npm --prefix docs run build`, run in a
      container, never on the host.
- [ ] Record every page that still mentions Fedora and why (legacy code that
      Phase 10 removes, or upstream history).
