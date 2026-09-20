# Palette entry point. Every consumer (hyprland.nix, desktop.nix,
# waybar.nix, cli.nix, quickshell) does `import ./colors.nix` and gets the
# ACTIVE theme's colors — the selection lives in modules/omarchy/theme.json
# and the palettes in modules/omarchy/theme.nix. Switch with
# `omarchy-theme-set` (Style > Theme in the menu), then rebuild.
#
# Bare hex (no "#"): Hyprland wants rgb(xxxxxx); GTK/CSS apps want #xxxxxx.
(import ../omarchy/theme.nix).colors
