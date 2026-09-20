# Theme registry + current selection. The omarchy-theme-set menu script
# edits theme.json and rebuilds; every palette consumer reaches the active
# colors through modules/home/colors.nix, which re-exports `colors` from
# here — so switching themes restyles hyprland, kitty, rofi, swaync, the
# quickshell bar, waybar CSS, and the CLI prompt in one rebuild.
#
# Both palettes are monochrome by design (the rice is luminance-only):
#   koda-dark  — the original near-black grey ramp
#   vantablack — pure #000000 blacks with white/grey text, palette lifted
#                from omarchy's vantablack theme (colors.toml)
#
# `wallpaper` is the theme's default background, relative to $HOME —
# themes' background sets are deployed to ~/Wallpapers/themes/<name>/ by
# modules/omarchy/home.nix, and the switcher (omarchy-wallpaper) offers
# every image in the active theme's set plus loose files in ~/Wallpapers.
let
  selection = (builtins.fromJSON (builtins.readFile ./theme.json)).theme;

  themes = {
    koda-dark = {
      wallpaper = "Wallpapers/themes/koda-dark/nixos.png";
      colors = {
        # ---- grey ramp (koda-dark ordering, near-black → white) ----
        bg        = "0a0a0a";
        bgDark    = "000000";
        bgAlt     = "141414";
        surface   = "1c1c1c";
        selection = "272727";
        border    = "3a3a3a";
        muted     = "50585d";
        comment   = "50585d";
        dim       = "777777";
        fgDim     = "9a9a9a";
        fg        = "b0b0b0";
        fgBright  = "e0e0e0";
        fgWhite   = "ffffff";

        # ---- "accent" names retained for API compat → bright grey ----
        red       = "e0e0e0";
        red1      = "b0b0b0";

        # ---- semantic slots — luminance differentiates ----
        danger    = "e0e0e0";
        warning   = "c0c0c0";
        info      = "9a9a9a";
        success   = "808080";

        # ---- legacy accent-name aliases — greyed ----
        magenta   = "c0c0c0";
        purple    = "a0a0a0";
        blue      = "9a9a9a";
        cyan      = "b0b0b0";
        teal      = "909090";
        green     = "808080";
        yellow    = "c0c0c0";
        orange    = "707070";
      };
    };

    vantablack = {
      wallpaper = "Wallpapers/themes/vantablack/0-dot-hands.webp";
      colors = {
        # ---- true-black ramp (omarchy vantablack colors.toml) ----
        bg        = "000000";
        bgDark    = "000000";
        bgAlt     = "090909";
        surface   = "1a1a1a";
        selection = "1a1a1a";
        border    = "333333";
        muted     = "7a7a7a";
        comment   = "7a7a7a";
        dim       = "8d8d8d";
        fgDim     = "a4a4a4";
        fg        = "ececec";
        fgBright  = "ffffff";
        fgWhite   = "ffffff";

        red       = "ffffff";
        red1      = "ececec";

        danger    = "ffffff";
        warning   = "cecece";
        info      = "a4a4a4";
        success   = "b6b6b6";

        magenta   = "9b9b9b";
        purple    = "9b9b9b";
        blue      = "8d8d8d";
        cyan      = "b0b0b0";
        teal      = "b0b0b0";
        green     = "b6b6b6";
        yellow    = "cecece";
        orange    = "b9b9b9";
      };
    };
  };
in
{
  name = selection;
  names = builtins.attrNames themes;
  inherit (themes.${selection}) colors wallpaper;
}
