# milkoutside / cybr — modular NixOS toolkit

A **host-agnostic** library of NixOS modules — hardware (CPU/GPU/VM-guest),
deployment role (headless/desktop/gaming-kiosk + laptop/multi-monitor/gaming),
and a shared user/theming layer (Hyprland, Waybar, Stylix, Nixcord, LazyVim,
zsh+starship). An interactive bootstrap (`./run.sh`) detects the machine's
hardware, asks the deployment questions a script can't sniff, and writes a
per-machine `/etc/nixos/{flake,host,hardware-configuration}.nix` that composes
the right modules.

**Per-host config never lands in the repo.** The repo is just the modules + the
bootstrap. Each machine owns its `/etc/nixos/` and pins this repo as a flake
input (`path:/path/to/this/repo`).

## Layout

```
flake.nix              # exposes lib.mkHost + nixosModules.{common,hardware,roles}
run.sh                 # interactive bootstrap
nixos.png              # default wallpaper (copied to ~/Wallpapers by bootstrap)

modules/
  common/              # always-on system layer
    base.nix           # bootloader, network, locales, audio, hyprland, ssh, nix.settings
    users.nix          # the primary user (username from specialArgs)
    packages.nix       # system packages; FOSS always + unfree gated on allowUnfree
    stylix.nix         # system-level Stylix import + base16 palette
    home-manager.nix   # wires home-manager.users.<username> = import ../home

  hardware/            # opt-in per-machine
    cpu-intel.nix      cpu-amd.nix
    gpu-intel.nix      gpu-amd.nix      gpu-nvidia.nix
    vm-hyperv.nix      vm-qemu.nix      vm-vmware.nix      vm-virtualbox.nix

  roles/               # opt-in by deployment shape
    headless.nix       # greetd hypr-headless, wayvnc, hypremote, virt-1 monitor
    desktop.nix        # normal greetd login → Hyprland
    laptop.nix         # tlp, lid switch, brightnessctl/light, powertop
    multi-monitor.nix  # profile.monitorsLua option → ~/.config/hypr/monitors.lua
    gaming.nix         # steam, gamemode, gamescope, mangohud, xpadneo, bluetooth
    gaming-kiosk.nix   # imports gaming, replaces greetd with Steam Big Picture

  home/                # user-level, applied through home-manager
    default.nix        # imports the others, sets home.username/homeDirectory
    hyprland.nix       # native-Lua hyprland config (sources ~/.config/hypr/monitors.lua)
    waybar.nix         # bespoke milkoutside powerline bar
    desktop.nix        # kitty / rofi / swaync
    shell.nix          # zsh + cybr starship prompt
    neovim.nix         # neovim package + ~/.config/nvim out-of-store symlink to LazyVim
    cli.nix            # lsd / bat / fzf / zoxide / yazi / lazygit / …
    nixcord.nix        # Vencord via nixcord home module (gated on allowUnfree)
    stylix.nix         # opts the bespoke modules out of Stylix theming
    colors.nix         # milkoutside palette consts
```

## Bootstrap

On a fresh NixOS install (or any time you want to (re)configure a host):

```bash
git clone <this repo> ~/Projects/nixos
cd ~/Projects/nixos
./run.sh
```

`run.sh` is interactive and idempotent. It will:

1. **Detect** CPU vendor (`/proc/cpuinfo`), GPU vendor (`lspci`),
   virtualization (`systemd-detect-virt`), and battery presence. You confirm
   or override each.
2. **Ask** the deployment questions:
   - **Hostname** and **primary username** (defaults to current values)
   - **Session role** — `headless` (greetd boots straight into headless
     Hyprland + wayvnc on :5900), `desktop` (normal Hyprland login), or
     `gaming-kiosk` (auto-login into Steam Big Picture via gamescope)
   - **Laptop power mgmt** (TLP, lid switch — suggested when a battery is
     detected)
   - **Multi-monitor** — writes a `profile.monitorsLua` stub you fill in after
     first boot once you know your output names
   - **Gaming extras** — Steam, gamemode, gamescope, mangohud, xpadneo
     (Xbox-pad Bluetooth), Bluetooth stack
   - **Allow proprietary software** — flips `nixpkgs.config.allowUnfree`
3. **Generate** `/etc/nixos/flake.nix` (inputs this repo as a `path:` flake
   input), `/etc/nixos/host.nix` (hostname + `allowUnfree`), and copies the
   hardware config in place.
4. **Build & switch** via `sudo nixos-rebuild switch --flake /etc/nixos#<hostname>`.

Future rebuilds, no script needed:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#<hostname>
```

Re-run `./run.sh` whenever you want to change role / hardware / unfree-policy
selection — it overwrites `/etc/nixos/{flake,host}.nix` and preserves
`hardware-configuration.nix`.

## Hardware modules

| Module | What it does |
| --- | --- |
| `cpu-intel` / `cpu-amd` | microcode + matching KVM module |
| `gpu-intel` | `hardware.graphics` + `intel-media-driver`, `LIBVA_DRIVER_NAME=iHD` |
| `gpu-amd` | `hardware.graphics` + `amdvlk` + ROCm OpenCL ICD |
| `gpu-nvidia` | proprietary driver + `nvidia-drm modeset` + Wayland env vars (`GBM_BACKEND=nvidia-drm`, …). Requires `allowUnfree`. |
| `vm-hyperv` | Hyper-V integration services (`virtualisation.hypervGuest.enable`) |
| `vm-qemu` | `qemuGuest` + `spice-vdagentd` (clipboard, resolution sync) |
| `vm-vmware` | `virtualisation.vmware.guest` (open-vm-tools) |
| `vm-virtualbox` | guest additions with drag-and-drop |

## Role modules

| Module | Mutex group | Notes |
| --- | --- | --- |
| `headless` | session | wlroots headless backend, wayvnc on :5900, `hypremote` keeps virt-1 at 1920x1080@60 across rebuilds |
| `desktop` | session | tuigreet → `uwsm start hyprland-uwsm.desktop` |
| `gaming-kiosk` | session | imports `gaming`, greetd auto-logs into `gamescope --steam -- steam -gamepadui` |
| `laptop` | orthogonal | TLP, suspend-on-lid, light/brightnessctl, powertop |
| `multi-monitor` | orthogonal | adds `profile.monitorsLua` option; main hyprland.lua sources `~/.config/hypr/monitors.lua` via `pcall(dofile,...)` |
| `gaming` | orthogonal | steam, gamescope, gamemode, mangohud, xpadneo, Bluetooth, blueman. Steam self-gates on `allowUnfree`. |

## Theming

Stylix drives every supported app from one base16 palette (in
`modules/common/stylix.nix`). The hand-tuned modules with bespoke configs
(waybar, kitty, rofi, swaync, hyprland, neovim, starship) are excluded in
`modules/home/stylix.nix` so Stylix doesn't fight their own configs. Nixcord
(Vencord) is auto-themed by the Stylix nixcord target.

## Notes

- The bootstrap warns about conflicting choices (`allowUnfree=false` +
  NVIDIA → falls back to nouveau; `allowUnfree=false` + gaming → Steam won't
  install; `allowUnfree=false` + `gaming-kiosk` → kiosk session can't start).
- SSH is key-only. The user module looks for
  `/home/<username>/.ssh/authorized_keys` and uses it if present.
- Passwordless sudo for the primary user.
- The flake inputs follow the same `nixpkgs` across all of `home-manager`,
  `stylix`, and `nixcord` so the closure is consistent.
- `hardware-configuration.nix` is machine-specific and lives only in
  `/etc/nixos/` — never in the repo.
