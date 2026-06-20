# /etc/nixos/nixcord.nix
# Declarative Discord via nixcord.
#
# Heads up on terminology: nixcord configures **Vencord** (Discord + the Vencord
# client mod), NOT BetterDiscord. They're different mods — BetterDiscord patches
# the official client imperatively and doesn't sit well on NixOS's read-only
# store. Vencord is the clean declarative path, and the big win is that Stylix
# already knows how to theme it: the Stylix nixcord target writes a milkoutside
# theme into Vencord and switches it on for you, so there's no hand-written CSS
# and it tracks your palette automatically.
#
# Discord is unfree — you already run nixpkgs.config.allowUnfree = true (for
# claude-code / rustdesk), so it builds without extra steps.
{ config, pkgs, ... }:
let
  nixcord = import (builtins.fetchTarball {
    url = "https://github.com/KaylorBen/nixcord/archive/main.tar.gz";
    # The first build prints the real hash; paste it here to pin the version and
    # silence the "unpinned fetchTarball" re-fetch warning:
    # sha256 = "sha256:0000000000000000000000000000000000000000000000000000";
  });
in
{
  imports = [ nixcord.homeModules.nixcord ];

  programs.nixcord = {
    enable = true;                # installs Discord + Vencord (discord client on by default)
    config = {
      frameless = true;           # drop the titlebar — cleaner under a tiling WM
      plugins = {
        # nixcord wraps ~32 Vencord plugins as typed options. A safe starter set
        # (all names validated against nixcord's wrapped list):
        betterFolders.enable = true;      # cleaner server-folder behaviour
        typingTweaks.enable = true;       # nicer "who's typing" display
        silentTyping.enable = true;       # don't broadcast your typing indicator
        spotifyControls.enable = true;    # Spotify controls in the toolbar
        platformIndicators.enable = true; # desktop / mobile / web badge per user
        # For any other Vencord plugin, toggle it in the in-app Plugins menu to
        # test (changes won't persist), then declare it here once it works.
      };
    };
  };

  # Stylix writes ~/.config/Vencord/themes/stylix.theme.css (milkoutside) and adds
  # it to enabledThemes. Leave the theme to Stylix — don't also set enabledThemes
  # or quickCss here or they'll collide.
  stylix.targets.nixcord.enable = true;
}

