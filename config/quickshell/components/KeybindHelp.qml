import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../Theme.js" as Theme
import "../services/KeybindParser.js" as KeybindParser

PanelWindow {
    id: root

    required property var modelData
    property bool open: false
    property var hyprMonitor: Hyprland.monitorFor(modelData)
    property bool onFocusedMonitor: Hyprland.focusedMonitor === null || hyprMonitor === null || Hyprland.focusedMonitor.name === hyprMonitor.name
    property string query: ""
    property string activeSource: "Hyprland"
    property var items: []
    property var shellConfig: ({})
    readonly property var sources: ["Hyprland", "Yazi"]
    signal openRequested
    signal closeRequested

    screen: modelData
    visible: open && onFocusedMonitor
    color: "transparent"
    focusable: true
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: modelData.width
    implicitHeight: modelData.height

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function reload() {
        loader.exec(["sh", "-c", "printf '__HYPR__\\n'; cat \"$HOME/.config/hypr/keybinds.lua\" 2>/dev/null; printf '\\n__YAZI__\\n'; cat \"$HOME/.config/yazi/keymap.toml\" 2>/dev/null"]);
    }

    function show() {
        query = "";
        activeSource = "Hyprland";
        reload();
        openRequested();
    }

    function close() {
        query = "";
        closeRequested();
    }

    function toggle() {
        if (open)
            close();
        else
            show();
    }

    function setContent(text) {
        const split = text.split("\n__YAZI__\n");
        const hyprText = split[0].replace(/^__HYPR__\n/, "");
        const yaziText = split.length > 1 ? split[1] : "";
        items = KeybindParser.parseHyprland(hyprText).concat(KeybindParser.parseYazi(yaziText));
    }

    function visibleGroups() {
        return KeybindParser.groups(items, activeSource, query);
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

    function helpFontScale() {
        return configNumber("keybindHelp.font.scale", 1, 0.5, 2.5);
    }

    function helpTitleFontSize() {
        return fontTokenSize("keybindHelp.font.titleSize", 18, 11, 48, helpFontScale());
    }

    function helpLabelFontSize() {
        return fontTokenSize("keybindHelp.font.labelSize", 14, 9, 38, helpFontScale());
    }

    function helpSectionTitleFontSize() {
        return fontTokenSize("keybindHelp.font.sectionTitleSize", 16, 10, 44, helpFontScale());
    }

    function helpBodyFontSize() {
        return fontTokenSize("keybindHelp.font.bodySize", 13, 9, 36, helpFontScale());
    }

    function helpMetaFontSize() {
        return fontTokenSize("keybindHelp.font.metaSize", 11, 8, 32, helpFontScale());
    }

    Process {
        id: loader

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.setContent(text)
        }
    }

    onOpenChanged: {
        if (open) {
            query = "";
            activeSource = "Hyprland";
            reload();
        } else {
            query = "";
        }
    }

    onVisibleChanged: {
        if (visible)
            search.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        width: Math.min(900, parent.width - 48)
        height: Math.min(660, parent.height - 96)
        anchors.centerIn: parent
        radius: 16
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Row {
                width: parent.width
                spacing: 12

                Column {
                    width: parent.width - 70
                    spacing: 3

                    Text {
                        text: "Keyboard Shortcuts"
                        color: Theme.fg
                        font.pixelSize: root.helpTitleFontSize()
                        font.bold: true
                    }

                    Text {
                        text: "Search Hyprland and Yazi shortcuts"
                        color: Theme.fgMuted
                        font.pixelSize: root.helpBodyFontSize()
                    }
                }

                Rectangle {
                    width: 48
                    height: 30
                    radius: 8
                    color: closeMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Esc"
                        color: Theme.fg
                        font.pixelSize: root.helpBodyFontSize()
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }

            Rectangle {
                height: 42
                width: parent.width
                radius: 10
                color: Theme.surface
                border.color: search.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search shortcuts"
                    color: Theme.fgMuted
                    font.pixelSize: root.helpLabelFontSize()
                    visible: search.text.length === 0
                }

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.query
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.pixelSize: root.helpLabelFontSize()
                    clip: true

                    onTextEdited: root.query = text

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: parent.height - 104
                spacing: 12

                Column {
                    width: 150
                    spacing: 6

                    Repeater {
                        model: root.sources

                        Rectangle {
                            required property string modelData
                            property bool selected: root.activeSource === modelData

                            width: parent.width
                            height: 34
                            radius: 9
                            color: selected ? Theme.accent : sourceMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                            border.color: selected ? Theme.accent : Theme.border
                            border.width: 1

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                color: parent.selected ? Theme.accentFg : Theme.fg
                                font.pixelSize: root.helpLabelFontSize()
                                font.bold: parent.selected
                            }

                            MouseArea {
                                id: sourceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.activeSource = modelData
                            }
                        }
                    }
                }

                ListView {
                    id: groups
                    width: parent.width - 162
                    height: parent.height
                    clip: true
                    spacing: 12
                    model: root.visibleGroups()

                    delegate: Rectangle {
                        required property string modelData
                        property var sectionItems: KeybindParser.groupItems(root.items, root.activeSource, modelData, root.query)
                        property bool modeSection: modelData.startsWith("Mode: ")

                        width: groups.width
                        height: sectionColumn.implicitHeight + 2
                        radius: 12
                        color: Theme.surface
                        border.color: modeSection ? Theme.accent : Theme.border
                        border.width: modeSection ? 2 : 1

                        Column {
                            id: sectionColumn
                            width: parent.width
                            spacing: 0

                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: 12
                                color: Theme.surfaceHover
                                border.color: Theme.border
                                border.width: 0

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: KeybindParser.groupTitle(modelData)
                                        color: modeSection ? Theme.accent : Theme.fg
                                        font.pixelSize: root.helpSectionTitleFontSize()
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sectionItems.length + " shortcuts"
                                        color: Theme.fgMuted
                                        font.pixelSize: root.helpMetaFontSize()
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: modeSection ? Theme.accent : Theme.border
                                    opacity: modeSection ? 0.9 : 1
                                }
                            }

                            Repeater {
                                model: sectionItems

                                Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: sectionColumn.width
                                    height: 40
                                    color: rowMouse.containsMouse ? Theme.surfaceHover : "transparent"

                                    Rectangle {
                                        visible: index > 0
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        height: 1
                                        color: Theme.border
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 10

                                        Text {
                                            width: 230
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.key
                                            color: Theme.fg
                                            font.pixelSize: root.helpBodyFontSize()
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: 112
                                            height: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 8
                                            color: modelData.group.startsWith("Mode: ") ? Theme.surfaceHover : Theme.surface
                                            border.color: modelData.group.startsWith("Mode: ") ? Theme.accent : Theme.border
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                width: parent.width - 10
                                                text: modelData.kind || "normal"
                                                color: modelData.group.startsWith("Mode: ") ? Theme.accent : Theme.fgMuted
                                                font.pixelSize: root.helpMetaFontSize()
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            width: parent.width - 366
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.action
                                            color: Theme.fg
                                            font.pixelSize: root.helpBodyFontSize()
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
