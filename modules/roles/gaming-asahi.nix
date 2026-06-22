{ config, lib, pkgs, username, ... }:

# Steam on Apple Silicon NixOS via the Asahi-canonical muvm + FEX stack.
#
# Stack: libkrun microVM (4K-page guest, virtiofs-mounted host /nix/store) +
# virtio-gpu DRM native context to the host Honeykrisp driver + FEX-Emu for
# x86_64 + i386 binfmt inside the guest + Wine/Proton + DXVK/vkd3d-proton.
# References:
#   https://asahilinux.org/2024/10/aaa-gaming-on-asahi-linux/
#   https://asahilinux.org/2024/12/muvm-x11-bridging/
#   https://github.com/AsahiLinux/muvm
#
# Usage after rebuild:
#   FEXRootFSFetcher                    # one-time, populates ~/.fex-emu/RootFS/
#   muvm -- steam                       # runs an x86_64 steam wrapper in the VM
#   muvm -t -i FEXBash                  # interactive x86_64 shell, useful for debug
#
# Wrapping a `steam` binary is left to the user — the two practical paths are:
#   1. A Fedora rootfs inside the FEX guest with `dnf install steam` (Asahi
#      Linux's reference setup; works out of the box with binfmt-dispatcher).
#   2. A cross-imported pkgsCross.gnu64.steam wrapped with `muvm -x init.sh`,
#      see https://github.com/vidhanio/vidhanix/blob/main/modules/programs/steam/packages/muvm-steam.nix
#      for a reference Nix implementation.
#
# Caveats:
#   - Kernel-mode anti-cheat (EAC/BattlEye in kernel mode) is broken.
#     User-mode EAC via Proton works for some titles. VAC works.
#   - Honeykrisp is Vulkan 1.3 conformant; lacks sparse residency and
#     ray-tracing extensions. DXVK works; vkd3d-proton works for non-RT DX12.
#   - Default muvm --mem is 80% of host RAM; lower with `muvm --mem N` on
#     8 GB machines (your 16" M1 Pro/Max has 16+ GB so the default is fine).
#   - Do NOT enable hardware.graphics.enable32Bit on the aarch64 host —
#     32-bit graphics live INSIDE the muvm guest via FEX, and there is no
#     aarch64 i686 Mesa to pair with on the host.

{
  assertions = [{
    assertion = pkgs.stdenv.hostPlatform.isAarch64;
    message = "The 'gaming-asahi' role is aarch64-only (muvm + FEX). For x86_64 hosts use 'gaming' instead.";
  }];

  # KVM + virtio + user namespaces are already configured by linux-asahi;
  # we just need to make sure the kvm module is loaded so /dev/kvm exists.
  boot.kernelModules = [ "kvm" ];

  # FEX uses FUSE for its rootfs overlay. NixOS's fuse setup is fine; this
  # just makes mounts visible across user namespaces (muvm needs it).
  programs.fuse.userAllowOther = true;

  # Do NOT enable programs.steam here — the upstream module pulls the
  # x86_64-only steam derivation + 32-bit graphics, both of which fail to
  # evaluate on aarch64. Steam lives inside the muvm guest instead.
  environment.systemPackages = with pkgs; [
    muvm                # libkrun wrapper, ships passt + fex on aarch64
    fex                 # x86_64 / i386 user-mode emulator
    mangohud            # works under DXVK/vkd3d-proton inside the guest
    # protonup-qt is x86-only in nixpkgs; install it inside the muvm guest
    # (e.g. via Fedora's `dnf install protonup-qt`) rather than on the host.
  ];

  # Controllers and bluetooth are host-side (USB/BT stack), shared with the
  # x86 gaming role.
  hardware.steam-hardware.enable = true;
  hardware.xpadneo.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };
  services.blueman.enable = true;

  # /dev/kvm is owned by group kvm; /dev/dri/* by render+video. Without these
  # the user can't open the VM or pass GPU access through to it.
  users.users.${username}.extraGroups = [ "kvm" "render" "video" ];
}
