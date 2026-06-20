{ pkgs, ... }:
{
  # Bootloader (UEFI; override per-host for legacy BIOS).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking. Per-host hostname is set in hosts/<hostname>/default.nix.
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 22 ];

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nl_NL.UTF-8";
    LC_IDENTIFICATION = "nl_NL.UTF-8";
    LC_MEASUREMENT = "nl_NL.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_NAME = "nl_NL.UTF-8";
    LC_NUMERIC = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
    LC_TELEPHONE = "nl_NL.UTF-8";
    LC_TIME = "nl_NL.UTF-8";
  };

  services.xserver.xkb = { layout = "us"; variant = ""; };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Wayland/Hyprland — system-side enablement. The user-side config is in
  # modules/home/hyprland.nix.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-wlr
    ];
    config.common.default = [ "wlr" ];
  };

  # Tells Chromium/Electron apps to use Wayland natively.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Lets unpatched dynamic binaries (some VS Code servers, Mason tools, …)
  # run on NixOS.
  programs.nix-ld.enable = true;

  programs.zsh.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Required for home-manager's dconfSettings activation (Stylix's GTK target
  # writes theme keys via `dconf write`). Without this, the first nixos-rebuild
  # switch on a fresh install fails with
  # "GDBus.Error.ServiceUnknown: The name is not activatable" because the
  # dconf service has no DBus activation manifest installed.
  programs.dconf.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # Flakes + the nix command are required for `nixos-rebuild switch --flake`.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # nixpkgs.config.allowUnfree is set per-host (the bootstrap asks). Anything
  # else nixpkgs-config-shaped is fine to set here unconditionally — it only
  # matters when the relevant package is actually pulled in.
  nixpkgs.config.chromium.commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";

  # Pinned to the install's release. Don't bump without reading the docs —
  # gates default values of stateful options.
  system.stateVersion = "26.05";
}
