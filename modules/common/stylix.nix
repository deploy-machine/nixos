{ inputs, pkgs, ... }:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";

    # Full greyscale base16. Every slot is a shade of grey — syntax
    # highlighting will differentiate by luminance (numbers slightly
    # different from strings different from functions) but no hue lands
    # anywhere. base00–base07 is the standard ramp; base08–base0F are
    # spread across the ramp so that categorical bases still visibly
    # differ from each other in supported editors.
    base16Scheme = {
      base00 = "0a0a0a"; # background
      base01 = "141414"; # panels / lighter background
      base02 = "272727"; # selection (koda line)
      base03 = "50585d"; # comments / disabled (koda comment)
      base04 = "777777"; # dim foreground (koda keyword/type)
      base05 = "b0b0b0"; # foreground (koda fg)
      base06 = "d0d0d0"; # bright foreground
      base07 = "ffffff"; # brightest / emphasis
      base08 = "e0e0e0"; # was accent — now bright grey (errors, diff-removed)
      base09 = "9a9a9a"; # numbers/constants
      base0A = "c0c0c0"; # classes/warnings
      base0B = "808080"; # strings
      base0C = "b0b0b0"; # support/regex
      base0D = "d0d0d0"; # functions (slightly bright — draws the eye)
      base0E = "a0a0a0"; # keywords
      base0F = "707070"; # deprecated (dim)
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
