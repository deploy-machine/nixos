//@ pragma UseQApplication
// Quickshell top bar (replaces waybar). QApplication is required so tray
// items' platform context menus render — see the note in omarchy's Tray.qml
// about QsMenu without QApplication silently showing nothing.
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool barVisible: true

    Bar {
        shell: root
    }

    // `qs ipc call bar toggle` — used by omarchy-toggle bar (SUPER+SHIFT+SPACE).
    IpcHandler {
        target: "bar"

        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
    }
}
