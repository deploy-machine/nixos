{ ... }:
{
  # Guest additions: clipboard, drag-and-drop, dynamic resolution, shared
  # folders. The host machine still needs the matching VBox version.
  virtualisation.virtualbox.guest = {
    enable = true;
    dragAndDrop = true;
  };
}
