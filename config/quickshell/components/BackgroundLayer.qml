import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

PanelWindow {
    id: root

    required property var modelData
    property var shellConfig: ({})
    property var monitorConfig: ({})
    property real phase: 0

    screen: modelData
    visible: backgroundEnabled()
    color: "transparent"
    focusable: false
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function screenName() {
        if (modelData && modelData.name !== undefined && modelData.name.length > 0)
            return modelData.name;
        return "";
    }

    function shellQuote(value) {
        return "'" + `${value}`.replace(/'/g, "'\\''") + "'";
    }

    function lookupConfigValue(source, path) {
        const parts = path.split(".");
        let cursor = source;

        for (let i = 0; i < parts.length; i++) {
            if (cursor === null || typeof cursor !== "object" || !(parts[i] in cursor))
                return ({ found: false, value: null });
            cursor = cursor[parts[i]];
        }

        return ({ found: true, value: cursor });
    }

    function monitorInlineConfigObject() {
        const name = screenName();
        if (name.length === 0 || !shellConfig || typeof shellConfig !== "object")
            return ({});

        const monitors = shellConfig.monitors || {};
        if (!monitors || typeof monitors !== "object" || !(name in monitors))
            return ({});

        return monitors[name] || {};
    }

    function configValue(path, fallbackValue) {
        const sources = [monitorConfig, monitorInlineConfigObject(), shellConfig];

        for (let i = 0; i < sources.length; i++) {
            const result = lookupConfigValue(sources[i], path);
            if (result.found)
                return result.value;
        }

        return fallbackValue;
    }

    function globalConfigValue(path, fallbackValue) {
        const result = lookupConfigValue(shellConfig, path);
        return result.found ? result.value : fallbackValue;
    }

    function configBool(path, fallbackValue) {
        const value = configValue(path, fallbackValue);
        return value === true || value === "true" || value === 1;
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

    function globalConfigBool(path, fallbackValue) {
        const value = globalConfigValue(path, fallbackValue);
        return value === true || value === "true" || value === 1;
    }

    function globalConfigNumber(path, fallbackValue, minValue, maxValue) {
        const raw = Number(globalConfigValue(path, fallbackValue));
        let value = Number.isFinite(raw) ? raw : fallbackValue;
        if (minValue !== undefined)
            value = Math.max(minValue, value);
        if (maxValue !== undefined)
            value = Math.min(maxValue, value);
        return value;
    }

    function appearanceAnimationsEnabled() {
        return globalConfigBool("appearance.anim.enabled", true);
    }

    function appearanceDuration(baseMs) {
        if (!appearanceAnimationsEnabled())
            return 0;

        return Math.round(baseMs * globalConfigNumber("appearance.anim.durationScale", 1, 0.15, 3));
    }

    function appearanceRounding(baseRadius) {
        return Math.max(0, Math.round(baseRadius * globalConfigNumber("appearance.rounding", 1, 0, 2)));
    }

    function configString(path, fallbackValue) {
        const value = configValue(path, fallbackValue);
        if (typeof value !== "string" || value.length === 0)
            return fallbackValue;
        return value;
    }

    function backgroundEnabled() {
        return configBool("background.enabled", false);
    }

    function desktopClockEnabled() {
        return configBool("background.desktopClock.enabled", false);
    }

    function visualiserEnabled() {
        return configBool("background.visualiser.enabled", false);
    }

    function clockPosition() {
        return configString("background.desktopClock.position", "bottom-right");
    }

    function clockScale() {
        return configNumber("background.desktopClock.scale", 1, 0.6, 2.2);
    }

    function appearanceFontScale() {
        return globalConfigNumber("appearance.font.scale", 1, 0.5, 2.5);
    }

    function fontTokenSize(path, fallbackValue, minValue, maxValue, localScale) {
        const base = configNumber(path, fallbackValue, minValue, maxValue);
        const scale = Number.isFinite(Number(localScale)) ? Number(localScale) : 1;
        return Math.max(minValue || 7, Math.round(base * scale * appearanceFontScale()));
    }

    function desktopClockTimeFontSize() {
        return fontTokenSize("background.desktopClock.font.timeSize", 62, 20, 140, 1);
    }

    function desktopClockDateFontSize() {
        return fontTokenSize("background.desktopClock.font.dateSize", 18, 8, 60, 1);
    }

    function visualiserBarCount() {
        return Math.round(configNumber("services.visualiserBars", 42, 12, 96));
    }

    function visualiserOpacity() {
        return configNumber("background.visualiser.opacity", 0.26, 0.05, 0.8);
    }

    function visualiserHeight() {
        return Math.round(configNumber("background.visualiser.height", 150, 60, 360));
    }

    function clockHorizontalAnchor() {
        const pos = clockPosition();
        if (pos.indexOf("left") !== -1)
            return Text.AlignLeft;
        if (pos.indexOf("right") !== -1)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    function positionedX(itemWidth, margin) {
        const pos = clockPosition();
        if (pos.indexOf("left") !== -1)
            return margin;
        if (pos.indexOf("right") !== -1)
            return Math.max(margin, width - itemWidth - margin);
        return Math.max(margin, (width - itemWidth) / 2);
    }

    function positionedY(itemHeight, margin) {
        const pos = clockPosition();
        if (pos.indexOf("top") !== -1)
            return margin;
        if (pos.indexOf("bottom") !== -1)
            return Math.max(margin, height - itemHeight - margin);
        return Math.max(margin, (height - itemHeight) / 2);
    }

    PollText {
        id: shellConfigFile
        interval: 2000
        command: ["sh", "-c", "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/quickshell.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
    }

    PollText {
        id: monitorConfigFile
        interval: 2000
        command: ["sh", "-c", "name=" + root.shellQuote(root.screenName()) + "; [ -n \"$name\" ] || exit 0; cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/monitors/$name/quickshell.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
    }

    Connections {
        target: shellConfigFile

        function onValueChanged() {
            if (shellConfigFile.value.length === 0) {
                root.shellConfig = ({});
                return;
            }

            try {
                root.shellConfig = JSON.parse(shellConfigFile.value);
            } catch (error) {
                root.shellConfig = ({});
            }
        }
    }

    Connections {
        target: monitorConfigFile

        function onValueChanged() {
            if (monitorConfigFile.value.length === 0) {
                root.monitorConfig = ({});
                return;
            }

            try {
                root.monitorConfig = JSON.parse(monitorConfigFile.value);
            } catch (error) {
                root.monitorConfig = ({});
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        interval: 90
        running: root.visible && root.visualiserEnabled()
        repeat: true
        onTriggered: root.phase = (root.phase + 0.075) % 6.283
    }

    Item {
        anchors.fill: parent
        visible: root.visualiserEnabled()
        opacity: root.visualiserOpacity()

        Row {
            id: bars
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 42
            anchors.rightMargin: 42
            anchors.bottomMargin: 38
            height: root.visualiserHeight()
            spacing: 3

            Repeater {
                model: root.visualiserBarCount()

                Rectangle {
                    required property int index
                    property real wave: Math.abs(Math.sin(root.phase + index * 0.38))
                    property real wave2: Math.abs(Math.cos(root.phase * 0.73 + index * 0.19))

                    width: Math.max(3, (bars.width - (root.visualiserBarCount() - 1) * bars.spacing) / root.visualiserBarCount())
                    height: Math.max(8, bars.height * (0.18 + wave * 0.52 + wave2 * 0.22))
                    anchors.bottom: parent.bottom
                    radius: Math.min(width / 2, 6)
                    color: index % 3 === 0 ? Theme.accent : index % 3 === 1 ? Theme.accent2 : Theme.success

                    Behavior on height { NumberAnimation { duration: root.appearanceDuration(120); easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Rectangle {
        visible: root.desktopClockEnabled() && configBool("background.desktopClock.background.enabled", false)
        width: clockColumn.implicitWidth + 40
        height: clockColumn.implicitHeight + 30
        x: root.positionedX(width, 58)
        y: root.positionedY(height, 58)
        radius: root.appearanceRounding(18)
        color: Qt.rgba(0, 0, 0, configNumber("background.desktopClock.background.opacity", 0.22, 0, 0.8))
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
    }

    Column {
        id: clockColumn

        visible: root.desktopClockEnabled()
        spacing: 8
        scale: root.clockScale()
        transformOrigin: Item.Center
        x: root.positionedX(width * scale, 78)
        y: root.positionedY(height * scale, 78)

        Text {
            width: 360
            text: Qt.formatTime(clock.date, "HH:mm")
            color: configBool("background.desktopClock.invertColors", false) ? Theme.bg : Theme.fg
            opacity: 0.86
            font.pixelSize: root.desktopClockTimeFontSize()
            font.weight: Font.DemiBold
            horizontalAlignment: root.clockHorizontalAnchor()
        }

        Text {
            width: 360
            text: Qt.formatDate(clock.date, "yyyy.MM.dd ddd")
            color: configBool("background.desktopClock.invertColors", false) ? Theme.bgAlt : Theme.fgMuted
            opacity: 0.82
            font.pixelSize: root.desktopClockDateFontSize()
            font.weight: Font.Medium
            horizontalAlignment: root.clockHorizontalAnchor()
        }
    }
}
