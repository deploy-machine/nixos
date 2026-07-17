# Full greyscale rice — koda-dark inspired. Every named color is a shade
# of grey; differentiation is by luminance only. Downstream consumers that
# expected `red` or `blue` still resolve, but they resolve to grey values.
# Bare hex (no "#"): Hyprland wants rgb(xxxxxx); GTK/CSS apps want #xxxxxx.
{
  # ---- grey ramp (koda-dark ordering, near-black → white) ----
  bg        = "0a0a0a"; # near-black background (koda-dark #101010, deeper)
  bgDark    = "000000";
  bgAlt     = "141414"; # panels / lighter background
  surface   = "1c1c1c"; # cards / raised
  selection = "272727"; # koda `line` — used for selections/hover fill
  border    = "3a3a3a"; # window / widget border
  muted     = "50585d"; # koda `comment` — dim text
  comment   = "50585d"; # alias, same as above
  dim       = "777777"; # koda keyword/type/operator neutral
  fgDim     = "9a9a9a"; # secondary text
  fg        = "b0b0b0"; # koda `fg` — primary text
  fgBright  = "e0e0e0";
  fgWhite   = "ffffff"; # koda emphasis / func / string / border-hi

  # ---- "accent" names retained for API compat, mapped to bright grey ----
  # Anywhere consumers historically painted with `red` (active border,
  # cursor, active workspace, rofi selection) now gets bright grey.
  red       = "e0e0e0"; # was milkoutside pink — now = fgBright
  red1      = "b0b0b0"; # was accent-dim       — now = fg

  # ---- semantic slots — greyed. Luminance differentiates. ----
  # danger  → brightest    (must catch the eye)
  # warning → bright        (needs attention but calmer)
  # info    → mid           (informational)
  # success → dim           (calm confirmation)
  danger    = "e0e0e0";
  warning   = "c0c0c0";
  info      = "9a9a9a";
  success   = "808080";

  # ---- legacy accent-name aliases — greyed. ANSI/terminal palettes now
  # render as pure luminance ramps too. If a TUI really needs to
  # differentiate categories, it does so via bold/underline instead. ----
  magenta   = "c0c0c0";
  purple    = "a0a0a0";
  blue      = "9a9a9a";
  cyan      = "b0b0b0";
  teal      = "909090";
  green     = "808080";
  yellow    = "c0c0c0";
  orange    = "707070";
}
