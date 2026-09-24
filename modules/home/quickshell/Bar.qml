// Pill bar in the active Omarchy theme (rounded pills, luminance
// signalling, no accent hue), with omarchy-style clickable panels: clock →
// calendar popup, audio → mixer popup, power → system menu, nixos → apps.
// All colors come from the generated Theme singleton, so theme switches
// (omarchy-theme-set) restyle the bar on rebuild.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: barRoot

    property var shell

    // ---------------- shared state (one copy for every screen) ----------
    property int cpu: 0
    property int mem: 0
    property int temp: 0
    property string netState: "off"
    property bool notifDnd: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool sinkMuted: sink && sink.audio ? sink.audio.muted : true
    readonly property real sinkVolume: sink && sink.audio ? sink.audio.volume : 0

    PwObjectTracker { objects: barRoot.sink ? [barRoot.sink] : [] }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // cpu% mem% tempC every 2s (script from modules/home/quickshell).
    Process {
        command: ["qs-bar-metrics"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ");
                if (parts.length >= 3) {
                    barRoot.cpu = parseInt(parts[0]) || 0;
                    barRoot.mem = parseInt(parts[1]) || 0;
                    barRoot.temp = parseInt(parts[2]) || 0;
                }
            }
        }
    }

    // wifi | eth | off every 5s.
    Process {
        command: ["qs-network-status"]
        running: true
        stdout: SplitParser {
            onRead: data => barRoot.netState = data.trim()
        }
    }

    // swaync waybar-protocol subscription: {"alt": "none|notification|dnd-..."}.
    Process {
        command: ["swaync-client", "-swb"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const state = JSON.parse(data);
                    barRoot.notifDnd = (state.alt || "none").indexOf("dnd") === 0;
                } catch (e) { /* ignore partial lines */ }
            }
        }
    }

    function volumeGlyph() {
        if (sinkMuted) return "\u{f0581}";
        if (sinkVolume > 0.66) return "\u{f057e}";
        if (sinkVolume > 0.33) return "\u{f0580}";
        return "\u{f057f}";
    }

    function netGlyph() {
        if (netState === "wifi") return "\u{f05a9}";
        if (netState === "eth") return "\u{f0200}";
        return "\u{f05aa}";
    }

    function batteryGlyph(pct, discharging) {
        if (!discharging) return "\u{f0084}";
        if (pct > 80) return "\u{f0079}";
        if (pct > 60) return "\u{f0081}";
        if (pct > 40) return "\u{f007f}";
        if (pct > 20) return "\u{f007d}";
        return "\u{f007a}";
    }

    // ---------------- building blocks (inline components must sit at the
    // document root) ----------------

    // Content pill: children go into the inner RowLayout; the MouseArea
    // lives outside it (explicit data list) so click and wheel handling
    // never fights the layout.
    component Pill: Rectangle {
        id: pillRoot

        default property alias content: row.data
        property alias spacing: row.spacing
        property int buttons: 0
        property bool hoverHighlight: false

        signal pressed(var mouse)
        signal wheelMoved(var wheel)

        radius: 8
        color: hoverHighlight && pillMouse.containsMouse ? Theme.selection : Theme.bgAlt
        implicitHeight: Theme.barHeight - 6
        implicitWidth: row.implicitWidth + 20

        data: [
            RowLayout {
                id: row
                anchors.centerIn: pillRoot
                spacing: 8
            },
            MouseArea {
                id: pillMouse
                anchors.fill: pillRoot
                hoverEnabled: true
                enabled: pillRoot.buttons !== 0
                acceptedButtons: pillRoot.buttons === 0 ? Qt.LeftButton : pillRoot.buttons
                cursorShape: pillRoot.buttons !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => pillRoot.pressed(mouse)
                onWheel: wheel => pillRoot.wheelMoved(wheel)
            }
        ]
    }

    // Bright square icon button (identity / power anchors).
    component BrightButton: Rectangle {
        id: brightRoot

        property string glyph: ""

        signal pressed(var mouse)

        radius: 8
        color: brightMouse.containsMouse ? Theme.fg : Theme.fgBright
        implicitHeight: Theme.barHeight - 6
        implicitWidth: 30

        data: [
            Text {
                anchors.centerIn: brightRoot
                text: brightRoot.glyph
                color: Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            },
            MouseArea {
                id: brightMouse
                anchors.fill: brightRoot
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => brightRoot.pressed(mouse)
            }
        ]
    }

    component BarText: Text {
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        verticalAlignment: Text.AlignVCenter
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panel

            required property var modelData

            readonly property var hyprMonitor: Hyprland.monitorFor(panel.screen)

            // Workspace ids shown on this bar: the ones pinned/present on
            // this monitor (global 1-10 split across monitors by the pin
            // script). Falls back to all ten if the mapping is unknown.
            function workspaceIds() {
                const out = [];
                const values = Hyprland.workspaces.values;
                for (let i = 0; i < values.length; i++) {
                    const ws = values[i];
                    if (ws.id < 1 || ws.id > 10) continue;
                    if (panel.hyprMonitor && ws.monitor && ws.monitor.name !== panel.hyprMonitor.name) continue;
                    out.push(ws.id);
                }
                out.sort((a, b) => a - b);
                if (out.length === 0) return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
                return out;
            }

            function workspaceById(id) {
                const values = Hyprland.workspaces.values;
                for (let i = 0; i < values.length; i++)
                    if (values[i].id === id) return values[i];
                return null;
            }

            screen: modelData
            visible: barRoot.shell ? barRoot.shell.barVisible : true
            color: "transparent"
            implicitHeight: Theme.barHeight

            anchors {
                top: true
                left: true
                right: true
            }

            // ---------------- left: launcher + workspaces ----------------
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                BrightButton {
                    glyph: "" // nf-linux-nixos
                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton)
                            Quickshell.execDetached(["omarchy-menu"]);
                        else
                            Quickshell.execDetached(["rofi", "-show", "drun", "-show-icons"]);
                    }
                }

                // Compact workspace pill.
                Pill {
                    spacing: 0

                    Repeater {
                        model: panel.workspaceIds()

                        Rectangle {
                            id: wsButton

                            required property int modelData

                            readonly property var ws: panel.workspaceById(modelData)
                            readonly property bool focused: Hyprland.focusedWorkspace !== null
                                && Hyprland.focusedWorkspace.id === modelData
                            readonly property bool occupied: ws !== null && ws.lastIpcObject
                                && (ws.lastIpcObject.windows || 0) > 0

                            radius: 6
                            color: focused ? Theme.fgBright : (wsMouse.containsMouse ? Theme.selection : "transparent")
                            implicitWidth: 22
                            implicitHeight: Theme.barHeight - 10

                            BarText {
                                anchors.centerIn: parent
                                text: wsButton.modelData === 10 ? "0" : String(wsButton.modelData)
                                color: wsButton.focused ? Theme.bg : (wsButton.occupied ? Theme.fg : Theme.dim)
                                font.bold: true
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Theme.focusWorkspace(wsButton.modelData)
                            }
                        }
                    }
                }
            }

            // ---------------- center: date | window title | time ----------
            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Pill {
                    buttons: Qt.LeftButton
                    hoverHighlight: true
                    onPressed: calendarPopup.visible = !calendarPopup.visible

                    BarText { text: Qt.formatDateTime(clock.date, "yyyy/MM/dd") }
                }

                Pill {
                    color: Theme.surface
                    visible: titleText.text !== ""

                    BarText {
                        id: titleText
                        readonly property var toplevel: ToplevelManager.activeToplevel
                        text: toplevel ? (toplevel.title || toplevel.appId || "") : ""
                        elide: Text.ElideRight
                        Layout.maximumWidth: 420
                        color: Theme.fgDim
                    }
                }

                Pill {
                    buttons: Qt.LeftButton
                    hoverHighlight: true
                    onPressed: calendarPopup.visible = !calendarPopup.visible

                    BarText { text: Qt.formatDateTime(clock.date, "HH.mm:ss") }
                }
            }

            // ---------------- right: metrics + controls ----------------
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // System metrics, one pill. Click → btop.
                Pill {
                    buttons: Qt.LeftButton
                    hoverHighlight: true
                    onPressed: Quickshell.execDetached(["kitty", "-e", "btop"])

                    BarText { text: "\u{f0ee0} " + barRoot.cpu + "%" }
                    BarText { text: "\u{f035b} " + barRoot.mem + "%" }
                    BarText {
                        visible: barRoot.temp > 0
                        text: "\u{f050f} " + barRoot.temp + "°"
                        color: barRoot.temp >= 90 ? Theme.fgBright : Theme.fg
                    }
                }

                // Network — click opens the rofi Wi-Fi picker.
                Pill {
                    buttons: Qt.LeftButton
                    hoverHighlight: true
                    onPressed: Quickshell.execDetached(["networkmanager_dmenu"])

                    BarText {
                        text: barRoot.netGlyph()
                        color: barRoot.netState === "off" ? Theme.dim : Theme.fg
                    }
                }

                // Audio — click toggles the mixer popup, wheel adjusts,
                // right-click mutes.
                Pill {
                    buttons: Qt.LeftButton | Qt.RightButton
                    hoverHighlight: true
                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (barRoot.sink && barRoot.sink.audio)
                                barRoot.sink.audio.muted = !barRoot.sink.audio.muted;
                        } else {
                            audioPopup.visible = !audioPopup.visible;
                        }
                    }
                    onWheelMoved: wheel => {
                        if (!barRoot.sink || !barRoot.sink.audio) return;
                        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                        barRoot.sink.audio.volume =
                            Math.max(0, Math.min(1, barRoot.sink.audio.volume + step));
                    }

                    BarText {
                        text: barRoot.volumeGlyph() + "  " + Math.round(barRoot.sinkVolume * 100) + "%"
                        color: barRoot.sinkMuted ? Theme.dim : Theme.fg
                    }
                }

                // Notifications — swaync panel / right-click DND.
                Pill {
                    buttons: Qt.LeftButton | Qt.RightButton
                    hoverHighlight: true
                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton)
                            Quickshell.execDetached(["swaync-client", "-d", "-sw"]);
                        else
                            Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
                    }

                    BarText {
                        text: barRoot.notifDnd ? "\u{f0ce4}" : "\u{f0027}"
                        color: barRoot.notifDnd ? Theme.dim : Theme.fg
                        font.pixelSize: Theme.fontSize + 2
                    }
                }

                // Battery (hidden when UPower reports nothing).
                Pill {
                    id: batteryPill

                    readonly property var dev: UPower.displayDevice
                    readonly property real pct: dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0

                    visible: dev !== null && pct > 0
                    buttons: Qt.LeftButton
                    hoverHighlight: true
                    onPressed: Quickshell.execDetached(["omarchy-notification", "battery"])

                    BarText {
                        text: barRoot.batteryGlyph(batteryPill.pct, UPower.onBattery)
                            + " " + Math.round(batteryPill.pct) + "%"
                        color: batteryPill.pct <= 15 && UPower.onBattery ? Theme.fgBright : Theme.fg
                    }
                }

                // Tray.
                Pill {
                    visible: SystemTray.items.values.length > 0
                    spacing: 10

                    Repeater {
                        model: SystemTray.items

                        Item {
                            id: trayItem

                            required property var modelData

                            implicitWidth: 16
                            implicitHeight: 16

                            IconImage {
                                anchors.fill: parent
                                source: trayItem.modelData.icon
                            }

                            QsMenuAnchor {
                                id: trayMenu
                                menu: trayItem.modelData.menu
                                anchor.window: panel
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton && !trayItem.modelData.onlyMenu) {
                                        trayItem.modelData.activate();
                                        return;
                                    }
                                    if (mouse.button === Qt.MiddleButton) {
                                        trayItem.modelData.secondaryActivate();
                                        return;
                                    }
                                    if (trayItem.modelData.hasMenu) {
                                        const pos = trayItem.mapToItem(null, 0, Theme.barHeight);
                                        trayMenu.anchor.rect.x = pos.x;
                                        trayMenu.anchor.rect.y = Theme.barHeight;
                                        trayMenu.open();
                                    }
                                }
                            }
                        }
                    }
                }

                // Power — the Omarchy system menu.
                BrightButton {
                    glyph: "⏻"
                    onPressed: Quickshell.execDetached(["omarchy-menu", "system"])
                }
            }

            // ---------------- calendar popup ----------------
            PopupWindow {
                id: calendarPopup

                property date shown: new Date()

                function monthCells() {
                    const first = new Date(shown.getFullYear(), shown.getMonth(), 1);
                    const lead = (first.getDay() + 6) % 7; // Monday-first
                    const count = new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate();
                    const cells = [];
                    for (let i = 0; i < lead; i++) cells.push(0);
                    for (let d = 1; d <= count; d++) cells.push(d);
                    return cells;
                }

                function isToday(day) {
                    const now = new Date();
                    return day > 0
                        && shown.getFullYear() === now.getFullYear()
                        && shown.getMonth() === now.getMonth()
                        && day === now.getDate();
                }

                anchor.window: panel
                anchor.rect.x: panel.width / 2 - implicitWidth / 2
                anchor.rect.y: Theme.barHeight
                implicitWidth: 280
                implicitHeight: calColumn.implicitHeight + 24
                visible: false
                color: "transparent"

                onVisibleChanged: if (visible) shown = new Date()

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    border.color: Theme.border
                    border.width: 1
                    radius: 12

                    ColumnLayout {
                        id: calColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            BarText {
                                text: "‹"
                                font.pixelSize: Theme.fontSize + 4

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.shown = new Date(
                                        calendarPopup.shown.getFullYear(),
                                        calendarPopup.shown.getMonth() - 1, 1)
                                }
                            }

                            BarText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDateTime(calendarPopup.shown, "MMMM yyyy")
                                color: Theme.fgBright
                                font.bold: true
                            }

                            BarText {
                                text: "›"
                                font.pixelSize: Theme.fontSize + 4

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.shown = new Date(
                                        calendarPopup.shown.getFullYear(),
                                        calendarPopup.shown.getMonth() + 1, 1)
                                }
                            }
                        }

                        GridLayout {
                            columns: 7
                            columnSpacing: 0
                            rowSpacing: 2
                            Layout.fillWidth: true

                            Repeater {
                                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                                BarText {
                                    required property string modelData
                                    text: modelData
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSize - 2
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }
                            }

                            Repeater {
                                model: calendarPopup.monthCells()

                                Rectangle {
                                    id: dayCell

                                    required property int modelData

                                    radius: 6
                                    color: calendarPopup.isToday(modelData) ? Theme.fgBright : "transparent"
                                    implicitHeight: 24
                                    Layout.fillWidth: true

                                    BarText {
                                        anchors.centerIn: parent
                                        text: dayCell.modelData > 0 ? String(dayCell.modelData) : ""
                                        color: calendarPopup.isToday(dayCell.modelData) ? Theme.bg : Theme.fg
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- audio popup ----------------
            PopupWindow {
                id: audioPopup

                anchor.window: panel
                anchor.rect.x: panel.width - implicitWidth - 8
                anchor.rect.y: Theme.barHeight
                implicitWidth: 300
                implicitHeight: audioColumn.implicitHeight + 24
                visible: false
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    border.color: Theme.border
                    border.width: 1
                    radius: 12

                    ColumnLayout {
                        id: audioColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            BarText {
                                text: barRoot.volumeGlyph()
                                font.pixelSize: Theme.fontSize + 4
                                color: barRoot.sinkMuted ? Theme.dim : Theme.fgBright

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (barRoot.sink && barRoot.sink.audio)
                                            barRoot.sink.audio.muted = !barRoot.sink.audio.muted;
                                    }
                                }
                            }

                            Slider {
                                id: volSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 1
                                value: barRoot.sinkVolume
                                onMoved: {
                                    if (barRoot.sink && barRoot.sink.audio)
                                        barRoot.sink.audio.volume = value;
                                }

                                background: Rectangle {
                                    x: volSlider.leftPadding
                                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                    width: volSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Theme.selection

                                    Rectangle {
                                        width: volSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: Theme.fgBright
                                    }
                                }

                                handle: Rectangle {
                                    x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Theme.fgBright
                                    border.color: Theme.border
                                }
                            }

                            BarText {
                                text: Math.round(barRoot.sinkVolume * 100) + "%"
                                color: Theme.fgDim
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 8
                            color: mixerMouse.containsMouse ? Theme.selection : Theme.bgAlt
                            implicitHeight: 30

                            BarText {
                                anchors.centerIn: parent
                                text: "Open mixer (pavucontrol)"
                                color: Theme.fg
                            }

                            MouseArea {
                                id: mixerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    audioPopup.visible = false;
                                    Quickshell.execDetached(["pavucontrol"]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
