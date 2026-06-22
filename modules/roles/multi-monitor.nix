{ config, lib, pkgs, username, ... }:
let
  # Match the Hyprland version split in modules/home/hyprland.nix: 25.11
  # ships 0.52 (.conf only); 26.05 ships 0.55+ (.lua only).
  isAsahi = pkgs.stdenv.hostPlatform.isAarch64;
in
{
  # Per-host monitor layout. Real output names (DP-1, HDMI-A-1, …) are only
  # knowable post-boot — after first boot, run `hyprctl monitors` and set
  # either `profile.monitorsLua` (x86 / 26.05) or `profile.monitorsConf`
  # (Asahi / 25.11) in /etc/nixos/host.nix. The main Hyprland config sources
  # whichever file matches its format.
  options.profile.monitorsLua = lib.mkOption {
    type = lib.types.lines;
    default = ''
      -- Discover output names with `hyprctl monitors`, then add one line per
      -- output. Reload Hyprland (Super+Shift+R or `hyprctl reload`) after.
      -- Set position explicitly so left → right matches your physical layout
      -- — autoPinWorkspaces() in modules/home/hyprland.nix sorts monitors by
      -- x to decide which gets ws 1-3 vs 4-6 vs 7-9 (etc.). It needs no
      -- per-host pinning; if you want to override a specific workspace, add
      -- an extra hl.workspace_rule call below — last write wins.
      --
      --   hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",  position = "0x0",    scale = 1 })
      --   hl.monitor({ output = "DP-2",     mode = "1920x1080@240", position = "1920x0", scale = 1 })
      --   hl.monitor({ output = "DP-1",     mode = "1920x1080@60",  position = "3840x0", scale = 1 })
    '';
    description = "Lua written to ~/.config/hypr/monitors.lua, sourced by the Hyprland .lua config (26.05 / x86).";
  };

  options.profile.monitorsConf = lib.mkOption {
    type = lib.types.lines;
    default = ''
      # Discover output names with `hyprctl monitors`, then add one line per
      # output. Reload Hyprland ($mainMod+SHIFT+R or `hyprctl reload`) after.
      # Set position explicitly so left → right matches your physical layout
      # — hypr-pin-workspaces (autostarted by hyprland.conf) sorts monitors
      # by x to decide which gets ws 1-3 vs 4-6 vs 7-9 (etc.). Per-workspace
      # overrides go in extra `workspace = N,monitor:...` lines below.
      #
      #   monitor = HDMI-A-1, 1920x1080@60,  0x0,    1
      #   monitor = DP-2,     1920x1080@240, 1920x0, 1
      #   monitor = DP-1,     1920x1080@60,  3840x0, 1
    '';
    description = "Hyprland .conf written to ~/.config/hypr/monitors.conf, sourced by the Hyprland .conf config (25.11 / Asahi).";
  };

  config.home-manager.users.${username}.xdg.configFile = lib.mkMerge [
    (lib.mkIf isAsahi    { "hypr/monitors.conf".text = config.profile.monitorsConf; })
    (lib.mkIf (!isAsahi) { "hypr/monitors.lua".text  = config.profile.monitorsLua;  })
  ];
}
