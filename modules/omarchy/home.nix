{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.omarchy;

  # The config repo checkout the menu edits (apps.json / dbs.json /
  # theme.json). Matches the path the per-machine /etc/nixos/flake.nix
  # consumes as its `config-repo` input.
  repo = "${config.home.homeDirectory}/nixos";

  # Stable OMARCHY_PATH: a symlink to the package's share/omarchy. Quickshell
  # identifies a running shell by its config path, so the shell and every
  # `omarchy-shell` IPC call must use the same path across rebuilds.
  omarchyPath = "${config.home.homeDirectory}/.local/share/omarchy";

  # Omarchy's shell needs Quickshell 0.3.1; 26.05 ships 0.3.0.
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  quickshell = unstable.quickshell;

  # ---------------------------------------------------------------- themes
  # Every theme (Omarchy's built-in set + installed community themes) run
  # through Omarchy's own renderer, exactly as omarchy-theme-set stages one:
  # alacritty.toml → colors.toml for older themes, then every template in
  # default/themed/ (shell.toml, kitty.conf, neovim.lua, btop.theme, …)
  # that the theme doesn't ship itself.
  theme = import ./theme.nix inputs;
  # Rendering needs only upstream's renderer; the NixOS command layer
  # (which carries the themes tree in its environment) would be circular.
  omarchyUpstream = pkgs.callPackage ./package.nix { src = inputs.omarchy; };
  themeDir = name: t: pkgs.runCommand "omarchy-theme-${name}" {
    nativeBuildInputs = [ omarchyUpstream pkgs.gawk pkgs.gnused pkgs.coreutils pkgs.findutils ];
  } ''
    export HOME=$TMPDIR OMARCHY_PATH=${omarchyUpstream}/share/omarchy
    next=$HOME/.local/state/omarchy/current/next-theme
    mkdir -p "$(dirname "$next")"
    cp -r --no-preserve=mode ${t.dir} "$next"
    omarchy-theme-colors-from-alacritty "$next"
    omarchy-theme-set-templates
    cp -r "$next" $out
  '';
  themeDirs = lib.mapAttrs themeDir theme.all;
  themesTree = pkgs.linkFarm "omarchy-themes"
    (lib.mapAttrsToList (name: path: { inherit name path; }) themeDirs);
  currentTheme = themeDirs.${theme.name};

  # The NixOS layer over Omarchy's menu (menu.nix).
  menuExtension = import ./menu.nix { inherit lib; inherit (inputs) omarchy; };

  # ------------------------------------------------------ dev environments
  # nix-templates/dev + local framework layers (Install > Development),
  # baked into the store so scaffolding is a plain copy: no flake
  # evaluation, works offline. One dir per template plus index.tsv
  # (name<TAB>description) for the picker.
  devTemplates = import ./dev-templates.nix {
    inherit lib;
    src = inputs.dev-templates;
    local = ../../templates;
  };
  # Framework layers are copied over their upstream base, so they ship the
  # same .nvim.lua / .vscode / .editorconfig as the language they build on.
  templateDir = name: t:
    if t ? base then
      pkgs.runCommand "dev-template-${name}" { } ''
        mkdir $out
        cp -r --no-preserve=mode ${t.base}/. ${t.path}/. $out/
      ''
    else t.path;
  devTemplatesDir = pkgs.linkFarm "omarchy-dev-templates" (
    lib.mapAttrsToList (name: t: { inherit name; path = templateDir name t; }) devTemplates.all
    ++ [{
      name = "index.tsv";
      path = pkgs.writeText "dev-templates-index.tsv" (lib.concatStrings
        (lib.mapAttrsToList (name: t: "${name}\t${t.description}\n") devTemplates.templates));
    }]
  );

  # -------------------------------------------------------------- commands
  scriptEnv = {
    OMARCHY_REPO = repo;
    OMARCHY_DEV_TEMPLATES = devTemplatesDir;
    OMARCHY_COMMUNITY_THEMES = ./community-themes.json;
    OMARCHY_THEMES = themesTree;
  };
  mkScript = dir: name: deps: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = deps;
    runtimeEnv = scriptEnv;
    text = builtins.readFile (dir + "/${name}.sh");
  };

  # NixOS versions of Omarchy commands, installed over upstream's in the
  # package (see package.nix). Anything they call by bare name (omarchy-*,
  # hyprctl, systemctl, nix, sudo, …) resolves through the session PATH.
  nixos = mkScript ./nixos-bin;
  replacements = [
    (nixos "omarchy-nixos-rebuild"          [ ])
    (nixos "omarchy-restart-shell"          [ ])
    (nixos "omarchy-launch-shell"           [ ])
    (nixos "omarchy-apply-lock"             [ ])
    (nixos "omarchy-update-available"       [ ])
    (nixos "omarchy-dns"                    [ pkgs.libnotify ])
    (nixos "omarchy-update"                 [ pkgs.gum pkgs.git pkgs.coreutils ])
    (nixos "omarchy-pkg-install"            [ pkgs.gum pkgs.jq pkgs.fzf pkgs.coreutils ])
    (nixos "omarchy-pkg-remove"             [ pkgs.gum pkgs.jq pkgs.coreutils ])
    (nixos "omarchy-pkg-present"            [ pkgs.jq ])
    (nixos "omarchy-pkg-missing"            [ ])
    (nixos "omarchy-pkg-add"                [ ])
    (nixos "omarchy-pkg-drop"               [ ])
    (nixos "omarchy-theme-set"              [ pkgs.jq pkgs.coreutils ])
    (nixos "omarchy-theme-install"          [ pkgs.jq pkgs.gnused pkgs.coreutils ])
    (nixos "omarchy-theme-remove"           [ pkgs.jq pkgs.coreutils ])
    (nixos "omarchy-dev-env"                [ pkgs.gum pkgs.coreutils ])
    (nixos "omarchy-install-dev-env"        [ ])
    (nixos "omarchy-install-docker-dbs"     [ pkgs.jq pkgs.coreutils ])
    (nixos "omarchy-install-font"           [ pkgs.fontconfig ])
    (nixos "omarchy-remove-launcher-entry"  [ pkgs.jq pkgs.gnugrep pkgs.coreutils pkgs.desktop-file-utils ])
    (nixos "omarchy-capture-screenshot"     [ pkgs.hyprshot pkgs.satty pkgs.wl-clipboard pkgs.coreutils ])
  ];
  omarchy = pkgs.callPackage ./package.nix {
    src = inputs.omarchy;
    inherit replacements;
  };

  # Programs Omarchy's shell and commands call by name. The services behind
  # them (NetworkManager, BlueZ, PipeWire, UPower, power-profiles-daemon,
  # polkit, uwsm) come from the NixOS side.
  runtimeDeps = with pkgs; [
    quickshell
    gum jq fzf curl socat perl python3 bc file
    wl-clipboard wtype inotify-tools libnotify desktop-file-utils
    hyprpicker hyprsunset hyprshot satty grim slurp tesseract zbar
    gpu-screen-recorder ffmpeg ffmpegthumbnailer vips imagemagick
    brightnessctl ddcutil iw qrencode xdg-terminal-exec xdg-utils gtk3
    fastfetch terminaltexteffects localsend playerctl pulseaudio
    procps util-linux libxkbcommon
  ];

  # Legacy rofi menu + scripts: only for hosts that can't run the shell
  # (Apple Silicon on Hyprland 0.52 has no Lua config API).
  legacy = mkScript ./scripts;
  legacyScripts = [
    (legacy "omarchy-menu"             [ pkgs.rofi pkgs.jq pkgs.gawk pkgs.coreutils pkgs.rofimoji pkgs.cliphist pkgs.wl-clipboard ])
    (legacy "omarchy-floating-term"    [ ])
    (legacy "omarchy-nixos-rebuild"    [ ])
    (legacy "omarchy-pkg-install"      [ pkgs.gum pkgs.jq pkgs.fzf pkgs.coreutils ])
    (legacy "omarchy-pkg-remove"       [ pkgs.gum pkgs.jq pkgs.coreutils ])
    (legacy "omarchy-webapp-install"   [ pkgs.rofi pkgs.curl pkgs.gnused pkgs.coreutils pkgs.libnotify ])
    (legacy "omarchy-webapp-remove"    [ pkgs.rofi pkgs.gnugrep pkgs.gnused pkgs.coreutils pkgs.libnotify ])
    (legacy "omarchy-launch-webapp"    [ ])
    (legacy "omarchy-tui-install"      [ pkgs.rofi pkgs.coreutils pkgs.libnotify ])
    (legacy "omarchy-tui-remove"       [ pkgs.rofi pkgs.gnugrep pkgs.gnused pkgs.coreutils pkgs.libnotify ])
    (legacy "omarchy-dev-env"          [ pkgs.gum pkgs.coreutils ])
    (legacy "omarchy-docker-db"        [ pkgs.jq pkgs.gnugrep pkgs.coreutils ])
    (legacy "omarchy-toggle"           [ pkgs.jq pkgs.libnotify pkgs.gawk pkgs.procps pkgs.coreutils ])
    (legacy "omarchy-capture"          [ pkgs.grim pkgs.slurp pkgs.tesseract pkgs.zbar pkgs.wl-clipboard pkgs.libnotify pkgs.procps pkgs.coreutils ])
    (legacy "omarchy-clipboard"        [ pkgs.jq ])
    (legacy "omarchy-zoom"             [ pkgs.jq pkgs.bc ])
    (legacy "omarchy-notification"     [ pkgs.libnotify pkgs.curl pkgs.coreutils ])
    (legacy "omarchy-menu-keybindings" [ pkgs.rofi pkgs.jq pkgs.coreutils pkgs.util-linux ])
    (legacy "omarchy-wallpaper"        [ pkgs.rofi pkgs.findutils pkgs.jq pkgs.libnotify pkgs.coreutils ])
    (legacy "omarchy-theme-set"        [ pkgs.rofi pkgs.jq pkgs.findutils pkgs.gnugrep pkgs.libnotify pkgs.coreutils ])
    (legacy "omarchy-update"           [ pkgs.gum pkgs.git pkgs.coreutils ])
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
  options.omarchy.shell.enable = lib.mkOption {
    type = lib.types.bool;
    # Needs Hyprland's Lua config API (0.55+, the 26.05 channel). Apple
    # Silicon stays on 25.11's Hyprland 0.52 and keeps the rofi menu +
    # modules/home/quickshell bar.
    default = !pkgs.stdenv.hostPlatform.isAarch64;
    description = ''
      Run Omarchy's Quickshell desktop shell: bar and dropdown panels
      (network, bluetooth, audio, display, power/stats, clock, weather,
      tailscale), the Omarchy menu, notifications, OSD, lock screen, idle,
      polkit agent, clipboard history and wallpaper. It replaces swaync,
      hyprlock, hypridle, hyprpolkitagent, cliphist, blueman-applet, the
      hyprsunset service and the rofi menu.
    '';
  };

  config = lib.mkMerge [
    {
      home.packages = menuPackages;

      # Theme hierarchy, as Omarchy lays it out: every theme under
      # ~/.config/omarchy/themes/<name>/, the active one at
      # ~/.local/state/omarchy/current/theme (colors.toml + shell.toml for
      # the shell, neovim.lua for ~/dotfiles/nvim, backgrounds, …).
      xdg.configFile."omarchy/themes".source = themesTree;
      home.file.".local/state/omarchy/current/theme".source = currentTheme;
      home.file.".local/state/omarchy/current/theme.name".text = theme.name;

      # current/background: the wallpaper link the shell (and omarchy-theme-
      # bg-set) use. Reset to the theme's first background when the theme
      # changes or the link went stale; a background picked within the same
      # theme survives rebuilds.
      home.activation.omarchyBackground = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        state="$HOME/.local/state/omarchy/current"
        stamp="$state/background.theme"
        if [ "$(cat "$stamp" 2>/dev/null)" != ${lib.escapeShellArg theme.name} ] || [ ! -e "$state/background" ]; then
          run ln -sfn "$HOME/${theme.wallpaper}" "$state/background"
          run sh -c 'echo "$1" >"$2"' _ ${lib.escapeShellArg theme.name} "$stamp"
        fi
      '';
    }

    (lib.mkIf cfg.shell.enable {
      home.packages = [ omarchy ] ++ runtimeDeps ++ (with pkgs; [
        nerd-fonts.jetbrains-mono liberation_ttf noto-fonts-color-emoji
      ]);
      fonts.fontconfig.enable = true;

      home.file.".local/share/omarchy".source = "${omarchy}/share/omarchy";
      # The `omarchy` icon font the menu and bar glyphs use.
      home.file.".local/share/fonts/omarchy.ttf".source =
        "${omarchy}/share/omarchy/default/fonts/omarchy/omarchy.ttf";

      home.sessionVariables.OMARCHY_PATH = omarchyPath;
      systemd.user.sessionVariables.OMARCHY_PATH = omarchyPath;

      # The NixOS layer over Omarchy's menu (install/remove via apps.json,
      # NixOS update actions, Arch-only entries hidden).
      xdg.configFile."omarchy/extensions/omarchy-menu.jsonc".text = menuExtension;

      # Omarchy opens its floating terminals through xdg-terminal-exec.
      xdg.configFile."xdg-terminals.list".text = "kitty.desktop\n";

      # Branding the About screen and screensaver render; seeded from
      # Omarchy's logo once, then editable from Style > About / Screensaver.
      home.activation.omarchyBranding = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        dir="$HOME/.config/omarchy/branding"
        run mkdir -p "$dir"
        for f in about.txt screensaver.txt; do
          [ -e "$dir/$f" ] || run install -m644 ${omarchy}/share/omarchy/logo.txt "$dir/$f"
        done
      '';

      # The shell, supervised by systemd instead of upstream's
      # omarchy-launch-shell loop. The unit embeds the package and the
      # current theme, so a rebuild that changes either restarts it (the
      # shell reads theme colors at startup).
      systemd.user.services.omarchy-shell = {
        Unit = {
          Description = "Omarchy shell (Quickshell)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          X-Restart-Triggers = [ "${omarchy}" "${currentTheme}" ];
        };
        Service = {
          ExecStart = "${quickshell}/bin/quickshell -n -p ${omarchyPath}/shell";
          Environment = [
            "OMARCHY_PATH=${omarchyPath}"
            "QS_DISABLE_FILE_WATCHER=1"
            "QS_NO_RELOAD_POPUP=1"
            "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
          ];
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })

    (lib.mkIf (!cfg.shell.enable) {
      home.packages = legacyScripts ++ [
        pkgs.rofimoji   # emoji picker (SUPER+CTRL+E / Trigger menu)
      ];
    })
  ];
}
