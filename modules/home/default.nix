{ pkgs, username, ... }:
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
  home.stateVersion = "26.05";

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nerd-fonts.geist-mono     # cybr/Stylix monospace: bar, prompt, terminal glyphs
    nerd-fonts.jetbrains-mono # kept as a secondary monospace
    nerd-fonts.symbols-only   # glyph fallback so no icon ever renders as tofu
    cava                      # audio visualizer
    btop                      # system monitor
    fastfetch                 # system info
  ];
}
