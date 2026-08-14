{ lib, pkgs, ... }:
{
  # Bootloader (UEFI; override per-host for legacy BIOS). mkDefault on the
  # EFI-vars flag so the Apple Silicon module can force it false — U-Boot on
  # M-series Macs has no EFI vars to touch.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  # Cap the boot menu so old generations don't accumulate forever. On the
  # Asahi host every generation keeps a kernel+initrd on the small ESP, and
  # a full /boot makes rebuilds fail.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Clear /tmp on boot (crashed-build litter, extracted archives, …).
  boot.tmp.cleanOnBoot = true;

  # Networking. Per-host hostname is set in hosts/<hostname>/default.nix.
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Tailscale mesh VPN. `openFirewall` punches UDP 41641 for direct (not
  # DERP-relayed) connections. Run `sudo tailscale up` once after rebuild to
  # authenticate; the daemon persists state in /var/lib/tailscale across
  # rebuilds. The `tailscale` CLI is added to systemPackages by the service.
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

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
    ];
    # hyprland portal only implements Screenshot/ScreenCast/GlobalShortcuts;
    # gtk is the fallback for everything else (FileChooser, OpenURI, …).
    config.common.default = [ "hyprland" "gtk" ];
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

  # Store hygiene. GC keeps two weeks of generations (rollback window) and
  # runs weekly; optimise hardlinks identical store files. GC'd Asahi
  # kernels re-substitute from cachix, so deletion is cheap to undo.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  # Weekly TRIM pass so the SSD controller learns about freed blocks —
  # without it write performance and wear-leveling degrade over time.
  services.fstrim.enable = true;

  # Compressed in-RAM swap (zstd, ~2-3× compression). Cheap pressure valve
  # on every host; the Apple Silicon module layers a real swapfile on top
  # for the muvm/OOM case documented there.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  # Firmware updates via fwupd/LVFS (UEFI, SSDs, peripherals). x86 only —
  # LVFS has no coverage for Apple Silicon machines.
  services.fwupd.enable = pkgs.stdenv.hostPlatform.isx86_64;

  # Smartcard daemon for the CCID half of a YubiKey (OpenPGP, PIV, most of
  # `ykman`). The FIDO/WebAuthn half talks hidraw directly and doesn't need
  # this. If `gpg --card-status` ever reports the card as unavailable, add
  # `disable-ccid` to scdaemon.conf so gpg goes through pcscd instead of
  # fighting it for the USB interface.
  services.pcscd.enable = true;

  # nixpkgs.config.allowUnfree is set per-host (the bootstrap asks). Anything
  # else nixpkgs-config-shaped is fine to set here unconditionally — it only
  # matters when the relevant package is actually pulled in.
  #
  # tutanota-desktop bundles an EOL Electron upstream; same risk profile as
  # using their Windows / macOS builds, which we already do.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # Default stateVersion for hosts that don't override it. Pinned to the
  # release the x86 install was bootstrapped on — never bump on a deployed
  # host (gates default values of stateful options). The Apple Silicon
  # hardware module overrides this to 25.11 because the Asahi installer ISO
  # was pinned to that release.
  system.stateVersion = lib.mkDefault "26.05";
}
