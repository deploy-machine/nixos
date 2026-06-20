# /etc/nixos/stylix.nix
# System-wide theming via Stylix, driven by the milkoutside palette.
#
# Stylix is the single colour engine for everything that doesn't already have a
# bespoke milkoutside config: GTK, Qt, the TTY console, the cursor, and every
# supported app (bat, btop, cava, fzf, mpv, firefox, chromium, vscode, …).
# The hand-tuned pieces (waybar, kitty, rofi, swaync, hyprland, neovim, starship)
# are EXCLUDED in home.nix so Stylix doesn't fight their own configs.
#
# One-time channel setup (run as root, matches your NixOS 26.05):
#   sudo nix-channel --add https://github.com/nix-community/stylix/archive/release-26.05.tar.gz stylix
#   sudo nix-channel --update
#
# Then add `./stylix.nix` to the imports in configuration.nix.
{ config, pkgs, ... }:

{
  # Non-flake entry point: default.nix re-exports the flake outputs.
  imports = [ (import <stylix>).nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";

    # Because home-manager.users.simbaclaws is configured inside this system,
    # Stylix auto-imports its home-manager module and the theme below propagates
    # to your user automatically (stylix.homeManagerIntegration.autoImport).

    # --- milkoutside as a base16 scheme (hex WITHOUT '#', the base16 convention) ---
    base16Scheme = {
      base00 = "040607"; # background
      base01 = "0f0f15"; # panels / lighter background
      base02 = "292e42"; # selection
      base03 = "595959"; # comments / disabled
      base04 = "828282"; # dim foreground
      base05 = "e8e8e8"; # foreground
      base06 = "f0f0f0"; # bright foreground
      base07 = "ffffff"; # brightest
      base08 = "f93a82"; # red  <- the milkoutside accent
      base09 = "ffad00"; # orange
      base0A = "f8e063"; # yellow
      base0B = "92cf9c"; # green
      base0C = "7dcfff"; # cyan
      base0D = "63c3dd"; # blue
      base0E = "9d7cd8"; # purple
      base0F = "e79cfb"; # magenta
    };

    # base16Scheme is set, so no wallpaper is required for colour generation and
    # swww keeps ownership of the desktop background. If your Stylix ever insists
    # on an image, point it at your existing wallpaper:
    # image = /home/simbaclaws/Wallpapers/nixos.png;

    fonts = {
      # The load-bearing one: a Nerd Font as the system monospace means glyphs
      # render everywhere (terminal, editor, anything Stylix themes). Matches the
      # bar/prompt font, so the whole rice is one typeface.
      monospace = {
        package = pkgs.nerd-fonts.geist-mono;
        name = "GeistMono Nerd Font";
      };
      # sansSerif / serif / emoji left at Stylix defaults (DejaVu + Noto). Set
      # them here if you want, e.g. sansSerif = { package = pkgs.inter; name = "Inter"; };
      sizes = {
        applications = 11;
        terminal = 12;
        desktop = 11;
        popups = 11;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Affects Stylix-themed terminals (kitty is excluded, so this is just a
    # sensible default for any other terminal you add later).
    opacity.terminal = 0.92;
  };
}

