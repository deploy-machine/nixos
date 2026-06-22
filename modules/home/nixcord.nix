{ lib, pkgs, inputs, osConfig ? null, ... }:
let
  # Discord is unfree AND x86_64-only upstream, so gate on both the host's
  # allowUnfree policy and the build platform. With the home-manager-on-NixOS
  # integration, `osConfig` exposes the system config; fall back to false
  # when unavailable (standalone home-manager).
  enabled = osConfig != null
         && (osConfig.nixpkgs.config.allowUnfree or false)
         && pkgs.stdenv.hostPlatform.isx86_64;
in
{
  # Module imported unconditionally — its closure is only realized when
  # programs.nixcord.enable is true (inside the mkIf below).
  imports = [ inputs.nixcord.homeModules.nixcord ];

  config = lib.mkIf enabled {
    programs.nixcord = {
      enable = true;                  # installs Discord + Vencord
      config = {
        frameless = true;             # drop the titlebar — cleaner under a tiling WM
        plugins = {
          betterFolders.enable = true;
          typingTweaks.enable = true;
          silentTyping.enable = true;
          spotifyControls.enable = true;
          platformIndicators.enable = true;
          # For any other Vencord plugin, toggle it in the in-app Plugins menu
          # to test (changes won't persist), then declare it here.
        };
      };
    };

    # Stylix writes ~/.config/Vencord/themes/stylix.theme.css (milkoutside) and
    # adds it to enabledThemes — only relevant when nixcord is on.
    stylix.targets.nixcord.enable = true;
  };
}
