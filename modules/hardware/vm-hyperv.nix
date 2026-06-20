{ ... }:
{
  # Hyper-V integration services: time sync, key/value pair exchange, dynamic
  # memory, file copy, etc. Loads hv_balloon / hv_netvsc / hv_storvsc /
  # hv_utils kernel modules.
  virtualisation.hypervGuest.enable = true;

  # NOTE: "Enhanced Session" (Hyper-V's native console with clipboard + audio
  # passthrough) goes through xrdp, which doesn't play well with a Wayland-
  # only Hyprland setup. For remote control on a Hyper-V guest, prefer the
  # headless role + wayvnc (already wired up by modules/roles/headless.nix).
}
