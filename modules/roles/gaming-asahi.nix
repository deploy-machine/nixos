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
#   https://github.com/vidhanio/vidhanix/blob/main/modules/programs/steam/packages/muvm-steam.nix
#
# After rebuild the wrappers `steam`, `steam-run`, and (when allowUnfree)
# `zoom` are on PATH and Just Work — they launch the cross-imported x86_64
# packages inside muvm, with the FEX rootfs auto-downloaded on first user
# login by fex-rootfs-bootstrap.service.
#
# Caveats:
#   - Kernel-mode anti-cheat (EAC/BattlEye in kernel mode) is broken.
#     User-mode EAC via Proton works for some titles. VAC works.
#   - Honeykrisp is Vulkan 1.3 conformant; lacks sparse residency and
#     ray-tracing extensions. DXVK works; vkd3d-proton works for non-RT DX12.
#   - muvm --mem is a CEILING, not a reservation: libkrun balloons memory
#     in/out of the guest as the workload demands, so the default 80% only
#     materializes if the guest actually touches that many pages. We rely on
#     the default plus host-side zram + 8 GiB swapfile (see apple-silicon.nix)
#     to absorb spikes. Earlier revisions pinned --mem to 8 GiB on the theory
#     that 80% would OOM the host, but that predated zramSwap landing and
#     also caused DXVK/vkd3d shader compilation (8-16 parallel wine workers)
#     to crash the game mid-cache-build by hitting the guest cap.
#   - We set --vram to 8 GiB explicitly. The default is 50% of host RAM (~7
#     GiB on a 16 GB host) reported to userspace as Vulkan heap size; some
#     Steam titles' pre-flight "system requirements" check trips on the
#     under-8-GiB figure. UMA means VRAM is just system RAM so this is honest.
#   - Do NOT enable hardware.graphics.enable32Bit on the aarch64 host —
#     32-bit graphics live INSIDE the muvm guest via FEX, and there is no
#     aarch64 i686 Mesa to pair with on the host.

let
  allowUnfree = config.nixpkgs.config.allowUnfree or false;

  # Cross-import x86_64 nixpkgs against this host's nixpkgs source. The
  # closures (steam, zoom-us, mesa, pkgsi686Linux.mesa) are substituted
  # binary from cache.nixos.org — no local x86 builds.
  pkgs-x86_64 = import pkgs.path {
    system = "x86_64-linux";
    config = { inherit allowUnfree; };
  };

  # muvm init script: lands inside the guest before the target binary runs.
  # The Steam/Proton loader looks up Vulkan ICDs under /run/opengl-driver{,-32}
  # by NixOS convention; the guest doesn't inherit those symlinks so we plant
  # them here from the cross-imported host mesa packages. Mesa loads
  # virtio_gpu_drm at runtime, which talks native-context to the host's
  # Honeykrisp driver via virtio-gpu.
  muvmInit = pkgs.writeShellScript "muvm-init.sh" ''
    ln -snf ${pkgs-x86_64.mesa}                  /run/opengl-driver
    ln -snf ${pkgs-x86_64.pkgsi686Linux.mesa}    /run/opengl-driver-32
  '';

  # Pulse-over-virtio doesn't survive SHM page swaps; muvm forwards pulse via
  # a unix socket and SHM negotiation hangs the client. Disabling SHM forces
  # everything down the socket and audio works.
  muvmPulseConf = pkgs.writeText "pulse-no-shm.conf" ''
    enable-shm=no
  '';

  # vidhanio's wrapMuvm pattern: symlinkJoin the original package, rename its
  # entrypoint binary to .<name>-wrapped, then planted a makeWrapper that
  # execs muvm with the init script + pulse env + the wrapped binary as the
  # in-guest command. Net effect: typing `steam` on the host execs muvm,
  # which boots the microVM and runs the x86 steam loader inside it.
  wrapMuvm = pkg: extraAttrs:
    let program = pkg.meta.mainProgram or pkg.pname;
    in pkgs.symlinkJoin ({
      inherit (pkg) pname version;
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        mv $out/bin/${program} $out/bin/.${program}-wrapped
        makeWrapper ${lib.getExe pkgs.muvm} $out/bin/${program} \
          --argv0 ${program} \
          --add-flags "--vram 8192 -x ${muvmInit} -e PULSE_CLIENTCONFIG=${muvmPulseConf} $out/bin/.${program}-wrapped"
      '';
      inherit (pkg) meta;
    } // extraAttrs);

  muvm-steam = wrapMuvm pkgs-x86_64.steam {
    name = "muvm-${pkgs-x86_64.steam.name}";
    # `steam-run` (the runtime sandbox) gets the same treatment so `steam-run
    # <some-x86-binary>` works for Proton-less workloads.
    passthru.run = wrapMuvm pkgs-x86_64.steam.run { };
    meta = pkgs-x86_64.steam.meta // {
      description = "Steam, wrapped to run in muvm for Apple Silicon support";
      platforms   = [ "aarch64-linux" ];
      mainProgram = "steam";
    };
  };

  muvm-zoom = wrapMuvm pkgs-x86_64.zoom-us {
    name = "muvm-${pkgs-x86_64.zoom-us.name}";
    meta = pkgs-x86_64.zoom-us.meta // {
      description = "Zoom, wrapped to run in muvm for Apple Silicon support";
      platforms   = [ "aarch64-linux" ];
      mainProgram = "zoom";
    };
  };
