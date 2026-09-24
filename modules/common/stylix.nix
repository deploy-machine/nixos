{ inputs, pkgs, ... }:
let
  # The active Omarchy theme (modules/omarchy/theme.nix, selected in
  # theme.json), in Omarchy's own key names.
  theme = import ../omarchy/theme.nix inputs;
  k = theme.palette;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = theme.mode;

    # base16 from the theme: base00–base07 is the background → foreground
    # ramp, base08–base0F the hues (red, orange, yellow, green, cyan, blue,
    # magenta, brown), the standard base16 slot meanings.
    base16Scheme = {
      base00 = k.background;
      base01 = k.lighter_background;
      base02 = k.selection;
      base03 = k.muted;
      base04 = k.dark_foreground;
      base05 = k.foreground;
      base06 = k.light_foreground;
      base07 = k.bright_foreground;
      base08 = k.red;
      base09 = k.orange;
      base0A = k.yellow;
      base0B = k.green;
      base0C = k.cyan;
      base0D = k.blue;
      base0E = k.magenta;
      base0F = k.brown;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.geist-mono;
        name = "GeistMono Nerd Font";
      };
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

    # Icons: Papirus with grey folder tint (papirus-folders -C grey) so
    # folders sit in the monochrome UI. The accent still shows through on
    # apps that render base08 (errors, diff-removed) — folders themselves
    # stay quiet.
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme.override { color = "grey"; };
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };

    opacity.terminal = 0.92;
  };
}
