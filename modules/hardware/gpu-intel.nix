{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Gen 9+ (Skylake/Kaby Lake and newer) — modern VA-API driver
      intel-media-driver
      # Legacy VA-API fallback for some older apps
      libvdpau-va-gl
    ];
  };

  # Helps with newer Intel iGPUs on Wayland.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
