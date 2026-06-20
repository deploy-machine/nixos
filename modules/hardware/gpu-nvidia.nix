{ config, ... }:
{
  # Kernel side: the proprietary driver provides nvidia-drm modesetting which
  # Wayland compositors (Hyprland included) require.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;   # flip on for laptops with NVIDIA Optimus
    open = false;                     # set true if you want the open kernel module (Turing+)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Wayland-on-NVIDIA tweaks. WLR_NO_HARDWARE_CURSORS works around a long-
  # standing wlroots cursor glitch; the GBM/GLX vars route hardware accel
  # through the NVIDIA stack rather than llvmpipe.
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
}
