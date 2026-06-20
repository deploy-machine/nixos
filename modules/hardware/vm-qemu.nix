{ pkgs, ... }:
{
  # QEMU/KVM guest agent + SPICE clipboard/resolution sync.
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  environment.systemPackages = with pkgs; [
    spice-vdagent
  ];
}
