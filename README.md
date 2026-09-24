# Omarchy on NixOS: a modular, declarative desktop

This repo rebuilds [Omarchy](https://omarchy.org) on NixOS. Omarchy is DHH's
opinionated Arch Linux + Hyprland setup. The keybindings, the SUPER+SPACE
menu, the theme switcher, dev-environment and database installers, web apps,
TUIs, capture tools and toggles all come across. What changes is how they're
built. Omarchy runs `pacman`, `mise` and `docker run` against a live system.
Here every menu action edits a file in this repo and rebuilds, so the machine
always matches what's committed.

Underneath the Omarchy layer is a host-agnostic NixOS module library:
hardware modules (CPU/GPU/VM guests, Apple Silicon, TPM2 disk unlock, Secure
Boot) and deployment roles (desktop, headless, gaming, kiosk, laptop, NAS).
An interactive bootstrap (`./run.sh`) detects the machine and picks from
them. The look comes from Omarchy's theme set: every upstream theme,
switchable from the menu, colours the whole desktop (see [Themes](#themes)).

**Per-host config never lands in the repo.** Each machine owns its
`/etc/nixos/` and pins this repo as a `path:` flake input.

## How it fits together

```
~/nixos  (this repo)                        /etc/nixos  (per machine, generated)
├── flake.nix  → lib.mkHost,        ◄────── flake.nix    inputs.config-repo = path:~/nixos
│                nixosModules.*,             host.nix     hostname, allowUnfree, overrides
│                templates.*                 hardware-configuration.nix
├── modules/{common,hardware,roles,home,omarchy}
├── templates/     framework dev-env layers
└── run.sh         bootstrap that writes /etc/nixos
```

`lib.mkHost { hostname, username, system, channel, extraModules }` composes a
system from the modules the bootstrap selected. `channel` picks a matched
nixpkgs + home-manager + Stylix trio:

| Channel | Used by | Why |
| --- | --- | --- |
| `26.05` (default) | x86_64 hosts | Current release; Hyprland 0.55+ with the native Lua config |
| `25.11` | Apple Silicon | The Asahi installer and the `nixos-apple-silicon` binary cache are pinned here; Hyprland 0.52 with the `.conf` config |

A few fast-moving packages (currently `claude-code`) come from
`nixos-unstable` without moving the whole system.

**Rebuilding.** Because `/etc/nixos` locks this repo by content hash, a plain
`nixos-rebuild` builds the *last locked copy* and ignores your edits. Always
refresh the input first. The `nrs` shell alias and Menu › Update › Rebuild
both do this:

```bash
sudo sh -c 'nix flake update config-repo --flake /etc/nixos && nixos-rebuild switch --flake /etc/nixos --impure'
```

## The Omarchy layer

`modules/omarchy/` plus the Hyprland keybinds in `modules/home/hyprland.nix`.
Every script is a `writeShellApplication` on `PATH` with its dependencies
pinned, and knows the repo location through `$OMARCHY_REPO`.

### Omarchy → NixOS

| Omarchy (Arch) | Here |
| --- | --- |
| `omarchy-pkg-install` → `pacman -S` | Search nixpkgs (fzf), append the attribute to `modules/omarchy/apps.json`, rebuild. Unknown names are skipped with a warning, so a typo can't break a rebuild. |
| `omarchy-install-dev-env` → `mise use --global` | Pick one of ~70 [nix-templates/dev](https://github.com/nix-templates/dev) templates and scaffold a **per-project** devShell with direnv (see below) |
| `omarchy-install-docker-dbs` → `docker run` | Toggle PostgreSQL / MySQL / MariaDB / Redis / MongoDB / MSSQL in `dbs.json`; each becomes a `virtualisation.oci-containers` systemd unit bound to localhost |
| `omarchy-theme-switcher` / `omarchy-theme-set` | Same themes, same `~/.config/omarchy/themes` + `current/theme` layout; the pick is written to `theme.json` and the system rebuilds |
| `omarchy-update` | Rebuild, bump flake inputs + rebuild, roll back a generation, garbage collect |
| Web apps / TUIs | Same as Omarchy: imperative `.desktop` entries in `~/.local/share/applications` (Chromium `--app` windows, or kitty-wrapped commands) |

### The menu (SUPER+SPACE)

A rofi tree, `omarchy-menu [route]`:

- **Apps**: the launcher
- **Trigger**: capture (screenshot region/window/screen through satty, screen recording, OCR, QR, colour picker), toggles, clipboard history, emoji
- **Style**: theme (preview grid), background, Hyprland look
- **Setup**: Wi-Fi, Bluetooth, audio, monitors, keybindings, open the config repo in the editor or lazygit
- **Install / Remove**: package, web app, TUI, development environment, Docker database
- **Update**: rebuild, bump inputs, roll back, garbage collect
- **Learn**: live keybinding cheatsheet, NixOS manual, nixpkgs search, Home Manager options, Hyprland wiki
- **System**: lock, suspend, logout, restart Hyprland, reboot, shutdown

Direct routes are bound too: SUPER+ESC system, SUPER+CTRL+C capture,
SUPER+CTRL+O toggles, SUPER+K keybindings, SUPER+CTRL+SPACE wallpaper,
SUPER+CTRL+E emoji. SUPER+CTRL+I / N toggle idle and nightlight, SUPER+SHIFT+SPACE
toggles the bar, and SUPER+, / SHIFT+, / CTRL+, dismiss or silence
notifications. Press SUPER+K for the full list; it's read live from `hyprctl`.

### Development environments

Install › Development environment lists every template from
[nix-templates/dev](https://github.com/nix-templates/dev), pinned as the
`dev-templates` flake input, plus three framework layers from `templates/`.
Each scaffolded project gets:

- `flake.nix`: a devShell with the toolchain, language server, linters,
  formatters and SAST/secret scanners, plus `lint`, `fmt` and `scan` commands
- `.envrc`: `use flake`, so direnv (with nix-direnv) loads the shell on `cd`
- `.nvim.lua`: plugin-free LSP + format-on-save. `exrc` is enabled in the
  LazyVim config; `:trust` it once per project
- `.vscode/`: recommended extensions, settings and tasks
- `.editorconfig`, `.gitignore`

| Framework layer | Built on | Adds |
| --- | --- | --- |
| `laravel` | upstream `php` | Node.js, the `laravel` installer, `node_modules/.bin` on PATH |
| `symfony` | upstream `php` | `symfony-cli` |
| `phoenix` | upstream `elixir` | `inotify-tools` for live reload |

A layer's `flake.nix` pulls the upstream devShell in through `inputsFrom`.
When the templates are built, the upstream editor files are merged underneath
it (`modules/omarchy/dev-templates.nix` and `home.nix`). Scaffolding copies
from the Nix store, so it works offline.

Outside the menu:

```bash
omarchy-dev-env rust                        # prompts for a directory
nix flake new -t path:$HOME/nixos#python ./myproject
```

The flake also exposes upstream's aliases (`ts`, `js`, `k8s`, `tf`, `sh`,
`md`, `c`/`cpp`, `gha`), plus `dotnet` → `csharp`. Update the template set with
`nix flake update dev-templates` and rebuild. A framework template made with a
manual `nix flake new` includes only the layer's own files; the menu adds the
upstream editor files.

## Layout

```
flake.nix               lib.mkHost, nixosModules.{common,hardware,roles}, templates
run.sh                  interactive bootstrap
templates/              framework dev-env layers (laravel, symfony, phoenix)
docs/uninstall-asahi.md removing Asahi from the MacBook and returning to macOS-only

modules/
  common/               always on
    base.nix            systemd-boot, NetworkManager, Tailscale, PipeWire, Hyprland, SSH, zram, nix GC/optimise
    users.nix           primary user (UID 1000, zsh, lingering, passwordless sudo, key-only SSH)
    packages.nix        system packages; FOSS always, unfree gated on allowUnfree
    stylix.nix          system Stylix; base16 scheme + polarity from the active theme
    home-manager.nix    home-manager.users.<username> = modules/home

  hardware/             opt-in per machine
    cpu-{intel,amd}.nix  gpu-{intel,amd,nvidia}.nix
    vm-{hyperv,qemu,vmware,virtualbox}.nix
    apple-silicon.nix   Asahi kernel, firmware, Mesa, 8 GiB swapfile (25.11 channel)
    tpm-fde.nix         systemd initrd + TPM2 unlock of a LUKS2 root
    secure-boot.nix     lanzaboote: signed UKIs, no cmdline editor, no initrd rescue shell

  roles/                opt-in by deployment shape
    desktop.nix         greetd/tuigreet → Hyprland; auto-login when the root is encrypted; Omarchy system layer
    headless.nix        headless Hyprland + wayvnc on :5900
    gaming-kiosk.nix    imports gaming; boots into Steam Big Picture under gamescope
    gaming.nix          Steam, Proton-GE, gamescope, gamemode, controllers, Bluetooth (x86_64)
    gaming-asahi.nix    Steam on Apple Silicon through muvm + FEX
    laptop.nix          TLP, lid switch, backlight tools, powertop
    multi-monitor.nix   profile.monitorsLua / monitorsConf → ~/.config/hypr/monitors.{lua,conf}
    nas.nix             SMB automounts under /mnt/nas/<share> (added by hand, not by run.sh)

  home/                 user layer, through home-manager
    hyprland.nix        Lua config (0.55, x86) or .conf (0.52, Asahi); keybinds; workspace pinning per monitor
    quickshell/         top bar with calendar, mixer and power popups (replaces waybar.nix, kept unimported)
    desktop.nix         kitty, rofi, swaync, hyprlock/hypridle, GUI app baseline, Tuta PWA
    shell.nix           zsh + starship; nrs alias
    cli.nix             lsd, bat, fzf, zoxide, yazi, lazygit, btop, …
    neovim.nix          neovim + direnv; ~/.config/nvim → ~/dotfiles/nvim (LazyVim, out of store)
    nixcord.nix         Discord + Vencord (x86, unfree) or Vesktop (aarch64)
    stylix.nix          opts the hand-styled apps out of Stylix
    colors.nix          re-exports the active Omarchy palette

  omarchy/              the Omarchy port
    home.nix            menu scripts, menu-installed packages, theme wallpaper sets
    system.nix          Docker + menu-managed database containers
    theme.nix           Omarchy theme registry (colors.toml → palette, ANSI, base16, neovim)
    dev-templates.nix   nix-templates/dev + local framework layers
    apps.json dbs.json theme.json    state the menu edits
    scripts/            omarchy-* shell scripts
```

## Bootstrap

On a fresh NixOS install, or any time you want to reconfigure a host:

```bash
git clone <this repo> ~/nixos
cd ~/nixos
./run.sh              # --no-rebuild writes /etc/nixos but stops before activating
```

Keep the clone at `~/nixos`; the menu scripts expect it there.

`run.sh` is interactive and safe to re-run. It:

1. **Detects** the architecture (Apple Silicon via the device tree, which
   selects the 25.11 channel), the CPU and GPU vendor, virtualization, a
   battery, a TPM and a LUKS root. You confirm or override each.
2. **Asks** what it can't detect: hostname, username, session role
   (`headless` / `desktop` / `gaming-kiosk`), laptop power management,
   multi-monitor, gaming extras (Steam on x86, muvm + FEX on Apple Silicon),
   TPM2 disk unlock, Secure Boot, and whether to allow unfree software.
3. **Writes** `/etc/nixos/flake.nix` (the module list), `host.nix` (kept on
   re-runs), and copies `hardware-configuration.nix` into place.
4. **Prepares** the user side: wallpaper, a LazyVim starter in
   `~/dotfiles/nvim` if missing, user lingering, and Secure Boot keys (`sbctl
   create-keys`) when Secure Boot was selected.
5. **Builds**: `nixos-rebuild boot` + reboot on a fresh install, `switch` on
   a reconfigure. On Apple Silicon with gaming, it builds in two stages so the
   x86 binfmt emulation is in place before the gaming role needs it.

## Disk encryption and Secure Boot

`secure-boot.nix` and `tpm-fde.nix` handle the declarative side. Key
enrollment is manual on purpose, because the order matters: create keys →
rebuild → enroll them in firmware Setup Mode (`sbctl enroll-keys
--microsoft`) → enable Secure Boot → only then bind LUKS to TPM PCR 7 with a
PIN (`systemd-cryptenroll --tpm2-with-pin=yes`). The header comment in each
module has the full procedure, including suspending BitLocker on dual-boot
disks. With an encrypted root, the desktop role skips the second login
prompt: the LUKS passphrase or TPM PIN already guards the machine, and
hyprlock still covers idle and suspend.

## Themes

All of Omarchy's themes, read from upstream (the pinned `omarchy` flake
input): catppuccin, catppuccin-latte, ethereal, everforest, flexoki-light,
gruvbox, hackerman, kanagawa, last-horizon, lumon, lupine, matte-black,
miasma, nord, osaka-jade, retro-82, ristretto, rose-pine, solitude,
tokyo-night, vantablack and white. `nix flake update omarchy` picks up new
ones.

Pick one in Style › Theme (a grid of the themes' preview images) or with
`omarchy-theme-set <name>`. The choice is written to
`modules/omarchy/theme.json` and the system rebuilds. The layout on disk
matches Omarchy's:

```
~/.config/omarchy/themes/<name>/     every theme: colors.toml, backgrounds/, preview.png, neovim.lua, …
~/.config/omarchy/current/theme  →   the active theme's directory
```

`modules/omarchy/theme.nix` reads each theme's `colors.toml` and applies
Omarchy's fallback rules for missing keys. It then drives:

- **Hyprland** borders (accent), **kitty** (ANSI 16, mapped like Omarchy's
  kitty template), **rofi**, **swaync**, **hyprlock**, the **Quickshell**
  bar and the **starship** prompt, through `modules/home/colors.nix`
- **Stylix** (`modules/common/stylix.nix`): a base16 scheme and light/dark
  polarity from the theme, for GTK, Qt, console, bat, btop, fzf, Chromium,
  VS Code, Vencord, …
- **Neovim**: `~/dotfiles/nvim/lua/plugins/colorscheme.lua` loads the
  active theme's `neovim.lua` (LazyVim spec). Themes that don't ship one get
  the aether.nvim spec Omarchy generates from the palette. Restart Neovim
  after switching.
- **Wallpaper**: the theme's first background. Style › Background picks
  from the theme's set or from loose files in `~/Wallpapers`.

## Notes

- Conflicting choices get a warning from the bootstrap: without unfree
  software, NVIDIA falls back to nouveau and Steam or the kiosk won't install.
- SSH is key-only; `~/.ssh/authorized_keys` is used if present.
- Tailscale is on everywhere; run `sudo tailscale up` once per host.
- `hardware-configuration.nix`, `host.nix`, `/etc/nas-credentials` and the
  Secure Boot keys in `/var/lib/sbctl` are per machine and never in the repo.
