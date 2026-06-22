{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs;
    # Always present (FOSS).
    [
      neovim gh git curl wget unzip
      gcc gnumake ripgrep fd tree-sitter

      nixd alejandra
      lua-language-server stylua

      waybar libnotify swaynotificationcenter kitty rofi networkmanagerapplet
      # Wallpaper daemon: `awww` is the rename of `swww` upstream (26.05).
      # 25.11 still ships `swww`; fall back so this evaluates on both.
      (pkgs.awww or pkgs.swww)

      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-wlr
    ]
    # Proprietary extras. Skipped automatically when the host opted out of
    # unfree software (nixpkgs.config.allowUnfree = false).
    ++ lib.optionals config.nixpkgs.config.allowUnfree [
      claude-code
      chromium
    ];
}
