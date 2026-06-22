#!/usr/bin/env bash
# Interactive NixOS bootstrap. Detects hardware (CPU/GPU/VM), asks deployment-
# shape questions a script can't sniff (session role, laptop, multi-monitor,
# gaming, unfree policy), then generates a per-machine /etc/nixos/{flake,host,
# hardware-configuration}.nix that pulls modules from this repo via a flake
# input. Nothing host-specific is written to the repo.
#
# After first run, future rebuilds are just `sudo nixos-rebuild switch --flake
# /etc/nixos#<hostname>`. Re-run this script to reconfigure a host (e.g. add
# the gaming role) — it overwrites /etc/nixos/{flake,host}.nix in place and
# preserves hardware-configuration.nix.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
NIXOS_DIR=/etc/nixos

# --no-rebuild stops after writing /etc/nixos/{flake,host,hardware-configuration}.nix.
# Useful for inspecting the generated config and running `nixos-rebuild dry-build`
# manually before touching the running system. The activation step (`nixos-rebuild
# boot|switch`) is skipped.
no_rebuild=n
for arg in "$@"; do
  case "$arg" in
    --no-rebuild|--dry|-n) no_rebuild=y ;;
    -h|--help)
      echo "Usage: $0 [--no-rebuild]"
      echo "  --no-rebuild  write /etc/nixos/{flake,host}.nix but skip nixos-rebuild"
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

# --- helpers ----------------------------------------------------------------
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m==>\033[0m %s\n' "$*"; }

ask() {
  local prompt="$1" default="$2" answer
  read -rp "$prompt [$default]: " answer </dev/tty
  echo "${answer:-$default}"
}

ask_yn() {
  local prompt="$1" default="$2" answer hint
  case "$default" in y|Y) hint="Y/n";; *) hint="y/N";; esac
  read -rp "$prompt [$hint]: " answer </dev/tty
  answer="${answer:-$default}"
  case "$answer" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

ask_choice() {
  # ask_choice <prompt> <default> opt1 opt2 ...
  # Menu lines go to /dev/tty so they're visible even when the function's
  # stdout is captured via $(...).
  local prompt="$1" default="$2"; shift 2
  local opts=("$@") i answer
  echo "$prompt" > /dev/tty
  for i in "${!opts[@]}"; do
    local mark=''
    [ "${opts[$i]}" = "$default" ] && mark=' (default)'
    printf '  %d) %s%s\n' "$((i+1))" "${opts[$i]}" "$mark" > /dev/tty
  done
  read -rp "choice (number, name, or Enter for default): " answer </dev/tty
  if [ -z "$answer" ]; then echo "$default"; return; fi
  if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le "${#opts[@]}" ]; then
    echo "${opts[$((answer-1))]}"; return
  fi
  echo "$answer"
}

# --- 0. sanity --------------------------------------------------------------
if ! command -v nixos-rebuild >/dev/null 2>&1; then
  echo "error: nixos-rebuild not found — this script is for NixOS." >&2
  exit 1
fi

# --- 1. hardware detection --------------------------------------------------
bold "Hardware detection"

# Architecture is the first fork: aarch64 is currently only meaningful for
# Apple Silicon (Asahi). Detect via /proc/device-tree/compatible — Asahi
# always exposes one populated with "apple,<soc>" entries.
arch_raw="$(uname -m)"
case "$arch_raw" in
  x86_64)  nix_system=x86_64-linux ;;
  aarch64) nix_system=aarch64-linux ;;
  *)       nix_system=x86_64-linux ;;  # fallback; user can edit /etc/nixos/flake.nix
esac
apple_silicon=n
if [ -f /proc/device-tree/compatible ] && grep -aq apple /proc/device-tree/compatible 2>/dev/null; then
  apple_silicon=y
fi
# Per-host nixpkgs channel. Asahi installer + binary cache are pinned to
# 25.11; the x86 host defaults to 26.05. mkHost looks this up to pick the
# matching home-manager + stylix release branches.
if [ "$apple_silicon" = "y" ]; then
  channel=25.11
else
  channel=26.05
fi
echo "  arch       : $arch_raw -> $nix_system"
echo "  Apple SoC  : $apple_silicon"
echo "  channel    : $channel"

if [ "$apple_silicon" = "y" ]; then
  # The Asahi kernel/firmware/Mesa stack subsumes the per-vendor CPU/GPU/VM
  # modules — picking gpu-amd on an M1 would be incoherent. Force-skip the
  # menus so we can't end up with a broken combination.
  cpu_choice=none
  gpu_choice=none
  vm_choice=none
  echo "  (skipping CPU/GPU/VM menus — Apple Silicon module owns those)"
