{ inputs, lib, username, ... }:
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
  # Partition under /boot/asahi; the module auto-detects that path, so no
  # explicit hardware.asahi.peripheralFirmwareDirectory is needed here.

  # Broadcom WiFi on Apple Silicon: wpa_supplicant doesn't do WPA3, iwd does.
  networking.networkmanager.wifi.backend = "iwd";

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
