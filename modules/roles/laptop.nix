{ pkgs, ... }:
{
  # TLP for power management. Conflicts with power-profiles-daemon, so we
  # turn the latter off explicitly.
  services.tlp.enable = true;
  services.power-profiles-daemon.enable = false;

  # Lid switch: suspend on battery and on AC, ignore when docked (external
  # monitor connected).
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "suspend";
    lidSwitchDocked = "ignore";
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    acpi
    powertop
    light
  ];
}
