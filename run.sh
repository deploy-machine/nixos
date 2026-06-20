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
  if ask_yn "Multi-monitor (writes a profile.monitorsLua stub you edit post-boot)?" n; then
    multi_monitor=y
  else
    multi_monitor=n
  fi
fi

if [ "$role" = "gaming-kiosk" ]; then
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
modules+=("config-repo.nixosModules.roles.$role")
[ "$laptop"        = "y" ] && modules+=("config-repo.nixosModules.roles.laptop")
[ "$multi_monitor" = "y" ] && modules+=("config-repo.nixosModules.roles.multi-monitor")
[ "$gaming"        = "y" ] && [ "$role" != "gaming-kiosk" ] && modules+=("config-repo.nixosModules.roles.gaming")

{
  cat <<EOF
{
  description = "Per-machine NixOS config for $hostname. Generated by $(basename "$0") on $TS. Edit host.nix for per-machine overrides; re-run the bootstrap to change role/hardware module selection.";

  inputs.config-repo.url = "path:$REPO_DIR";

  outputs = { self, config-repo }: {
    nixosConfigurations."$hostname" = config-repo.lib.mkHost {
      hostname = "$hostname";
      username = "$username";
      system   = "x86_64-linux";
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

ok "Wrote $NIXOS_DIR/flake.nix and $NIXOS_DIR/host.nix"

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

# --- 10. build & switch -----------------------------------------------------
# First-run rebuild needs flake features on the CLI; subsequent rebuilds
# inherit them from modules/common/base.nix's nix.settings.
ok "Building the system. First run downloads everything; expect a wait."
sudo nixos-rebuild switch \
  --flake "$NIXOS_DIR#$hostname" \
  --option experimental-features "nix-command flakes"

echo
bold "Bootstrap complete."
echo "Future rebuilds: sudo nixos-rebuild switch --flake /etc/nixos#$hostname"
echo "Re-run this script to change role/hardware module selection."
if [ "$multi_monitor" = "y" ]; then
  echo
  echo "Multi-monitor: after first boot, run \`hyprctl monitors\` to discover"
  echo "output names, then set profile.monitorsLua in /etc/nixos/host.nix."
fi