else
  cpu_raw="$(awk -F: '/vendor_id/{gsub(/ /,"",$2); print $2; exit}' /proc/cpuinfo)"
  case "$cpu_raw" in
    GenuineIntel) cpu_detected=intel ;;
    AuthenticAMD) cpu_detected=amd ;;
    *)            cpu_detected=none ;;
  esac
  echo "  CPU vendor : $cpu_raw -> $cpu_detected"
  cpu_choice="$(ask_choice "Select CPU module:" "$cpu_detected" intel amd none)"

  gpu_line="$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)"
  gpu_detected=none
  # Match unambiguous vendor strings only. Earlier versions used '|amd|ati' but
  # 'ati' matches "comp[ati]ble" inside lspci's "VGA compatible controller"
  # prefix, so every system got falsely flagged AMD.
  echo "$gpu_line" | grep -qi 'intel corporation'   && gpu_detected=intel
  echo "$gpu_line" | grep -qi 'advanced micro devices' && gpu_detected=amd
  echo "$gpu_line" | grep -qi 'nvidia corporation'  && gpu_detected=nvidia
  echo "  GPU        : $gpu_detected"
  [ -n "$gpu_line" ] && echo "$gpu_line" | sed 's/^/    /'
  gpu_choice="$(ask_choice "Select GPU module:" "$gpu_detected" intel amd nvidia none)"

  virt="$(systemd-detect-virt 2>/dev/null || echo none)"
  case "$virt" in
    microsoft) vm_detected=hyperv ;;
    vmware)    vm_detected=vmware ;;
    oracle)    vm_detected=virtualbox ;;
    kvm|qemu)  vm_detected=qemu ;;
    *)         vm_detected=none ;;
  esac
  echo "  VM         : systemd-detect-virt=$virt -> $vm_detected"
  vm_choice="$(ask_choice "Select VM guest-tools module:" "$vm_detected" hyperv qemu vmware virtualbox none)"
fi

# --- 2. deployment questions ------------------------------------------------
echo
bold "Deployment"

current_host="$(hostname 2>/dev/null || echo nixos)"
hostname="$(ask "Hostname" "$current_host")"

current_user="$(id -un)"
username="$(ask "Primary username" "$current_user")"

role="$(ask_choice "Session role (mutex):" headless headless desktop gaming-kiosk)"

laptop_default=n
if ls /sys/class/power_supply/ 2>/dev/null | grep -qi 'BAT'; then laptop_default=y; fi
if ask_yn "Laptop power management (TLP, lid switch)?" "$laptop_default"; then laptop=y; else laptop=n; fi

if [ "$role" = "headless" ]; then
  multi_monitor=n
  echo "  (skipping multi-monitor — headless role)"
else
  # If a previous run.sh wrote a host.nix that's setting profile.monitorsLua,
  # default to y — otherwise the regenerated flake.nix would drop the
  # multi-monitor module and the preserved host.nix would no longer evaluate.
  mm_default=n
  if [ -f "$NIXOS_DIR/host.nix" ] && grep -q '^\s*profile\.monitorsLua\b\|profile = {' "$NIXOS_DIR/host.nix" 2>/dev/null; then
    mm_default=y
  fi
  if ask_yn "Multi-monitor (writes a profile.monitorsLua stub you edit post-boot)?" "$mm_default"; then
    multi_monitor=y
  else
    multi_monitor=n
  fi
fi

if [ "$apple_silicon" = "y" ]; then
  # The x86 gaming role's stack (Steam, Proton, gamescope-session, proton-ge-bin)
  # is x86_64-only in nixpkgs. On Apple Silicon the canonical path is muvm +
  # FEX, packaged separately as roles.gaming-asahi.
  if [ "$role" = "gaming-kiosk" ]; then
    warn "gaming-kiosk is x86_64-only — falling back to desktop role."
    role=desktop
  fi
  if ask_yn "Gaming extras (muvm + FEX, controllers, bluetooth)?" n; then
    gaming=y
  else
    gaming=n
  fi
elif [ "$role" = "gaming-kiosk" ]; then
  gaming=y
  echo "  (gaming extras forced on — implied by gaming-kiosk)"
else
  if ask_yn "Gaming extras (steam, gamescope, mangohud, controllers, bluetooth)?" n; then
    gaming=y
  else
    gaming=n
  fi