in
{
  assertions = [{
    assertion = pkgs.stdenv.hostPlatform.isAarch64;
    message = "The 'gaming-asahi' role is aarch64-only (muvm + FEX). For x86_64 hosts use 'gaming' instead.";
  }];

  # nixos-25.11 ships libkrun 1.15.1, which has a KVM_SET_USER_MEMORY_REGION2
  # EINVAL bug on Asahi (muvm issue #213). The fix landed in libkrun 1.17+ and
  # 25.11 has no backport, so we bump libkrun → 1.18.1 and libkrunfw → 5.5.0
  # locally. Both also moved orgs from "containers" → "libkrun" on GitHub,
  # which is why owner is overridden alongside version/hash. libkrunfw bundles
  # the guest kernel image, so the kernel tarball moves with it.
  #
  # muvm 0.4.1 (25.11) hardcodes eth0 as interface index 2, an assumption that
  # newer libkrun/libkrunfw break (muvm PR #226). On the libkrun 1.18 bump the
  # guest's eth0 stays DOWN, passt is reachable but the link never comes up,
  # so DNS/HTTP fail (e.g. Steam updater: "http error 0"). Bumping muvm to
  # 0.6.0 picks up the dynamic interface-index lookup and restores networking.
  nixpkgs.overlays = [
    (final: prev: {
      libkrunfw = prev.libkrunfw.overrideAttrs (_: rec {
        version = "5.5.0";
        src = prev.fetchFromGitHub {
          owner = "libkrun";
          repo = "libkrunfw";
          tag = "v${version}";
          hash = "sha256-MF1oDqhS4xqyQJIntl4DBfDBvuqCxQn9Zdws82Tn5Gg=";
        };
        kernelSrc = prev.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-6.12.91.tar.xz";
          hash = "sha256-D/KrnhafnxlIVXRx+7RQ0wGPjFt3yvKI4aOYJYJZeWk=";
        };
      });
      libkrun = prev.libkrun.overrideAttrs (_: rec {
        version = "1.18.1";
        src = prev.fetchFromGitHub {
          owner = "libkrun";
          repo = "libkrun";
          tag = "v${version}";
          hash = "sha256-JXbCDByrWhmcEqwREX/kgVAtS4K8blfpjknTdJwQCLo=";
        };
        cargoDeps = prev.rustPlatform.fetchCargoVendor {
          inherit src;
          hash = "sha256-dfIe2pl957MRcY1hIv6wPPX/4He+ou+eCZLbylVeGAE=";
        };
      });
      muvm = prev.muvm.overrideAttrs (_: rec {
        version = "0.6.0";
        src = prev.fetchFromGitHub {
          owner = "AsahiLinux";
          repo = "muvm";
          tag = "muvm-${version}";
          hash = "sha256-9lrJ622kPCfVo/QrtRmLLQs5rjh3FJE8EelqPHdU/vc=";
        };
        # Override cargoDeps directly (not cargoHash) — overrideAttrs cannot
        # rewrite the vendor derivation that buildRustPackage closes over at
        # eval time, so a bumped src would otherwise keep vendoring against
        # 0.4.1's Cargo.lock. Mirror the libkrun pattern above.
        cargoDeps = prev.rustPlatform.fetchCargoVendor {
          inherit src;
          name = "muvm-${version}-vendor";
          hash = "sha256-Ij2Tdn7HhQ815mXCuamfej4KpDjHALTusrx06t8M87w=";
        };
        # muvm 0.6.0 removed all sysctl calls, so the nixpkgs postPatch line
        # that substitutes /sbin/sysctl into crates/muvm/src/monitor.rs now
        # fails with "pattern doesn't match". Reduce postPatch to just the
        # two substitutions that still apply (systemd-udevd + fex share dir).
        postPatch = ''
          substituteInPlace crates/muvm/src/guest/bin/muvm-guest.rs \
            --replace-fail "/usr/lib/systemd/systemd-udevd" "${prev.systemd}/lib/systemd/systemd-udevd"
          substituteInPlace crates/muvm/src/guest/mount.rs \
            --replace-fail "/usr/share/fex-emu" "${prev.fex}/share/fex-emu"
        '';
      });
    })
  ];

  # KVM + virtio + user namespaces are already configured by linux-asahi;
  # we just need to make sure the kvm module is loaded so /dev/kvm exists.
  boot.kernelModules = [ "kvm" ];

  # FEX uses FUSE for its rootfs overlay. NixOS's fuse setup is fine; this
  # just makes mounts visible across user namespaces (muvm needs it).
  programs.fuse.userAllowOther = true;

  # x86_64 build/run capability (qemu binfmt + nix.settings.extra-platforms)
  # is provided unconditionally by modules/hardware/apple-silicon.nix — see
  # the boot.binfmt.emulatedSystems block there for the rationale. Don't
  # duplicate it here.

  # Do NOT enable programs.steam here — the upstream module pulls the
  # x86_64-only steam derivation + 32-bit graphics, both of which fail to
  # evaluate on aarch64. The muvm-steam wrapper above is the substitute.
  environment.systemPackages = with pkgs; [
    muvm                # libkrun wrapper, ships passt + fex on aarch64
    fex                 # x86_64 / i386 user-mode emulator
    squashfsTools       # FEXRootFSFetcher shells out to `unsquashfs` to extract its rootfs
    squashfuse          # FEXRootFSFetcher's startup probe requires it even when -x is used
    mangohud            # works under DXVK/vkd3d-proton inside the guest
    # protonup-qt is x86-only in nixpkgs; install it inside the muvm guest
    # (Fedora rootfs's `dnf install protonup-qt`) rather than on the host.
  ] ++ lib.optionals allowUnfree [
    muvm-steam          # `steam` -> muvm -> x86 steam loader
    muvm-zoom           # `zoom`  -> muvm -> x86 zoom-us
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

  # First-time FEX rootfs bootstrap. FEX needs an x86_64 Linux filesystem
  # image to provide /lib, /usr/lib etc. for the binaries it's interpreting.
  # FEXRootFSFetcher is interactive by default; the flags here select the
  # first available distro non-interactively and extract the squashfs. ~1.5GB
  # download, ~10 min on a typical home connection. The ConditionPathExists
  # gate makes the unit a no-op once Config.json exists.
  #
  # Runs as the target user via home-manager so $HOME is the right path and
  # the rootfs lands in the user's own ~/.fex-emu (not /root or /var/empty).
  home-manager.users.${username} = lib.mkIf allowUnfree {
    systemd.user.services.fex-rootfs-bootstrap = {
      Unit = {
        Description = "First-run FEX RootFS download for x86 emulation";
        Wants = [ "network-online.target" ];
        After = [ "network-online.target" ];
        # Skip if Config.json already exists — FEXRootFSFetcher writes it on
        # success, so its presence is a reliable "rootfs is ready" marker.
        # FEX uses ~/.config/.fex-emu (XDG) for config and ~/.local/share/.fex-emu
        # for the rootfs squashfs/dir, not ~/.fex-emu.
        ConditionPathExists = "!%h/.config/.fex-emu/Config.json";
      };
      Service = {
        Type = "oneshot";
        # libnotify lets us tell the user what's happening; without this the
        # ~1.5GB download would just look like nothing's happening for 10min.
        # `-` prefix: notification daemon may not be up yet at login, and a
        # missing notification must not block the actual rootfs download.
        ExecStartPre = "-${pkgs.libnotify}/bin/notify-send -u low -i system-software-install 'FEX x86 emulator' 'Downloading rootfs (~1.5GB). First-run only.'";
        ExecStart = "${pkgs.fex}/bin/FEXRootFSFetcher -y -x --distro-list-first --force-ui=tty";
        ExecStartPost = "-${pkgs.libnotify}/bin/notify-send -u low -i emblem-default 'FEX x86 emulator' 'Rootfs ready — Steam and Zoom can launch now.'";
        RemainAfterExit = true;
        # The download is on the slow side and we don't want systemd killing
        # it. 1 hour ceiling is generous.
        TimeoutStartSec = "1h";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
