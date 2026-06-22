{ lib, pkgs, inputs, osConfig ? null, ... }:
let
  # Upstream Discord is unfree + x86_64-only, so on aarch64 (Asahi) we fall
  # back to Vesktop, which is FOSS and has an aarch64-linux build. Both
  # clients share the same Vencord config below, written by nixcord.
  allowUnfree = osConfig != null && (osConfig.nixpkgs.config.allowUnfree or false);
  isAarch64   = pkgs.stdenv.hostPlatform.isAarch64;
  useVesktop  = isAarch64;
  enabled     = allowUnfree || useVesktop;  # Vesktop itself is free
in
{
  # Module imported unconditionally — its closure is only realized when
  # programs.nixcord.enable is true (inside the mkIf below).
  imports = [ inputs.nixcord.homeModules.nixcord ];

  config = lib.mkIf enabled {
    # The whole nixcord HM module body is gated on programs.nixcord.enable —
    # leaving it false skips installation of Vesktop too. So enable nixcord
    # unconditionally and opt out of Discord on aarch64 via discord.enable.
    programs.nixcord = {
      enable = true;
      discord.enable = !useVesktop;   # x86_64: Discord + Vencord
      vesktop.enable = useVesktop;    # aarch64: Vesktop (bundled Vencord)
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
