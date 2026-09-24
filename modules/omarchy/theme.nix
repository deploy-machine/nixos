# Theme registry + current selection: Omarchy's theme set, read straight
# from upstream (the `omarchy` flake input). Each themes/<name>/ provides:
#
#   colors.toml    accent, background/foreground ramps, the 8+6 ANSI hues
#   backgrounds/   the theme's wallpapers
#   preview.png    shown by the theme switcher
#   neovim.lua     LazyVim colorscheme spec (generated from the palette via
#                  aether.nvim when a theme has none, as Omarchy does)
#
# modules/omarchy/home.nix lays these out the way Omarchy does:
# ~/.config/omarchy/themes/<name>/ per theme, and
# ~/.config/omarchy/current/theme → the active one.
#
# The omarchy-theme-set menu script writes the selection to theme.json and
# rebuilds. Everything palette-driven follows: hyprland, kitty (ANSI 16),
# rofi, swaync, hyprlock, the quickshell bar, the starship prompt, neovim,
# and the Stylix base16 scheme behind GTK/Qt/btop/bat/fzf/….
#
# Takes the flake inputs (only `omarchy` is used), so call it as
# `import ./theme.nix inputs`.
{ omarchy, ... }:
let
  selection = (builtins.fromJSON (builtins.readFile ./theme.json)).theme;

  themesDir = omarchy + "/themes";
  entries = builtins.readDir themesDir;
  dirs = builtins.mapAttrs (name: _: themesDir + "/${name}")
    (builtins.removeAttrs entries
      (builtins.filter (n: entries.${n} != "directory") (builtins.attrNames entries)));

  # ---- hex helpers (Omarchy's mix_color, in Nix) -------------------------
  hexDigits = { "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4; "5" = 5; "6" = 6; "7" = 7;
                "8" = 8; "9" = 9; a = 10; b = 11; c = 12; d = 13; e = 14; f = 15; };
  byte = s: i: hexDigits.${builtins.substring i 1 s} * 16 + hexDigits.${builtins.substring (i + 1) 1 s};
  toHex2 = n: let d = "0123456789abcdef"; in
    builtins.substring (n / 16) 1 d + builtins.substring (n - (n / 16) * 16) 1 d;
  # Bare lowercase hex, no "#": Hyprland wants rgb(xxxxxx), CSS wants #xxxxxx.
  bare = s: let l = builtins.replaceStrings
      [ "#" "A" "B" "C" "D" "E" "F" ] [ "" "a" "b" "c" "d" "e" "f" ] s;
    in builtins.substring 0 6 l;
  # mix a b t: t = 0 → a, t = 1 → b (t in percent, integer).
  mix = a: b: t:
    let ch = i: (byte a i * (100 - t) + byte b i * t + 50) / 100;
    in toHex2 (ch 0) + toHex2 (ch 2) + toHex2 (ch 4);

  # ---- colors.toml → resolved Omarchy keys --------------------------------
  # Mirrors the fallback cascade in omarchy-theme-color, for the keys some
  # themes leave out.
  resolve = raw:
    let
      # Plain "#rrggbb" colors only; a few themes also carry Hyprland
      # gradient strings (hyprland_active_border) we don't consume.
      isHex = v: builtins.isString v && builtins.match "#[0-9a-fA-F]{6}" v != null;
      r = builtins.mapAttrs (_: bare)
        (builtins.removeAttrs raw (builtins.filter (n: !isHex raw.${n}) (builtins.attrNames raw)));
      get = k: fallback: r.${k} or fallback;
      background = r.background;
      foreground = r.foreground;
      yellow = r.yellow;
      orange = get "orange" yellow;
      lift = k: get "bright_${k}" (mix r.${k} "ffffff" 20);
    in r // rec {
      inherit background foreground orange;
      mode = raw.mode or "dark";
      accent = get "accent" r.blue;
      dark_background = get "dark_background" (mix background "000000" 25);
      darker_background = get "darker_background" (mix background "000000" 50);
      lighter_background = get "lighter_background" background;
      dark_foreground = get "dark_foreground" foreground;
      light_foreground = get "light_foreground" foreground;
      bright_foreground = get "bright_foreground" foreground;
      muted = get "muted" dark_foreground;
      selection = get "selection" lighter_background;
      brown = get "brown" (mix orange "000000" 50);
      bright_red = lift "red";
      bright_green = lift "green";
      bright_yellow = lift "yellow";
      bright_blue = lift "blue";
      bright_magenta = lift "magenta";
      bright_cyan = lift "cyan";
    };

  # ---- resolved keys → this repo's palette schema --------------------------
  # The names every colors.nix consumer uses. `red`/`red1` are the accent
  # slots (the rice's original accent was red); real red is `danger`.
  schema = k: {
    bg        = k.background;
    bgDark    = k.darker_background;
    bgAlt     = k.dark_background;
    surface   = k.lighter_background;
    selection = k.selection;
    border    = mix k.lighter_background k.muted 50;
    muted     = k.muted;
    comment   = k.dark_foreground;
    dim       = mix k.dark_foreground k.foreground 35;
    fgDim     = mix k.foreground k.background 20;
    fg        = k.foreground;
    fgBright  = k.light_foreground;
    fgWhite   = k.bright_foreground;

    accent    = k.accent;
    red       = k.accent;
    red1      = mix k.accent k.background 30;

    danger    = k.red;
    warning   = k.yellow;
    info      = k.blue;
    success   = k.green;

    magenta   = k.magenta;
    purple    = k.magenta;
    blue      = k.blue;
    cyan      = k.cyan;
    teal      = k.cyan;
    green     = k.green;
    yellow    = k.yellow;
    orange    = k.orange;
    brown     = k.brown;
  };

  # ANSI 16, as Omarchy's kitty/alacritty templates map them.
  ansi = k: [
    k.background k.red k.green k.yellow k.blue k.magenta k.cyan k.foreground
    k.muted k.bright_red k.bright_green k.bright_yellow k.bright_blue k.bright_magenta k.bright_cyan k.bright_foreground
  ];

  # Themes without their own neovim.lua get Omarchy's generated one
  # (aether.nvim fed the palette), same as upstream does.
  renderNeovim = k:
    let
      tpl = builtins.readFile (omarchy + "/default/themed/neovim.lua.tpl");
      keys = builtins.filter (n: builtins.isString k.${n}) (builtins.attrNames k);
    in builtins.replaceStrings
      (map (n: "{{ ${n} }}") keys)
      (map (n: if n == "mode" then k.${n} else "#${k.${n}}") keys)
      tpl;

  load = name: dir:
    let
      k = resolve (builtins.fromTOML (builtins.readFile (dir + "/colors.toml")));
      files = builtins.readDir dir;
      backgrounds = builtins.sort builtins.lessThan
        (builtins.attrNames (builtins.readDir (dir + "/backgrounds")));
    in {
      inherit name dir;
      mode = k.mode;
      palette = k;
      colors = schema k;
      ansi = ansi k;
      # Relative to $HOME, through the current-theme link home.nix deploys.
      wallpaper = ".config/omarchy/current/theme/backgrounds/${builtins.head backgrounds}";
      # null when the theme ships its own neovim.lua.
      generatedNeovim = if files ? "neovim.lua" then null else renderNeovim k;
    };

  themes = builtins.mapAttrs load dirs;
  current = themes.${selection} or (throw
    "modules/omarchy/theme.json selects unknown theme '${selection}'. Available: ${toString (builtins.attrNames themes)}");
in
current // {
  names = builtins.attrNames themes;
  all = themes;
}
