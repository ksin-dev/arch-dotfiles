import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

PanelWindow {
    id: root

    required property var modelData
    property var shellConfig: ({})
    property string mode: {
        const value = submap.value.trim();
        return value === "default" || value === "reset" ? "" : value;
    }

    screen: modelData
    visible: mode.length > 0
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
    }

    margins {
        top: 48
    }

    implicitWidth: indicator.implicitWidth
    implicitHeight: 34

    function modeLabel(value) {
        if (value === "music")
            return "Music mode";
        if (value === "resize")
            return "Resize mode";
        return `${value} mode`;
    }

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

    function appearanceFontScale() {
        return configNumber("appearance.font.scale", 1, 0.5, 2.5);
    }

    function fontTokenSize(path, fallbackValue, minValue, maxValue, localScale) {
        const base = configNumber(path, fallbackValue, minValue, maxValue);
        const scale = Number.isFinite(Number(localScale)) ? Number(localScale) : 1;
        return Math.max(minValue || 7, Math.round(base * scale * appearanceFontScale()));
    }

    function submapFontScale() {
        return configNumber("submap.font.scale", 1, 0.5, 2.5);
    }

    function submapIconFontSize() {
        return fontTokenSize("submap.font.iconSize", 10, 7, 34, submapFontScale());
    }

    function submapLabelFontSize() {
        return fontTokenSize("submap.font.labelSize", 8, 6, 32, submapFontScale());
    }

    function submapHintFontSize() {
        return fontTokenSize("submap.font.hintSize", 7, 6, 28, submapFontScale());
    }

    PollText {
        id: submap
        interval: 150
        command: ["sh", "-c", "hyprctl -j submap 2>/dev/null | tr -d '\"'"]
    }

    Rectangle {
        id: indicator

        implicitWidth: row.implicitWidth + 22
        width: implicitWidth
        height: 34
        radius: 12
        color: Theme.bg
        border.color: root.mode === "music" ? Theme.accent2 : Theme.accent
        border.width: 1

        Row {
            id: row
            anchors.centerIn: parent
            height: 22
            spacing: 8

            Item {
                width: 18
                height: row.height
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.fill: parent
                    text: root.mode === "music" ? "♪" : root.mode === "resize" ? "↔" : "•"
                    color: Theme.accent
                    font.pixelSize: root.submapIconFontSize()
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                height: row.height
                anchors.verticalCenter: parent.verticalCenter
                text: root.modeLabel(root.mode)
                color: Theme.fg
                font.pixelSize: root.submapLabelFontSize()
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: 34
                height: 20
                radius: 7
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.fill: parent
                    text: "Esc"
                    color: Theme.fgMuted
                    font.pixelSize: root.submapHintFontSize()
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
