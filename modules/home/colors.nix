# Palette entry point. Every consumer (hyprland.nix, desktop.nix, cli.nix,
# shell.nix, quickshell) does `import ./colors.nix inputs` and gets the
# ACTIVE theme's colors — the selection lives in modules/omarchy/theme.json
# and the themes (Omarchy's colors.toml format) in modules/omarchy/theme.nix.
# Switch with `omarchy-theme-set` (Style > Theme in the menu).
#
# Bare hex (no "#"): Hyprland wants rgb(xxxxxx); GTK/CSS apps want #xxxxxx.
inputs: (import ../omarchy/theme.nix inputs).colors
