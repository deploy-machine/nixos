{ config, lib, username, ... }:
{
  # Per-host monitor layout. Real output names (DP-1, HDMI-A-1, …) are only
  # knowable post-boot — after first boot, run `hyprctl monitors` and set
  # `profile.monitorsLua` in hosts/<hostname>/default.nix. The hyprland.lua
  # config sources ~/.config/hypr/monitors.lua via pcall(dofile, ...).
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
    description = "Lua written to ~/.config/hypr/monitors.lua, sourced by the main Hyprland config.";
  };

  config.home-manager.users.${username}.xdg.configFile."hypr/monitors.lua".text =
    config.profile.monitorsLua;
}
