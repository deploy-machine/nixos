{ config, lib, pkgs, ... }:
{
  # Steam needs allowUnfree. The bootstrap should keep these consistent, but
  # if the host opted out we silently skip enabling Steam rather than failing
  # the build.
  programs.steam = lib.mkIf config.nixpkgs.config.allowUnfree {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;          # adds a "Gamescope Session" entry to greetd
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # Steam Input + non-Steam controllers (Xbox via xpadneo, Switch Pro via
  # hid-nintendo, DualShock/DualSense via the kernel's hid-playstation).
  hardware.steam-hardware.enable = true;
  hardware.xpadneo.enable = true;

  # Bluetooth for wireless controllers.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";  # audio profile bits
  };
  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    lutris
    protonup-qt
  ];
}
