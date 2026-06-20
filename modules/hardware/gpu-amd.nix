{ pkgs, ... }:
{
  # Mesa provides RADV (Vulkan) and radeonsi (OpenGL) — both come in via
  # hardware.graphics.enable, so the module body stays tiny. ROCm OpenCL
  # ICD is the only extra worth pulling in for compute workloads.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  # amdvlk was removed from nixpkgs (AMD deprecated it). If you want it back
  # later, install it as a user package and switch via `AMD_VULKAN_ICD=AMDVLK`.
}
