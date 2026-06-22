{ pkgs, ... }:
{
  # TLP for power management. Conflicts with power-profiles-daemon, so we
  # turn the latter off explicitly.
  services.tlp.enable = true;
  services.power-profiles-daemon.enable = false;

  # Lid switch: suspend on battery and on AC, ignore when docked (external
  # monitor connected). The top-level lidSwitch* options were renamed to
  # services.logind.settings.Login.HandleLidSwitch* in 25.11; the old names
  # still work via aliases but warn on every eval.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    acpi
    powertop
    light
  ];
}
