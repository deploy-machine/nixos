{ inputs, lib, pkgs, username, ... }:
{
  # Pulls the upstream Asahi kernel (linux-asahi), m1n1 / u-boot, peripheral
  # firmware extraction, and the Mesa overlay that exposes the Apple GPU
  # driver. Since Mesa 25.1 the GPU driver is upstream by default, so there
  # are no longer any useExperimentalGPUDriver / withRust knobs to flip.
  imports = [ inputs.nixos-apple-silicon.nixosModules.apple-silicon-support ];

  # Pinned to the Asahi installer ISO's release. Overrides base.nix's
  # mkDefault "26.05". This is per-install state — once a host boots on a
  # given stateVersion, it can never move (esp. backwards) without
  # corrupting persistent state. The home-manager equivalent is set below
  # because HM 25.11 rejects any value newer than "25.11".
  system.stateVersion = "25.11";
  home-manager.users.${username}.home.stateVersion = "25.11";

  # The Asahi installer drops extracted firmware blobs on the EFI System
  # Partition under /boot/asahi. Two upstream-defect interactions force the
  # explicit path-literal form here:
  #
  #   1. The upstream auto-detect uses builtins.pathExists on a Nix path
  #      literal, which silently returns false under flake pure-eval — the
  #      default falls back to null and the peripheral-firmware assertion
  #      fires even when the files are right there.
  #   2. A string ("/boot/asahi") would silence (1) but the firmware-
  #      extraction derivation runs in the Nix build sandbox, where /boot
  #      isn't mounted — tar fails with "Cannot open: No such file".
  #
  # The path literal triggers store-import of /boot/asahi at evaluation
  # time so the sandboxed builder can read it. Because /boot/asahi is
  # outside the flake source, this requires `--impure` on rebuilds
  # (run.sh adds it automatically when Apple Silicon is detected).
  hardware.asahi.peripheralFirmwareDirectory = /boot/asahi;

  # Broadcom WiFi on Apple Silicon: wpa_supplicant doesn't do WPA3, iwd does.
  networking.networkmanager.wifi.backend = "iwd";

  # Register qemu-user as the x86_64 binfmt handler so the host can build
  # (and, if needed, run) x86_64 binaries under emulation. Asahi is aarch64-
  # only and a lot of useful software is x86-only in nixpkgs; even when most
  # of a closure substitutes binary from cache, some wrapper derivations
  # (buildFHSEnv's gsettings-schemas-directory, *-wrapped, *-init glue) are
  # `allowSubstitutes = false` and MUST build locally. Without binfmt, those
  # builds fail with "required system: x86_64-linux ... current: aarch64".
  # `boot.binfmt.emulatedSystems` also adds x86_64-linux to
  # nix.settings.extra-platforms automatically.
  #
  # Runtime note: roles.gaming-asahi routes Steam/Zoom through muvm + FEX,
  # not host qemu — the muvm wrapper execs the x86 entrypoint inside the
  # microVM, where FEX is the registered binfmt handler. The host qemu
  # registration here is for build-time emulation and as a fallback for
  # one-off x86 binaries outside the muvm/FEX path.
  boot.binfmt.emulatedSystems = [ "x86_64-linux" ];

  # APFS (macOS filesystem) read access. The mainline Linux kernel has no
  # APFS driver. apfs-fuse is a userspace FUSE driver that mounts APFS
  # containers read-only (write support is experimental upstream and not
  # exposed by default — safe for dual-boot Asahi users who want to read
  # files off their macOS partition). The kernel-module alternative
  # (linux-apfs-rw) is out-of-tree and would force linux-asahi rebuilds,
  # losing the cachix substituter for kernel updates, so FUSE wins.
  #
  # Usage (manual mount — no fstab entry because device paths vary per host):
  #     lsblk -f                                  # find the APFS partition
  #     mkdir -p ~/macos
  #     apfs-fuse /dev/nvme0n1p3 ~/macos          # read-only by default
  #     fusermount -u ~/macos                     # unmount
  # If the container has multiple volumes (Data, Preboot, Recovery, VM),
  # pass `-v <index>` to select one; `apfs-fuse -l /dev/...` lists them.
  environment.systemPackages = [ pkgs.apfs-fuse ];

  # Asahi installs ship with zero swap, so the kernel has nowhere to spill
  # under memory pressure and reaches straight for the OOM-killer. The muvm
  # microVM (gaming-asahi role) is the most common trigger — its libkrun
  # guest pins anonymous RSS that the host can't reclaim — but heavy browser
  # tabs and Nix builds hit the same wall. Two layers of relief:
  #
  #   1. zramSwap: compressed in-RAM swap (zstd, ~2-3× compression). No SSD
  #      wear, fast pages-out for cold anon pages. Default priority 5 — used
  #      first under pressure.
  #   2. /var/lib/swapfile (8 GiB): real disk swap as a last-resort backstop
  #      for runaway allocations that overflow zram. Lower priority than
  #      zram, so only touched when zram is full.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 8 * 1024; # MiB
  }];

  # Building linux-asahi + Mesa from source on a laptop is hours of wall-clock
  # time. The community cache ships pre-built kernels keyed to specific
  # nixpkgs revisions. Trusted-public-key is required even on a flake-pinned
  # config because nix verifies signatures before substituting.
  nix.settings = {
    extra-substituters = [ "https://nixos-apple-silicon.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };
}