fi

if ask_yn "Allow proprietary (unfree) software (NVIDIA, Steam, Discord, chromium, claude-code)?" y; then
  unfree=true
else
  unfree=false
fi

# Conflict warnings
if [ "$unfree" = "false" ] && [ "$gpu_choice" = "nvidia" ]; then
  warn "NVIDIA driver is proprietary; with allowUnfree=false the system falls back to nouveau (slower, partial Wayland support)."
fi
if [ "$unfree" = "false" ] && [ "$gaming" = "y" ]; then
  warn "Steam is unfree; with allowUnfree=false steam won't enable. Lutris (FOSS) still installs."
fi
if [ "$unfree" = "false" ] && [ "$role" = "gaming-kiosk" ]; then
  warn "gaming-kiosk auto-logs into Steam Big Picture; with allowUnfree=false the kiosk session can't start. Consider 'desktop' role or enable unfree."
fi

# --- 3. summary + confirm ---------------------------------------------------
echo
bold "Summary"
cat <<EOF
  hostname        $hostname
  username        $username
  arch / system   $nix_system
  apple silicon   $apple_silicon
  nixpkgs channel $channel
  CPU module      $cpu_choice
  GPU module      $gpu_choice
  VM module       $vm_choice
  session role    $role
  laptop          $laptop
  multi-monitor   $multi_monitor
  gaming extras   $gaming
  allow unfree    $unfree
EOF
echo
ask_yn "Proceed? This will write to /etc/nixos and run nixos-rebuild switch." y \
  || { echo "aborted."; exit 1; }

# --- 4. take /etc/nixos out of symlink mode if needed ----------------------
# Earlier versions of this script symlinked /etc/nixos to the repo. The new
# design owns /etc/nixos as a real directory holding the per-machine flake.
if [ -L "$NIXOS_DIR" ]; then
  sudo rm "$NIXOS_DIR"
  ok "Removed legacy /etc/nixos symlink"
fi
sudo mkdir -p "$NIXOS_DIR"

# --- 5. locate hardware-configuration.nix and copy into /etc/nixos ---------
if [ ! -f "$NIXOS_DIR/hardware-configuration.nix" ]; then
  hw_src=""
  for cand in \
      "$NIXOS_DIR/hardware-configuration.nix" \
      "$REPO_DIR/hardware-configuration.nix"; do
    [ -f "$cand" ] && hw_src="$cand" && break
  done
  if [ -z "$hw_src" ]; then
    for backup in /etc/nixos.bak.*/hardware-configuration.nix; do
      [ -f "$backup" ] && hw_src="$backup" && break
    done
  fi
  if [ -z "$hw_src" ]; then
    ok "Generating hardware-configuration.nix via nixos-generate-config ..."
    tmp="$(mktemp -d)"
    sudo nixos-generate-config --root / --dir "$tmp"
    hw_src="$tmp/hardware-configuration.nix"
  fi
  sudo cp "$hw_src" "$NIXOS_DIR/hardware-configuration.nix"
  ok "hardware-configuration.nix copied from $hw_src"
fi

# --- 6. write /etc/nixos/host.nix (per-machine overrides) -------------------
# Only generate a starter host.nix on first run. Re-runs preserve any
# hand-edits the user has made (monitor layouts, additional overrides, etc.).
# To regenerate from scratch, delete /etc/nixos/host.nix first.
if [ -f "$NIXOS_DIR/host.nix" ]; then
  ok "Keeping existing $NIXOS_DIR/host.nix (delete it to regenerate)."
else
  sudo tee "$NIXOS_DIR/host.nix" >/dev/null <<EOF
{ ... }:
{
  networking.hostName = "$hostname";

  # Proprietary software policy. Modules that depend on unfree packages
  # (claude-code, chromium, steam, nixcord/discord, nvidia) self-skip when
  # this is false.
  nixpkgs.config.allowUnfree = $unfree;
}
EOF
  ok "Wrote $NIXOS_DIR/host.nix"
fi

