{ config, lib, pkgs, username, ... }:
let
  # greetd boots straight into Hyprland with the wlroots headless backend,
  # so it'll come up usable over wayvnc even without a monitor attached.
  hypr-headless = pkgs.writeShellScript "hypr-headless" ''
    export WLR_BACKENDS=headless
    export WLR_LIBINPUT_NO_DEVICES=1
    export HYPRLAND_TRACE=1
    export AQ_TRACE=1
    exec hyprland
  '';

  # Idempotent script that ensures virt-1 exists at 1920x1080@60.
  # `hyprctl keyword` is rejected by the native-Lua parser ("can't work with
  # non-legacy parsers"); the eval form goes through hl.monitor instead.
  hypremoteScript = pkgs.writeShellScript "hypremote" ''
    ${pkgs.coreutils}/bin/sleep 3
    if ! ${pkgs.hyprland}/bin/hyprctl -i 0 monitors | ${pkgs.gnugrep}/bin/grep -q "^Monitor virt-1 "; then
      ${pkgs.hyprland}/bin/hyprctl -i 0 output create headless virt-1
    fi
    ${pkgs.hyprland}/bin/hyprctl -i 0 eval 'hl.monitor({ output = "virt-1", mode = "1920x1080@60", position = "0x0", scale = 1 })'
  '';
in
{
  environment.systemPackages = [ pkgs.wayvnc ];

  networking.firewall.allowedTCPPorts = [ 5900 ];
  networking.firewall.allowedUDPPorts = [ 5900 ];

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${hypr-headless}";
        user = username;
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  systemd.user.services.wayvnc = {
    description = "WayVNC headless service for Hyprland";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    environment = {
      WLR_RENDERER = "pixman";
      # TODO: not great with non-1000 UIDs — fine for single-user hosts.
      XDG_RUNTIME_DIR = "/run/user/1000";
    };

    script = ''
      # Wait until Hyprland has published its Wayland socket.
      while [ -z "$WAYLAND_DISPLAY" ]; do
        WAYLAND_DISPLAY=$(systemctl --user show-environment | grep '^WAYLAND_DISPLAY=' | cut -d= -f2)
        sleep 0.5
      done
      export WAYLAND_DISPLAY
      exec ${pkgs.wayvnc}/bin/wayvnc -o virt-1 0.0.0.0 5900
    '';

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # User-level glue (via home-manager): the hypremote service plus an
  # activation hook that re-fires it after every nixos-rebuild so the headless
  # mode survives reconfigurations. Written as a function so `lib` rebinds to
  # home-manager's extended lib (needed for lib.hm.dag.entryAfter).
  home-manager.users.${username} = { lib, ... }: {
    systemd.user.services.hypremote = {
      Unit = {
        Description = "Ensure virt-1 headless monitor exists at 1920x1080@60";
        After = [ "wayland-session@hyprland.desktop.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${hypremoteScript}";
        Slice = "background-graphical.slice";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    home.activation.resetHeadlessMonitor = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user start --no-block hypremote.service || true
    '';
  };
}
