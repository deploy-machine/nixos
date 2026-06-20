{ inputs, pkgs, ... }:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    polarity = "dark";

    base16Scheme = {
      base00 = "040607"; # background
      base01 = "0f0f15"; # panels / lighter background
      base02 = "292e42"; # selection
      base03 = "595959"; # comments / disabled
      base04 = "828282"; # dim foreground
      base05 = "e8e8e8"; # foreground
      base06 = "f0f0f0"; # bright foreground
      base07 = "ffffff"; # brightest
      base08 = "f93a82"; # red (milkoutside accent)
      base09 = "ffad00"; # orange
      base0A = "f8e063"; # yellow
      base0B = "92cf9c"; # green
      base0C = "7dcfff"; # cyan
      base0D = "63c3dd"; # blue
      base0E = "9d7cd8"; # purple
      base0F = "e79cfb"; # magenta
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

    opacity.terminal = 0.92;
  };
}