# --- 7. assemble the modules list and write /etc/nixos/flake.nix -----------
modules=(
  "config-repo.nixosModules.common.base"
  "config-repo.nixosModules.common.users"
  "config-repo.nixosModules.common.packages"
  "config-repo.nixosModules.common.stylix"
  "config-repo.nixosModules.common.home-manager"
)
[ "$cpu_choice" != "none" ] && modules+=("config-repo.nixosModules.hardware.cpu-$cpu_choice")
[ "$gpu_choice" != "none" ] && modules+=("config-repo.nixosModules.hardware.gpu-$gpu_choice")
[ "$vm_choice"  != "none" ] && modules+=("config-repo.nixosModules.hardware.vm-$vm_choice")
[ "$apple_silicon" = "y" ] && modules+=("config-repo.nixosModules.hardware.apple-silicon")
modules+=("config-repo.nixosModules.roles.$role")
[ "$laptop"        = "y" ] && modules+=("config-repo.nixosModules.roles.laptop")
[ "$multi_monitor" = "y" ] && modules+=("config-repo.nixosModules.roles.multi-monitor")
if [ "$gaming" = "y" ] && [ "$role" != "gaming-kiosk" ]; then
  if [ "$apple_silicon" = "y" ]; then
    modules+=("config-repo.nixosModules.roles.gaming-asahi")
  else
    modules+=("config-repo.nixosModules.roles.gaming")
  fi
fi

{
  cat <<EOF
{
  description = "Per-machine NixOS config for $hostname. Generated by $(basename "$0") on $TS. Edit host.nix for per-machine overrides; re-run the bootstrap to change role/hardware module selection.";

  inputs.config-repo.url = "path:$REPO_DIR";

  outputs = { self, config-repo }: {
    nixosConfigurations."$hostname" = config-repo.lib.mkHost {
      hostname = "$hostname";
      username = "$username";
      system   = "$nix_system";
      channel  = "$channel";
      extraModules = [
        ./hardware-configuration.nix
        ./host.nix
EOF
  for m in "${modules[@]}"; do printf '        %s\n' "$m"; done
  cat <<'EOF'
      ];
    };
  };
}
EOF
} | sudo tee "$NIXOS_DIR/flake.nix" >/dev/null

ok "Wrote $NIXOS_DIR/flake.nix"

# --- 8. wallpaper (referenced by modules/home/hyprland.nix's awww autostart)
if [ -f "$REPO_DIR/nixos.png" ]; then
  mkdir -p "$HOME/Wallpapers"
  cp -u "$REPO_DIR/nixos.png" "$HOME/Wallpapers/nixos.png"
fi

# --- 9. LazyVim dotfiles (out-of-store target from modules/home/neovim.nix) -
if [ ! -d "$HOME/dotfiles/nvim" ]; then
  ok "Cloning LazyVim starter into ~/dotfiles/nvim ..."
  git clone https://github.com/LazyVim/starter "$HOME/dotfiles/nvim"
  rm -rf "$HOME/dotfiles/nvim/.git"
  mkdir -p "$HOME/dotfiles/nvim/lua/plugins"

  cat > "$HOME/dotfiles/nvim/lua/plugins/colorscheme.lua" << 'LUA'
return {
  { "color-schemes/milkoutside.nvim", lazy = false, priority = 1000, opts = {} },
  { "LazyVim/LazyVim", opts = { colorscheme = "milkoutside" } },
}
LUA

  cat > "$HOME/dotfiles/nvim/lua/plugins/nixos.lua" << 'LUA'
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      for _, s in pairs(opts.servers) do
        if type(s) == "table" then s.mason = false end
      end
    end,
  },
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
}
LUA
fi

# --- 10. enable user lingering BEFORE the rebuild --------------------------
# home-manager-<user>.service runs `dconf write` during dconfSettings
# activation (Stylix's GTK target etc). dconf needs the user's session DBus
# bus, which only exists when systemd --user is running for that user. On a
# fresh install that hasn't reached a graphical login yet, the user manager
# isn't running, so the activation fails with
# "GDBus.Error.ServiceUnknown: The name is not activatable".
# `loginctl enable-linger` starts the user manager immediately AND makes it
# auto-start at boot. The users.users.<user>.linger = true in users.nix
# persists this — we run it here so the very first switch already benefits.
ok "Enabling user lingering for $username so home-manager has a live DBus session ..."
sudo loginctl enable-linger "$username"

# --- 11. refresh the config-repo lock entry --------------------------------
# /etc/nixos/flake.nix pins this repo as `path:$REPO_DIR`. nix locks path inputs
# by narHash, so once a flake.lock exists, edits to the repo are invisible to
# nixos-rebuild until the lock is refreshed. On reconfig runs we explicitly
# bump just the config-repo input; on a fresh install there's no lock yet and
# nixos-rebuild creates one.
if [ -f "$NIXOS_DIR/flake.lock" ]; then
  ok "Refreshing config-repo input in $NIXOS_DIR/flake.lock ..."
  sudo nix --extra-experimental-features "nix-command flakes" \
    flake update config-repo --flake "$NIXOS_DIR"
