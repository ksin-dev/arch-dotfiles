import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../Theme.js" as Theme

Item {
    id: root

    property bool centerOpen: false
    property bool dndEnabled: dndStatus.value === "true"
    property var history: []
    property var shellConfig: ({})

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

    function appearanceFontScale() {
        return configNumber("appearance.font.scale", 1, 0.5, 2.5) * monitorFontScale();
    }

    function monitorFontScale() {
        if (!configBool("appearance.font.scaleWithMonitor", true))
            return 1;

        const screens = Quickshell.screens.values || [];
        let ratio = 1;
        for (let i = 0; i < screens.length; i++) {
            const next = screens[i] && screens[i].devicePixelRatio !== undefined ? Number(screens[i].devicePixelRatio) : 1;
            if (Number.isFinite(next))
                ratio = Math.max(ratio, next);
        }

        if (ratio <= 1)
            return 1;

        const weight = configNumber("appearance.font.monitorScaleWeight", 1, 0, 1);
        return 1 + (Math.min(2, ratio) - 1) * weight;
    }

    function fontTokenSize(path, fallbackValue, minValue, maxValue, localScale) {
        const base = configNumber(path, fallbackValue, minValue, maxValue);
        const scale = Number.isFinite(Number(localScale)) ? Number(localScale) : 1;
        return Math.max(minValue || 7, Math.round(base * scale * appearanceFontScale()));
    }

    function notificationFontScale() {
        return configNumber("notifs.font.scale", 1, 0.5, 2.5);
    }

    function notificationTitleFontSize() {
        return fontTokenSize("notifs.font.titleSize", 14, 7, 40, notificationFontScale());
    }

    function notificationLabelFontSize() {
        return fontTokenSize("notifs.font.labelSize", 12, 7, 36, notificationFontScale());
    }

    function notificationBodyFontSize() {
        return fontTokenSize("notifs.font.bodySize", 11, 6, 32, notificationFontScale());
    }

    function notificationMetaFontSize() {
        return fontTokenSize("notifs.font.metaSize", 10, 6, 28, notificationFontScale());
    }

    function notificationIconFontSize() {
        return fontTokenSize("notifs.font.iconSize", 16, 7, 44, notificationFontScale());
    }

    function appearanceAnimationsEnabled() {
        return configBool("appearance.anim.enabled", true);
    }

    function appearanceDuration(baseMs) {
        if (!appearanceAnimationsEnabled())
            return 0;

        return Math.round(baseMs * configNumber("appearance.anim.durationScale", 1, 0.15, 3));
    }

    function appearanceRounding(baseRadius) {
        return Math.max(0, Math.round(baseRadius * configNumber("appearance.rounding", 1, 0, 2)));
    }

    function appearanceTransparencyEnabled() {
        return configBool("appearance.transparency.enabled", false);
    }

    function appearanceOpacity(path, fallbackValue) {
        if (!appearanceTransparencyEnabled())
            return fallbackValue;

        return configNumber(path, fallbackValue, 0.15, 1);
    }

    function panelOpacity() {
        return appearanceOpacity("appearance.transparency.panelOpacity", 1);
    }

    function sidebarEnabled() {
        return configBool("sidebar.enabled", true);
    }

    function sidebarWidth() {
        return Math.round(configNumber("sidebar.width", 390, 320, 560));
    }

    function sidebarHeight(screenHeight) {
        return Math.round(Math.min(screenHeight - 88, configNumber("sidebar.height", 560, 360, 900)));
    }

    function sidebarTopMargin() {
        return Math.round(configNumber("sidebar.topMargin", 52, 0, 180));
    }

    function sidebarRightMargin() {
        return Math.round(configNumber("sidebar.rightMargin", 12, 0, 80));
    }

    function sidebarShowOnHover() {
        return configBool("sidebar.showOnHover", false);
    }

    function sidebarHoverWidth() {
        return Math.round(configNumber("sidebar.minHoverThreshold", 12, 4, 240));
    }

    function notifsEnabled() {
        return configBool("notifs.enabled", true);
    }

    function notifsExpireEnabled() {
        return configBool("notifs.expire", true);
    }

    function fullscreenPolicy(path, fallbackValue) {
        const value = `${configValue(path, fallbackValue)}`.toLowerCase();
        if (value === "on" || value === "always" || value === "true")
            return "on";
        if (value === "critical")
            return "critical";
        return "off";
    }

    function fullscreenNotificationsEnabled(notification) {
        const policy = fullscreenPolicy("notifs.fullscreen", "on");
        if (policy === "on")
            return true;
        if (policy === "critical")
            return notification && notification.urgency === NotificationUrgency.Critical;
        return false;
    }

    function toastsEnabled() {
        return configBool("utilities.enabled", true) && configBool("utilities.toasts.enabled", true);
    }

    function fullscreenToastsEnabled(notification) {
        const policy = fullscreenPolicy("utilities.toasts.fullscreen", "off");
        if (policy === "on")
            return true;
        if (policy === "critical")
            return notification && notification.urgency === NotificationUrgency.Critical;
        return false;
    }

    function maxToasts() {
        return Math.round(configNumber("utilities.maxToasts", 4, 1, 8));
    }

    function toastTimeout(notification) {
        if (!notifsExpireEnabled() || notification.resident)
            return 0;

        const fallback = notification.urgency === NotificationUrgency.Critical ? 9000 : configNumber("notifs.defaultExpireTimeout", 5000, 1000, 60000);
        const fullscreenFallback = configNumber("notifs.fullscreenExpireTimeout", 2000, 500, 60000);
        const value = activeFullscreen.value === "true" ? fullscreenFallback : Math.round(notification.expireTimeout || 0);
        if (value <= 0)
            return Math.round(fallback);
        return Math.max(500, Math.min(value, 60000));
    }

    function toastVisible(notification, index) {
        if (!notifsEnabled() || !toastsEnabled() || root.dndEnabled || index >= maxToasts())
            return false;
        if (activeFullscreen.value === "true")
            return fullscreenNotificationsEnabled(notification) && fullscreenToastsEnabled(notification);
        return true;
    }

    function invokeDefaultAction(notification) {
        if (!configBool("notifs.actionOnClick", false))
            return false;
        if (!notification.actions || notification.actions.length === 0)
            return false;

        notification.actions[0].invoke();
        notification.dismiss();
        return true;
    }

    function writeHistoryCount() {
        countWriter.exec(["sh", "-c", `state="\${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"; mkdir -p "$state"; printf '${history.length}' > "$state/quickshell-notification-count"`]);
    }

    Component.onCompleted: writeHistoryCount()

    function cleanText(value) {
        return `${value || ""}`.replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
    }

    function iconSource(notification) {
        const icon = notification.appIcon || notification.desktopEntry || "";
        if (notification.image && notification.image.length > 0)
            return notification.image.startsWith("/") ? "file://" + notification.image : notification.image;
        if (icon.length > 0 && icon[0] === "/")
            return "file://" + icon;
        if (icon.length > 0 && Quickshell.hasThemeIcon(icon))
            return Quickshell.iconPath(icon);
        return "";
    }

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: function(notification) {
            notification.tracked = root.notifsEnabled() && !root.dndEnabled;
            const entry = {
                summary: root.cleanText(notification.summary || notification.appName || "Notification"),
                body: root.cleanText(notification.body || ""),
                appName: root.cleanText(notification.appName || ""),
                time: Qt.formatTime(new Date(), "HH:mm"),
                urgency: notification.urgency,
                icon: root.iconSource(notification)
            };
            root.history = [entry].concat(root.history).slice(0, 50);
            root.writeHistoryCount();
        }
    }

    Process {
        id: countWriter
    }

    PollText {
        id: dndStatus
        interval: 1000
        command: ["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-dnd.enabled\"; [ \"$(cat \"$state\" 2>/dev/null)\" = true ] && printf true || printf false"]
    }

    PollText {
        id: activeFullscreen
        interval: 1000
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | jq -r 'if (.fullscreen // 0) == 0 then false else true end' 2>/dev/null || printf false"]
    }

    PollText {
        id: shellConfigFile
        interval: 2000
        command: ["sh", "-c", "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/quickshell.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
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

    IpcHandler {
        target: "notifications"

        function open(): void {
            root.centerOpen = true;
        }

        function close(): void {
            root.centerOpen = false;
        }

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }

        function clear(): void {
            root.history = [];
            root.writeHistoryCount();
        }

        function dnd(): bool {
            return root.dndEnabled;
        }
    }

    IpcHandler {
        target: "notifs"

        function open(): void {
            root.centerOpen = true;
        }

        function close(): void {
            root.centerOpen = false;
        }

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }

        function clear(): void {
            root.history = [];
            root.writeHistoryCount();
        }

        function dnd(): bool {
            return root.dndEnabled;
        }
    }

    IpcHandler {
        target: "sidebar"

        function open(): void {
            root.centerOpen = true;
        }

        function close(): void {
            root.centerOpen = false;
        }

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: hoverReveal

            required property var modelData

            screen: modelData
            visible: root.sidebarEnabled() && root.sidebarShowOnHover() && !root.centerOpen
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: root.sidebarHoverWidth()

            anchors {
                top: true
                bottom: true
                right: true
            }

            HoverHandler {
                onHoveredChanged: if (hovered) root.centerOpen = true
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: centerWindow

            required property var modelData

            screen: modelData
            visible: root.sidebarEnabled() && root.centerOpen
            color: "transparent"
            focusable: true
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                right: true
            }

            margins {
                top: root.sidebarTopMargin()
                right: root.sidebarRightMargin()
            }

            implicitWidth: root.sidebarWidth()
            implicitHeight: root.sidebarHeight(modelData.height)

            MouseArea {
                anchors.fill: parent
                onClicked: root.centerOpen = false
            }

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.fill: parent
                radius: root.appearanceRounding(16)
                color: Theme.bg
                border.color: Theme.border
                border.width: 1
                opacity: centerWindow.visible ? root.panelOpacity() : 0
                scale: centerWindow.visible ? 1 : 0.965
                transformOrigin: Item.TopRight

                Behavior on opacity { NumberAnimation { duration: root.appearanceDuration(220); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: root.appearanceDuration(260); easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse.accepted = true
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.right: clearButton.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Notifications"
                            color: Theme.fg
                            font.pixelSize: root.notificationTitleFontSize()
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: clearButton

                            visible: root.history.length > 0
                            width: 30
                            height: 30
                            anchors.right: closeButton.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 9
                            color: clearMouse.containsMouse ? Qt.rgba(1, 0.42, 0.42, 0.14) : "transparent"
                            border.color: clearMouse.containsMouse ? Theme.danger : "transparent"
                            border.width: 1

                            IconImage {
                                id: clearIcon

                                anchors.centerIn: parent
                                implicitSize: 15
                                source: Quickshell.hasThemeIcon("user-trash-symbolic") ? Quickshell.iconPath("user-trash-symbolic") : ""
                                opacity: 0
                            }

                            ColorOverlay {
                                visible: clearIcon.source.toString().length > 0
                                anchors.fill: clearIcon
                                source: clearIcon
                                color: Theme.danger
                            }

                            Text {
                                visible: clearIcon.source.toString().length === 0
                                anchors.centerIn: parent
                                text: "D"
                                color: Theme.danger
                                font.pixelSize: root.notificationBodyFontSize()
                                font.bold: true
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.history = [];
                                    root.writeHistoryCount();
                                }
                            }
                        }

                        Rectangle {
                            id: closeButton

                            width: 30
                            height: 30
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 9
                            color: closeCenterMouse.containsMouse ? Theme.surfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Theme.fgMuted
                                font.pixelSize: root.notificationTitleFontSize()
                                font.bold: true
                            }

                            MouseArea {
                                id: closeCenterMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.centerOpen = false
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    Text {
                        visible: root.history.length === 0
                        width: parent.width
                        height: 420
                        text: "No notifications"
                        color: Theme.fgMuted
                        font.pixelSize: root.notificationBodyFontSize()
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Flickable {
                        visible: root.history.length > 0
                        width: parent.width
                        height: parent.height - 62
                        clip: true
                        contentHeight: historyColumn.implicitHeight

                        Column {
                            id: historyColumn
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.history

                                Rectangle {
                                    required property var modelData

                                    width: historyColumn.width
                                    height: notificationBody.implicitHeight + 26
                                    radius: 12
                                    color: Theme.surface
                                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.border
                                    border.width: 1

                                    Row {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 10
                                        spacing: 10

                                        Rectangle {
                                            width: 34
                                            height: 34
                                            radius: 10
                                            color: Theme.bg
                                            border.color: Theme.border
                                            border.width: 1
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 3
                                                fillMode: Image.PreserveAspectCrop
                                                source: modelData.icon
                                                visible: source.toString().length > 0
                                            }

                                            Text {
                                                visible: modelData.icon.length === 0
                                                anchors.centerIn: parent
                                                text: "!"
                                                color: modelData.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.accent
                                                font.pixelSize: root.notificationIconFontSize()
                                                font.bold: true
                                            }
                                        }

                                        Column {
                                            id: notificationBody
                                            width: parent.width - 44
                                            spacing: 5

                                            Row {
                                                width: parent.width
                                                spacing: 8

                                                Text {
                                                    width: parent.width - 48
                                                    text: modelData.summary
                                                    color: Theme.fg
                                                    font.pixelSize: root.notificationLabelFontSize()
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: 40
                                                    text: modelData.time
                                                    color: Theme.fgMuted
                                                    font.pixelSize: root.notificationMetaFontSize()
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.body
                                                visible: text.length > 0
                                                color: Theme.fgMuted
                                                font.pixelSize: root.notificationBodyFontSize()
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
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
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData

            screen: modelData
            visible: root.notifsEnabled() && root.toastsEnabled() && server.trackedNotifications.values.length > 0
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                right: true
            }

            margins {
                top: 48
                right: 12
            }

            implicitWidth: 360
            implicitHeight: Math.min(640, stack.implicitHeight)

            Column {
                id: stack

                width: 360
                spacing: 10

                Repeater {
                    model: server.trackedNotifications

                    Rectangle {
                        id: toast

                        required property var modelData
                        required property int index
                        property int timeout: root.toastTimeout(modelData)

                        width: stack.width
                        height: content.implicitHeight + 24
                        visible: root.toastVisible(modelData, index)
                        radius: root.appearanceRounding(14)
                        color: Theme.bg
                        border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.border
                        border.width: 1
                        opacity: root.panelOpacity()

                        Timer {
                            interval: toast.timeout
                            running: toast.timeout > 0
                            repeat: false
                            onTriggered: toast.modelData.expire()
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: root.invokeDefaultAction(toast.modelData)
                        }

                        Row {
                            id: content

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                width: 42
                                height: 42
                                radius: 11
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    fillMode: Image.PreserveAspectCrop
                                    source: root.iconSource(toast.modelData)
                                    visible: source.toString().length > 0
                                }

                                Text {
                                    visible: root.iconSource(toast.modelData).length === 0
                                    anchors.centerIn: parent
                                    text: "!"
                                    color: toast.modelData.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.accent
                                    font.pixelSize: root.notificationIconFontSize()
                                    font.bold: true
                                }
                            }

                            Column {
                                width: parent.width - 66
                                spacing: 7

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        width: parent.width - 34
                                        text: root.cleanText(toast.modelData.summary || toast.modelData.appName || "Notification")
                                        color: Theme.fg
                                        font.pixelSize: root.notificationLabelFontSize()
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 22
                                        radius: 7
                                        color: closeMouse.containsMouse ? Theme.surfaceHover : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: Theme.fgMuted
                                            font.pixelSize: root.notificationTitleFontSize()
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: toast.modelData.dismiss()
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: root.cleanText(toast.modelData.body)
                                    visible: text.length > 0
                                    color: Theme.fgMuted
                                    font.pixelSize: root.notificationBodyFontSize()
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                Row {
                                    id: actionsRow

                                    property var notification: toast.modelData

                                    visible: toast.modelData.actions.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: toast.modelData.actions

                                        Rectangle {
                                            required property var modelData

                                            height: 26
                                            width: Math.min(150, actionLabel.implicitWidth + 18)
                                            radius: 8
                                            color: actionMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                            border.color: Theme.border
                                            border.width: 1

                                            Text {
                                                id: actionLabel
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                color: Theme.fg
                                                font.pixelSize: root.notificationMetaFontSize()
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: actionMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    modelData.invoke();
                                                    actionsRow.notification.dismiss();
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
        }
    }
}
