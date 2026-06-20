# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let 
  unstable = import <unstable> {};
  hypr-headless = pkgs.writeShellScript "hypr-headless" ''
    export WLR_BACKENDS=headless
    export WLR_LIBINPUT_NO_DEVICES=1
    export HYPRLAND_TRACE=1 
    export AQ_TRACE=1
    exec hyprland
  '';
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <home-manager/nixos>
      ./stylix.nix
    ];

  home-manager = {
   useGlobalPkgs = true;
   useUserPackages = true;
   users.simbaclaws = import ./home.nix;
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Select internationalisation properties.
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };


  systemd.user.services.wayvnc = {
    description = "WayVNC Headless Service voor Hyprland";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    environment = {
      WLR_RENDERER = "pixman";
      XDG_RUNTIME_DIR = "/run/user/1000"; 
    };

    script = ''
      # Wacht tot Hyprland de Wayland-socket heeft aangemaakt
      while [ -z "$WAYLAND_DISPLAY" ]; do
        WAYLAND_DISPLAY=$(systemctl --user show-environment | grep '^WAYLAND_DISPLAY=' | cut -d= -f2)
        sleep 0.5
      done

      export WAYLAND_DISPLAY
      # Start wayvnc met het exacte systeempad
      exec ${pkgs.wayvnc}/bin/wayvnc -o virt-1 0.0.0.0 5900
    '';

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  services.displayManager.gdm.enable = false;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."simbaclaws" = {
    openssh.authorizedKeys.keyFiles = [
	/home/simbaclaws/.ssh/authorized_keys
    ];
    isNormalUser = true;
    description = "Hylke Hellinga";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];
    packages = with pkgs; [];
  };

  security.sudo.extraRules = [{
    users = ["simbaclaws"];
    commands = [{ command = "ALL";
    	options = ["NOPASSWD"];
	}];
  }];

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    chromium = {
      commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
    };
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

  programs.nix-ld.enable = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    gh
    gcc gnumake git curl unzip wget ripgrep fd tree-sitter
    lua-language-server stylua nixd alejandra 
    pkgs.nix-ld
    pkgs.waybar
    libnotify
    swaynotificationcenter
    awww
    kitty
    rofi
    pkgs.claude-code
    pkgs.chromium
    pkgs.networkmanagerapplet
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-wlr
    pkgs.wayvnc
  ];

  systemd.tmpfiles.rules = [
    "d /root/.config 0755 root root -" 
    "L+ /root/.config/nvim - - - - /home/simbaclaws/dotfiles/nvim"
  ];

  services.greetd = {
    enable = true;
    settings = {
      # Boot straight into Hyprland as your user — no password, no greeter:
      initial_session = {
        command = "${hypr-headless}";
        user = "simbaclaws";
      };
      # Only shown if you log out / for manual logins (optional — drop it if you never want a prompt):
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
     enable = true;
     enableSSHSupport = true;
  };

  programs.zsh.enable = true;
  users.users.simbaclaws.shell = pkgs.zsh;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 5900 ];
  networking.firewall.allowedUDPPorts = [ 22 5900 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}