fi

# --- 12. build (boot for first install, switch for reconfig) ---------------
# Fresh install on a TTY can't safely live-switch: home-manager-<user>.service
# does `dconf write` for Stylix's GTK target, which needs the user's session
# DBus bus to be up and addressable in the running environment. On a fresh
# system the user manager + bus aren't reliably reachable from a system
# service running under systemd's User= directive, and the activation fails
# with "GDBus.Error.ServiceUnknown: The name is not activatable".
#
# Detect fresh-vs-reconfig by checking whether the user's home-manager system
# unit already exists (it only does after a prior successful build):
#   - fresh  -> `nixos-rebuild boot` + reboot prompt (services come up clean
#               at next boot with linger already on)
#   - reconf -> `nixos-rebuild switch` (live, no reboot needed for role
#               changes once the system is past first install)
#
# First-run rebuild needs flake features on the CLI; subsequent rebuilds
# inherit them from modules/common/base.nix's nix.settings.
# is-active is the only reliable signal — is-enabled returns true even when
# a previous failed `switch` only WROTE the unit file without ever activating
# it, which would trick us into trying switch again. home-manager's service
# is Type=oneshot with RemainAfterExit, so a successful activation leaves it
# "active"; a failed one shows "failed", and a never-run install shows
# "inactive" or "Unit not found".
if systemctl --quiet is-active "home-manager-${username}.service" 2>/dev/null; then
  rebuild_action=switch
else
  rebuild_action=boot
fi

if [ "$no_rebuild" = "y" ]; then
  impure_hint=""
  [ "$apple_silicon" = "y" ] && impure_hint=" --impure"
  echo
  bold "Dry run — skipping nixos-rebuild."
  echo "Generated files are in $NIXOS_DIR. Inspect with:"
  echo "  cat $NIXOS_DIR/flake.nix"
  echo "  cat $NIXOS_DIR/host.nix"
  echo "Then verify with a non-mutating build:"
  echo "  sudo nixos-rebuild dry-build --flake $NIXOS_DIR#$hostname$impure_hint \\"
  echo "    --option experimental-features 'nix-command flakes'"
  echo "Or build to a result symlink without activation:"
  echo "  sudo nixos-rebuild build --flake $NIXOS_DIR#$hostname$impure_hint \\"
  echo "    --option experimental-features 'nix-command flakes'"
  echo "  ls -l ./result/"
  echo "When you're ready to stage for next boot:"
  echo "  sudo nixos-rebuild boot --flake $NIXOS_DIR#$hostname$impure_hint"
  [ "$apple_silicon" = "y" ] && echo \
    "  (--impure is required: modules/hardware/apple-silicon.nix needs to" \
    && echo "   store-import /boot/asahi, which is outside the flake source.)"
  exit 0
fi

# Apple Silicon needs --impure because modules/hardware/apple-silicon.nix
# uses the path literal /boot/asahi to store-import the firmware blobs.
# /boot/asahi is outside the flake source and pure-eval forbids that.
rebuild_extra=()
[ "$apple_silicon" = "y" ] && rebuild_extra+=(--impure)

ok "Building the system ($rebuild_action). First run downloads everything; expect a wait."
sudo nixos-rebuild "$rebuild_action" \
  --flake "$NIXOS_DIR#$hostname" \
  --option experimental-features "nix-command flakes" \
  "${rebuild_extra[@]}"

echo
if [ "$rebuild_action" = "boot" ]; then
  bold "Bootstrap complete — fresh install."
  echo "The new configuration is staged as the next-boot default but is NOT"
  echo "live yet. Reboot to activate it. After the next boot, future rebuilds"
  echo "are live: sudo nixos-rebuild switch --flake /etc/nixos#$hostname"
  echo
  if ask_yn "Reboot now?" y; then sudo reboot; fi
else
  bold "Bootstrap complete."
  echo "Future rebuilds: sudo nixos-rebuild switch --flake /etc/nixos#$hostname"
  echo "Re-run this script to change role/hardware module selection."
fi
if [ "$multi_monitor" = "y" ]; then
  echo
  echo "Multi-monitor: after first boot, run \`hyprctl monitors\` to discover"
  echo "output names, then set profile.monitorsLua in /etc/nixos/host.nix."
fi
