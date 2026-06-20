{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs;
    # Always present (FOSS).
    [
      neovim gh git curl wget unzip
      gcc gnumake ripgrep fd tree-sitter

      nixd alejandra
      lua-language-server stylua

      waybar libnotify swaynotificationcenter awww kitty rofi networkmanagerapplet

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
