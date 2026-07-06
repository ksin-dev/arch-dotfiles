import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

PanelWindow {
    id: root

    required property var modelData
    property var shellConfig: ({})
    property real nowSeconds: Date.now() / 1000
    property string rawState: monitorMode.value.trim()
    property var stateParts: rawState.length > 0 ? rawState.split("|") : []
    property string mode: stateParts.length > 0 ? stateParts[0] : ""
    property string label: stateParts.length > 1 ? stateParts[1] : modeLabel(mode)
    property real shownAt: stateParts.length > 2 ? Number(stateParts[2]) : 0
    property var modes: [
        { id: "extend", label: "Extend" },
        { id: "mirror", label: "Duplicate" },
        { id: "primary", label: "Primary only" },
        { id: "secondary", label: "Second only" }
    ]

    screen: modelData
    visible: mode.length > 0 && shownAt > 0 && nowSeconds - shownAt < visibleSeconds()
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
    }

    margins {
        top: 88
    }

    implicitWidth: indicator.implicitWidth
    implicitHeight: 78

    function configValue(path, fallbackValue) {
        const parts = path.split(".");
        let cursor = shellConfig;

        for (let i = 0; i < parts.length; i++) {
            if (cursor === null || typeof cursor !== "object" || !(parts[i] in cursor))
                return fallbackValue;
            cursor = cursor[parts[i]];
        }

        return cursor;
    }

    function configNumber(path, fallbackValue, minValue, maxValue) {
        const raw = Number(configValue(path, fallbackValue));
        let value = Number.isFinite(raw) ? raw : fallbackValue;
        if (minValue !== undefined)
            value = Math.max(minValue, value);
        if (maxValue !== undefined)
            value = Math.min(maxValue, value);
        return value;
    }

    function visibleSeconds() {
        return configNumber("monitorMode.visibleSeconds", 2.2, 0.5, 10);
    }

    function modeLabel(value) {
        for (let i = 0; i < modes.length; i++) {
            if (modes[i].id === value)
                return modes[i].label;
        }
        return "Display mode";
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: root.nowSeconds = Date.now() / 1000
    }

    PollText {
        id: monitorMode
        interval: 150
        command: ["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/monitor-mode-indicator\"; [ -r \"$state\" ] && cat \"$state\""]
    }

    Rectangle {
        id: indicator

        implicitWidth: Math.max(titleRow.implicitWidth, modeRow.implicitWidth) + 28
        width: implicitWidth
        height: 78
        radius: 12
        color: Theme.bg
        border.color: Theme.accent
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 9

            Row {
                id: titleRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    text: "▣"
                    color: Theme.accent
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    text: root.label
                    color: Theme.fg
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Row {
                id: modeRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: root.modes

                    Rectangle {
                        required property var modelData
                        property bool active: modelData.id === root.mode

                        width: 74
                        height: 26
                        radius: 8
                        color: active ? Theme.accent : Theme.surface
                        border.color: active ? Theme.accent : Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: parent.active ? Theme.accentFg : Theme.fgMuted
                            font.pixelSize: 8
                            font.bold: parent.active
                        }
                    }
                }
            }
        }
    }
}
