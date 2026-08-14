{ config, lib, pkgs, inputs, ... }:
let
  # claude-code moves faster than either release channel — new model IDs
  # (e.g. Fable) ship in the CLI within days, but the release-branch backport
  # can lag by weeks. Sourcing this one package from nixos-unstable keeps the
  # CLI current without bumping the whole system closure.
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in
{
  environment.systemPackages = with pkgs;
    # Always present (FOSS).
    [
      neovim gh git curl wget unzip
      gcc gnumake ripgrep fd tree-sitter
      yubikey-manager   # `ykman` — pairs with services.pcscd in base.nix

      nixd alejandra
      lua-language-server stylua

      waybar libnotify swaynotificationcenter kitty rofi networkmanagerapplet
      teams-for-linux
      # Wallpaper daemon: `awww` is the rename of `swww` upstream (26.05).
      # 25.11 still ships `swww`; fall back so this evaluates on both.
      (pkgs.awww or pkgs.swww)
    ]
    # Proprietary extras. Skipped automatically when the host opted out of
    # unfree software (nixpkgs.config.allowUnfree = false).
    ++ lib.optionals config.nixpkgs.config.allowUnfree [
      unstable.claude-code
      chromium
    ];
}
