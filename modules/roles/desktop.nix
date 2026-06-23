{ config, lib, pkgs, ... }:
{
  # Conventional graphical login: greetd → tuigreet, user selects Hyprland.
  # Mutually exclusive with the headless and gaming-kiosk roles (they all set
  # services.greetd.settings).
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };
  };

  # Thunar file manager. thunar-volman handles in-session auto-mounting of
  # removable media; udiskie (home-manager service) covers automount when
  # Thunar isn't running. xfconf is required for Thunar to persist preferences.
  programs.thunar = {
    enable = true;
    # 26.05 moved these to top-level; 25.11 still has them under pkgs.xfce.
    plugins = [
      (pkgs.thunar-archive-plugin or pkgs.xfce.thunar-archive-plugin)
      (pkgs.thunar-volman         or pkgs.xfce.thunar-volman)
    ];
  };
  programs.xfconf.enable = true;

  # Disk + filesystem stack Thunar/udiskie talk to:
  #   udisks2 — block device daemon (mount/unmount/eject)
  #   gvfs    — trash, MTP, network mounts, "Other Locations" sidebar
  #   tumbler — thumbnail generation for the file manager
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Basic bluetooth stack. The gaming role layers controller-specific
  # tweaks (powerOnBoot, audio profile bits) on top via plain assignments;
  # mkDefault here lets that win without a merge conflict.
  hardware.bluetooth.enable = lib.mkDefault true;
  services.blueman.enable   = lib.mkDefault true;

  # gnome-keyring provides org.freedesktop.secrets (the Secret Service API).
  # Chromium, VS Code, Slack, networkmanager-applet, etc. all use it to store
  # credentials. enableGnomeKeyring in PAM means the keyring unlocks on
  # login automatically — no second password prompt the first time an app
  # asks for a secret.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Battery / AC state for desktop apps + tray indicators.
  services.upower.enable = true;

  # CPU performance profiles (balanced / power-saver / performance). The
  # laptop role prefers tlp and overrides this to false; mkDefault loses to
  # the laptop role's plain `false`.
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # ---------------- suspend/resume reliability (x86_64 only) ----------------
  # ASUS X570 + Ryzen Zen 2 (and several other consumer AMD desktop boards)
  # have buggy ACPI S3 implementations: the machine enters sleep, but USB
  # wake events never resume it. Two-part fix:
  #   1. mem_sleep_default=s2idle — AMD's recommendation for modern Ryzen.
  #      Slightly higher idle draw than S3, but resume is reliable.
  #   2. Enable wakeup on every USB hub. By default Linux ships USB hubs
  #      with power/wakeup=disabled, so a keypress/mouse-click emits a wake
  #      signal that the hub silently drops. The udev rule below flips that
  #      on at hub-add time (matches class 09 = USB hub, covers roothubs and
  #      any downstream hub a keyboard might be plugged into).
  # Gated on x86_64 because Asahi (aarch64) uses s2idle natively and has its
  # own wake plumbing — this would be a noisy no-op there.
  boot.kernelParams = lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    "mem_sleep_default=s2idle"
  ];
  services.udev.extraRules = lib.optionalString pkgs.stdenv.hostPlatform.isx86_64 ''
    ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{bDeviceClass}=="09", ATTR{power/wakeup}="enabled"
  '';
}
