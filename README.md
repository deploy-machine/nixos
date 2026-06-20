# milkoutside / cybr — declarative NixOS rice

A single-machine NixOS configuration for a Hyprland desktop themed end-to-end
with the **milkoutside** palette (pink/cyan on near-black). The whole system
— bootloader, audio, networking, login manager, window manager, bar, terminal,
launcher, notifications, shell, prompt, editor, file manager, Discord — is
declared in this repo and brought up by `./run.sh`.

## Stack

| Layer | Piece |
| --- | --- |
| OS | NixOS 26.05 (channel `nixos-unstable` exposed as `<unstable>` for cherry-picks) |
| Login | `greetd` booting straight into a headless-aware Hyprland session, `tuigreet` as fallback |
| WM | Hyprland 0.55+ (native Lua config), with `wayvnc` exposing the headless display on `:5900` |
| Bar | Waybar (hand-tuned powerline, milkoutside palette) |
| Notifications | swaync (custom CSS) |
| Terminal | kitty + GeistMono / JetBrainsMono Nerd Fonts |
| Launcher | rofi (`drun`, milkoutside `.rasi`) |
| Shell | zsh + starship (cybr "lucid" prompt recoloured) |
| CLI sugar | lsd, bat, fzf, zoxide, yazi, lazygit, dust, duf, procs, gping, glow, onefetch, tealdeer, delta |
| Editor | Neovim + LazyVim, with config kept editable at `~/dotfiles/nvim` (out-of-store symlink) |
| Discord | Nixcord (declarative Vencord) |
| Theming | Stylix drives GTK, Qt, console, cursor, bat, btop, cava, fzf, mpv, firefox, chromium, vscode, Vencord… from one base16 palette |
| User env | Home-Manager via the NixOS module (`home-manager.users.simbaclaws = import ./home.nix`) |

## Layout

```
configuration.nix   # system: bootloader, networking, users, greetd, pipewire, system packages, home-manager hook
hardware-configuration.nix  # per-machine (gitignored, copied in by run.sh)
home.nix            # home-manager entry point — imports every user-level module
hyprland.nix        # ~/.config/hypr/hyprland.lua (native Lua, not the HM Lua generator)
waybar.nix          # bar config + CSS
desktop.nix         # kitty, rofi, swaync (the bespoke milkoutside surfaces Stylix is told to skip)
shell.nix           # zsh + cybr starship prompt
cli.nix             # modern CLI tooling (lsd/bat/fzf/zoxide/yazi/lazygit/…)
neovim.nix          # neovim package + out-of-store symlink to ~/dotfiles/nvim
nixcord.nix         # Vencord via the nixcord home module
stylix.nix          # base16 palette, fonts, cursor; auto-themes everything not opted out
colors.nix          # palette constants shared by hand-tuned modules
run.sh              # bootstrap (channels, hardware config, symlink /etc/nixos, nixos-rebuild)
```

## How the theming is split

Stylix auto-enables every supported target. The hand-tuned modules (waybar,
kitty, rofi, swaync, hyprland, neovim, starship, nixcord — well, nixcord stays
on) are excluded in `home.nix` so Stylix doesn't fight their own configs. The
upshot: one base16 palette in `stylix.nix` themes ~30 apps automatically;
the six modules that already had bespoke milkoutside configs keep them.

## Bootstrap

On a fresh NixOS install:

```bash
git clone <this repo> ~/Projects/nixos
cd ~/Projects/nixos
./run.sh
```

`run.sh` is idempotent. It:

1. Copies `/etc/nixos/hardware-configuration.nix` into the repo (gitignored).
2. Renames the old `/etc/nixos` to `/etc/nixos.bak.<timestamp>` and symlinks
   `/etc/nixos` to this repo, so future `nixos-rebuild` runs read this tree.
3. Adds the channels the imports need:
   - `unstable` → `nixos-unstable` (referenced as `<unstable>` in
     `configuration.nix`)
   - `home-manager` → `release-26.05` (referenced as `<home-manager/nixos>`)
   - `stylix` → `release-26.05` (referenced as `<stylix>`)
   Nixcord is fetched inline via `builtins.fetchTarball`, so no channel.
4. Clones the LazyVim starter into `~/dotfiles/nvim` and drops in the
   milkoutside colorscheme plus a Mason-disabling shim (LSP servers come from
   Nix, not Mason).
5. Runs `sudo nixos-rebuild switch`.

Log out / reboot afterwards to land in the Hyprland session greetd starts.

## Day-to-day

Edit any `.nix` file in this repo, then:

```bash
sudo nixos-rebuild switch
```

To bump channels:

```bash
sudo nix-channel --update && sudo nixos-rebuild switch
```

LazyVim plugins update via `:Lazy sync` inside Neovim — the config at
`~/dotfiles/nvim` is editable and not managed by Nix.

## Notes

- `hardware-configuration.nix` is **gitignored** — it's per-machine. The first
  `./run.sh` on a new box copies it from `/etc/nixos`.
- The user `simbaclaws` is hard-coded across `configuration.nix`, `home.nix`,
  and the systemd units. Search/replace if forking.
- SSH is key-only (`/home/simbaclaws/.ssh/authorized_keys`); the firewall opens
  `22` and `5900` (the latter for wayvnc).
- `sudo` is passwordless for `simbaclaws` (`wheel` + `NOPASSWD: ALL`).
- The greetd `initial_session` runs a headless-friendly Hyprland (`WLR_BACKENDS=headless`,
  `WLR_LIBINPUT_NO_DEVICES=1`) so the box comes up usable over VNC even with no
  monitor attached.
