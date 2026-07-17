{ lib, pkgs, username, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./desktop.nix
    ./neovim.nix
    ./shell.nix
    ./cli.nix
    ./nixcord.nix
    ./stylix.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  # Default to the x86 host's install release. The Apple Silicon NixOS
  # module pins this back to "25.11" via home-manager.users.<user>.home — the
  # 25.11 HM module rejects values newer than its own release.
  home.stateVersion = lib.mkDefault "26.05";

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nerd-fonts.geist-mono     # cybr/Stylix monospace: bar, prompt, terminal glyphs
    nerd-fonts.jetbrains-mono # kept as a secondary monospace
    nerd-fonts.symbols-only   # glyph fallback so no icon ever renders as tofu
    cava                      # audio visualizer
    fastfetch                 # system info
    # btop moved to cli.nix as programs.btop.enable so Stylix themes it.
  ];
}
