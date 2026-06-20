{ config, lib, pkgs, username, ... }:
{
  # Builds on the gaming role and replaces the normal greeter with a
  # gamescope-driven Steam Big Picture session — pick-up-and-play console feel.
  # Mutually exclusive with the headless and desktop roles (sets greetd).
  imports = [ ./gaming.nix ];

  services.greetd = lib.mkIf config.nixpkgs.config.allowUnfree {
    enable = true;
    settings = {
      initial_session = {
        # `steam-gamescope` is wrapped by programs.steam.gamescopeSession; it
        # launches Steam in Big Picture mode under a gamescope compositor.
        command = "${pkgs.gamescope}/bin/gamescope --steam -e -- steam -gamepadui";
        user = username;
      };
      # Fallback: tuigreet for maintenance / dropping into Hyprland.
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };
  };

  # TODO (v1 scaffold only): "wake on controller connect, idle screen-off
  # when no controller picked up". The plan:
  #   1. udev rule fires on a joystick/Bluetooth controller plug/unplug:
  #        SUBSYSTEM=="input", ATTRS{name}=="*Controller*",
  #          TAG+="systemd", ENV{SYSTEMD_WANTS}="kiosk-controller@%k.service"
  #   2. kiosk-controller@.service runs a watcher that calls `loginctl unlock-session`
  #      on connect and `loginctl lock-session` after N minutes of inactivity.
  #   3. DPMS off via `hyprctl dispatch dpms off` after idle, on via `dpms on`.
  # Skipped here because the device matching is hardware-specific (USB IDs,
  # Bluetooth profiles) — wire it up once you know your controllers.
}
