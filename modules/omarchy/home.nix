{ config, lib, pkgs, ... }:
let
  # The config repo checkout the menu edits (apps.json / dbs.json) and
  # scaffolds templates from. Matches the path the per-machine
  # /etc/nixos/flake.nix consumes as its `config-repo` input.
  repo = "${config.home.homeDirectory}/nixos";

  script = name: deps: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = deps;
    runtimeEnv.OMARCHY_REPO = repo;
    text = builtins.readFile ./scripts/${name + ".sh"};
  };

  # Tools referenced by bare name instead of runtimeInputs (hyprctl,
  # systemctl, swaync-client, kitty, chromium, ...) resolve via the session
  # PATH so the scripts always use the same build the session runs.
  scripts = [
    (script "omarchy-menu"             [ pkgs.rofi pkgs.jq pkgs.coreutils pkgs.rofimoji pkgs.cliphist pkgs.wl-clipboard ])
    (script "omarchy-floating-term"    [ ])
    (script "omarchy-nixos-rebuild"    [ ])
    (script "omarchy-pkg-install"      [ pkgs.gum pkgs.jq pkgs.fzf pkgs.coreutils ])
    (script "omarchy-pkg-remove"       [ pkgs.gum pkgs.jq pkgs.coreutils ])
    (script "omarchy-webapp-install"   [ pkgs.rofi pkgs.curl pkgs.gnused pkgs.coreutils pkgs.libnotify ])
    (script "omarchy-webapp-remove"    [ pkgs.rofi pkgs.gnugrep pkgs.gnused pkgs.coreutils pkgs.libnotify ])
    (script "omarchy-launch-webapp"    [ ])
    (script "omarchy-tui-install"      [ pkgs.rofi pkgs.coreutils pkgs.libnotify ])
    (script "omarchy-tui-remove"       [ pkgs.rofi pkgs.gnugrep pkgs.gnused pkgs.coreutils pkgs.libnotify ])
    (script "omarchy-dev-env"          [ pkgs.gum pkgs.coreutils ])
    (script "omarchy-docker-db"        [ pkgs.jq pkgs.gnugrep pkgs.coreutils ])
    (script "omarchy-toggle"           [ pkgs.jq pkgs.libnotify pkgs.gawk pkgs.procps pkgs.coreutils ])
    (script "omarchy-capture"          [ pkgs.grim pkgs.slurp pkgs.tesseract pkgs.zbar pkgs.wl-clipboard pkgs.libnotify pkgs.procps pkgs.coreutils ])
    (script "omarchy-clipboard"        [ pkgs.jq ])
    (script "omarchy-zoom"             [ pkgs.jq pkgs.bc ])
    (script "omarchy-notification"     [ pkgs.libnotify pkgs.curl pkgs.coreutils ])
    (script "omarchy-menu-keybindings" [ pkgs.rofi pkgs.jq pkgs.coreutils pkgs.util-linux ])
    (script "omarchy-wallpaper"        [ pkgs.rofi pkgs.findutils pkgs.libnotify pkgs.coreutils ])
    (script "omarchy-update"           [ pkgs.gum pkgs.git pkgs.coreutils ])
  ];

  # Menu-managed packages (Install > Package appends here, Remove > Package
  # deletes). Unknown attribute names are skipped with a warning instead of
  # failing the build, so a typo'd entry can never brick a rebuild — remove
  # it via the menu or by editing apps.json.
  appState = builtins.fromJSON (builtins.readFile ./apps.json);
  resolvePackage = name:
    let path = lib.splitString "." name; in
    if lib.hasAttrByPath path pkgs
    then [ (lib.getAttrFromPath path pkgs) ]
    else lib.warn "omarchy: unknown package '${name}' in apps.json — skipped" [ ];
  menuPackages = lib.concatMap resolvePackage appState.packages;
in
{
  home.packages = scripts ++ menuPackages ++ [
    pkgs.rofimoji   # emoji picker (SUPER+CTRL+E / Trigger menu)
  ];
}
