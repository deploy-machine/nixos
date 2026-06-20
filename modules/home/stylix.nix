{ ... }:
{
  # Stylix auto-enables every supported target. These already have bespoke
  # milkoutside/cybr configs and would conflict or get double-themed, so
  # exclude them. EVERYTHING ELSE (gtk, qt, console, cursor, bat, btop, cava,
  # fzf, mpv, firefox, chromium, vscode, …) is themed by Stylix from the
  # palette in modules/common/stylix.nix.
  stylix.targets = {
    waybar.enable   = false;  # custom cybr powerline bar  -> waybar.nix
    kitty.enable    = false;  # milkoutside kitty          -> desktop.nix
    rofi.enable     = false;  # milkoutside rofi           -> desktop.nix
    swaync.enable   = false;  # milkoutside swaync         -> desktop.nix
    starship.enable = false;  # cybr prompt                -> shell.nix
    hyprland.enable = false;  # raw-lua hyprland, hand-coloured
    neovim.enable   = false;  # milkoutside.nvim via LazyVim
    # nixcord.enable stays true (set in nixcord.nix gated on allowUnfree).
  };
}
