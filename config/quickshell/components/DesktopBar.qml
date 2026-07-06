import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import "../Theme.js" as Theme
import "../services/ShellCommands.js" as ShellCommands

Item {
    id: bar

    required property var modelData
    property string drawerRequest: ""
    property int drawerNonce: 0
    property string openDropdown: ""
    property int calendarMonthOffset: 0
    property bool calendarPickerOpen: false
    property string selectedCalendarKey: dateKey(new Date())
    property string selectedPlayerKey: ""
    property var player: selectedPlayerKey.length > 0 ? playerByKey(selectedPlayerKey) || chooseMediaPlayer(mediaPlayers()) : chooseMediaPlayer(mediaPlayers())
    property var sink: Pipewire.defaultAudioSink
    property real volumeOverride: -1
    property int muteOverride: -1
    property int sourceMuteOverride: -1
    property real brightnessOverride: -1
    property bool osdVisible: false
    property string osdKind: "volume"
    property real osdValue: 0
    property real osdMax: 1
    property bool osdMuted: false
    property bool topBarHover: false
    property bool revealHover: false
    property var activeTrayItem: null
    property var activeTraySubmenu: null
    property var pendingNativeTrayTarget: null
    property real pendingNativeTrayX: 10
    property var trayMenuParents: []
    property var trayMenuTitles: []
    property real trayDropdownX: 10
    property real workspaceWheelAccum: 0
    property real workspaceWheelLastAt: 0
    property int clipboardRefreshNonce: 0
    property int profileImageRefreshNonce: 0
    property int idleSettingsRefreshNonce: 0
    property int idleInhibitRefreshNonce: 0
    property var colorSchemes: [
        { name: "default", family: "default", label: "Default", familyLabel: "Default", mode: "dark", variant: "dark", accent: "#3b82f6", accent2: "#88c0d0", bg: "#101216" },
        { name: "default-light", family: "default", label: "Default Light", familyLabel: "Default", mode: "light", variant: "light", accent: "#2563eb", accent2: "#0891b2", bg: "#f8fafc" },
        { name: "graphite", family: "graphite", label: "Graphite", familyLabel: "Graphite", mode: "dark", variant: "dark", accent: "#22c55e", accent2: "#38bdf8", bg: "#0d1117" },
        { name: "catppuccin-mocha", family: "catppuccin", label: "Catppuccin Mocha", familyLabel: "Catppuccin", mode: "dark", variant: "mocha", accent: "#89b4fa", accent2: "#cba6f7", bg: "#1e1e2e" },
        { name: "catppuccin-latte", family: "catppuccin", label: "Catppuccin Latte", familyLabel: "Catppuccin", mode: "light", variant: "latte", accent: "#1e66f5", accent2: "#8839ef", bg: "#eff1f5" },
        { name: "rose-pine", family: "rose-pine", label: "Rose Pine", familyLabel: "Rose Pine", mode: "dark", variant: "main", accent: "#c4a7e7", accent2: "#9ccfd8", bg: "#191724" },
        { name: "rose-pine-dawn", family: "rose-pine", label: "Rose Pine Dawn", familyLabel: "Rose Pine", mode: "light", variant: "dawn", accent: "#907aa9", accent2: "#56949f", bg: "#faf4ed" },
        { name: "nord", family: "nord", label: "Nord", familyLabel: "Nord", mode: "dark", variant: "dark", accent: "#88c0d0", accent2: "#81a1c1", bg: "#2e3440" },
        { name: "dracula", family: "dracula", label: "Dracula", familyLabel: "Dracula", mode: "dark", variant: "dark", accent: "#bd93f9", accent2: "#8be9fd", bg: "#282a36" },
        { name: "solarized-dark", family: "solarized", label: "Solarized Dark", familyLabel: "Solarized", mode: "dark", variant: "dark", accent: "#268bd2", accent2: "#2aa198", bg: "#002b36" },
        { name: "solarized-light", family: "solarized", label: "Solarized Light", familyLabel: "Solarized", mode: "light", variant: "light", accent: "#268bd2", accent2: "#2aa198", bg: "#fdf6e3" },
        { name: "tokyonight", family: "tokyonight", label: "Tokyo Night", familyLabel: "Tokyo Night", mode: "dark", variant: "dark", accent: "#7aa2f7", accent2: "#bb9af7", bg: "#1a1b26" }
    ]

    function toggleDropdown(name) {
        openDropdown = openDropdown === name ? "" : name;
        if (openDropdown !== "calendar")
            calendarPickerOpen = false;
    }

    function drawerKnown(name) {
        const drawers = ["dashboard", "media", "calendar", "system", "audio", "network", "nexus", "bluetooth", "keyboard", "brightness", "activewindow", "power", "idlesettings", "theme", "quick", "clipboard", "profileimage", "updates"];
        return drawers.indexOf(name) !== -1;
    }

    function handleDrawerRequest() {
        const name = `${drawerRequest || ""}`.toLowerCase();
        if (name.length === 0 || !drawerKnown(name))
            return;
        if (!screenBarEnabled() || !focusedMonitor())
            return;
        toggleDropdown(name);
    }

    onDrawerNonceChanged: handleDrawerRequest()

    function closeDropdown() {
        if (openDropdown === "tray" && activeTraySubmenu && activeTraySubmenu.sendClosed)
            activeTraySubmenu.sendClosed();
        if (openDropdown === "tray" && trayMenuModel.menu && trayMenuModel.menu.sendClosed)
            trayMenuModel.menu.sendClosed();

        openDropdown = "";
        calendarPickerOpen = false;
        activeTrayItem = null;
        activeTraySubmenu = null;
        trayMenuParents = [];
        trayMenuTitles = [];
        traySubmenuModel.menu = null;
    }

    function parseConfigText(value) {
        if (value.length === 0)
            return ({});

        try {
            return JSON.parse(value);
        } catch (error) {
            return ({});
        }
    }

    function shellConfigObject() {
        return parseConfigText(shellConfig.value);
    }

    function monitorFileConfigObject() {
        return parseConfigText(monitorConfig.value);
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

    function monitorInlineConfigObject(globalConfig) {
        const name = screenName();
        if (name.length === 0 || !globalConfig || typeof globalConfig !== "object")
            return ({});

        const monitors = globalConfig.monitors || {};
        if (!monitors || typeof monitors !== "object" || !(name in monitors))
            return ({});

        return monitors[name] || {};
    }

    function configValue(path, fallbackValue) {
        const globalConfig = shellConfigObject();
        const sources = [monitorFileConfigObject(), monitorInlineConfigObject(globalConfig), globalConfig];

        for (let i = 0; i < sources.length; i++) {
            const result = lookupConfigValue(sources[i], path);
            if (result.found)
                return result.value;
        }

        return fallbackValue;
    }

    function globalConfigValue(path, fallbackValue) {
        const result = lookupConfigValue(shellConfigObject(), path);
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
        return Math.max(0, Math.round(baseRadius * globalConfigNumber("appearance.rounding", 1, 0, 2) * appearanceDeformScale()));
    }

    function appearanceScale(path, fallbackValue) {
        const value = globalConfigValue(path, null);
        if (typeof value === "number" || typeof value === "string")
            return globalConfigNumber(path, fallbackValue, 0, 2.5);

        const nested = globalConfigValue(path + ".scale", fallbackValue);
        const raw = Number(nested);
        return Number.isFinite(raw) ? Math.max(0, Math.min(2.5, raw)) : fallbackValue;
    }

    function appearanceDeformScale() {
        return globalConfigNumber("appearance.deformScale", 1, 0.35, 2);
    }

    function appearanceSpacing(baseSpacing) {
        return Math.max(0, Math.round(baseSpacing * appearanceScale("appearance.spacing", 1)));
    }

    function appearancePadding(basePadding) {
        return Math.max(0, Math.round(basePadding * appearanceScale("appearance.padding", 1)));
    }

    function appearanceTransparencyEnabled() {
        return globalConfigBool("appearance.transparency.enabled", false);
    }

    function appearanceOpacity(path, fallbackValue) {
        if (!appearanceTransparencyEnabled())
            return fallbackValue;

        return globalConfigNumber(path, fallbackValue, 0.15, 1);
    }

    function barOpacity() {
        return appearanceOpacity("appearance.transparency.barOpacity", 0.96);
    }

    function panelOpacity() {
        return appearanceOpacity("appearance.transparency.panelOpacity", 1);
    }

    function osdOpacity() {
        return appearanceOpacity("appearance.transparency.osdOpacity", 0.98);
    }

    function appearanceFontScale() {
        return appearanceScale("appearance.font", 1) * monitorFontScale();
    }

    function monitorFontScale() {
        if (!globalConfigBool("appearance.font.scaleWithMonitor", true))
            return 1;

        const ratio = modelData && modelData.devicePixelRatio !== undefined ? Number(modelData.devicePixelRatio) : 1;
        if (!Number.isFinite(ratio) || ratio <= 1)
            return 1;

        const weight = globalConfigNumber("appearance.font.monitorScaleWeight", 1, 0, 1);
        return 1 + (Math.min(2, ratio) - 1) * weight;
    }

    function appearanceFontValue(role) {
        return globalConfigValue("appearance.font." + role, "");
    }

    function appearanceFontFamily(role, fallbackValue) {
        const value = appearanceFontValue(role);
        if (typeof value === "string" && value.length > 0)
            return value;
        if (value && typeof value === "object" && value.family !== undefined && `${value.family}`.length > 0)
            return `${value.family}`;
        return fallbackValue || "";
    }

    function appearanceFontSize(role, size, fallbackValue) {
        const configured = globalConfigValue("appearance.font." + role + "." + size + ".size", null);
        const base = Number(configured);
        const value = Number.isFinite(base) ? base : fallbackValue;
        return Math.max(7, Math.round(value * appearanceFontScale()));
    }

    function fontTokenSize(path, fallbackValue, minValue, maxValue, localScale) {
        const base = configNumber(path, fallbackValue, minValue, maxValue);
        const scale = Number.isFinite(Number(localScale)) ? Number(localScale) : 1;
        return Math.max(minValue || 7, Math.round(base * scale * appearanceFontScale()));
    }

    function clockFontFamily() {
        return appearanceFontFamily("clock", appearanceFontFamily("label", ""));
    }

    function workspaceFontFamily() {
        return appearanceFontFamily("workspaces", appearanceFontFamily("label", ""));
    }

    function labelFontSize(size, fallbackValue) {
        return appearanceFontSize("label", size, fallbackValue);
    }

    function bodyFontSize(size, fallbackValue) {
        return appearanceFontSize("body", size, fallbackValue);
    }

    function titleFontSize(size, fallbackValue) {
        return appearanceFontSize("title", size, fallbackValue);
    }

    function barHeight() {
        return Math.round(configNumber("bar.height", 40, 34, 56));
    }

    function barFontScale() {
        return configNumber("bar.font.scale", 1, 0.5, 2.5);
    }

    function barLabelFontSize() {
        return fontTokenSize("bar.font.labelSize", 8, 6, 36, barFontScale());
    }

    function barBodyFontSize() {
        return fontTokenSize("bar.font.bodySize", 8, 6, 36, barFontScale());
    }

    function barClockFontSize() {
        return fontTokenSize("bar.font.clockSize", 9, 6, 40, barFontScale());
    }

    function barBadgeFontSize() {
        return fontTokenSize("bar.font.badgeSize", 6, 5, 24, barFontScale());
    }

    function barWorkspaceIconFontSize() {
        return fontTokenSize("bar.font.workspaceIconSize", 6, 5, 24, barFontScale());
    }

    function calendarFontScale() {
        return configNumber("calendar.font.scale", 1, 0.5, 2.5);
    }

    function calendarLabelFontSize() {
        return fontTokenSize("calendar.font.labelSize", 8, 6, 36, calendarFontScale());
    }

    function calendarTitleFontSize() {
        return fontTokenSize("calendar.font.titleSize", 9, 6, 40, calendarFontScale());
    }

    function calendarDayFontSize() {
        return fontTokenSize("calendar.font.daySize", 9, 6, 40, calendarFontScale());
    }

    function calendarDetailFontSize() {
        return fontTokenSize("calendar.font.detailSize", 7, 6, 36, calendarFontScale());
    }

    function panelFontScale() {
        return configNumber("panel.font.scale", 1, 0.5, 2.5);
    }

    function panelTitleFontSize() {
        return fontTokenSize("panel.font.titleSize", 9, 6, 44, panelFontScale());
    }

    function panelLabelFontSize() {
        return fontTokenSize("panel.font.labelSize", 7, 6, 36, panelFontScale());
    }

    function panelBodyFontSize() {
        return fontTokenSize("panel.font.bodySize", 7, 6, 36, panelFontScale());
    }

    function panelMetaFontSize() {
        return fontTokenSize("panel.font.metaSize", 6, 5, 32, panelFontScale());
    }

    function panelHeroFontSize() {
        return fontTokenSize("panel.font.heroSize", 11, 8, 64, panelFontScale());
    }

    function panelIconFontSize() {
        return fontTokenSize("panel.font.iconSize", 17, 8, 80, panelFontScale());
    }

    function configString(path, fallbackValue) {
        const value = configValue(path, fallbackValue);
        if (value === null || value === undefined)
            return fallbackValue;
        return `${value}`;
    }

    function barEntryEnabled(id) {
        const entries = configValue("bar.entries", []);
        if (Array.isArray(entries) && entries.length > 0) {
            for (let i = 0; i < entries.length; i++) {
                const entry = entries[i] || {};
                if (`${entry.id || ""}` === id)
                    return entry.enabled !== false;
            }

            return false;
        }

        return configBool("bar." + id + ".enabled", true);
    }

    function barEntries() {
        const entries = configValue("bar.entries", []);
        return Array.isArray(entries) && entries.length > 0 ? entries : [];
    }

    function barEntrySection(id, fallbackSection) {
        const entries = barEntries();
        if (entries.length === 0)
            return fallbackSection;

        let section = 0;
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i] || {};
            const entryId = `${entry.id || ""}`;
            if (entryId === "spacer") {
                if (entry.enabled !== false)
                    section = Math.min(2, section + 1);
                continue;
            }
            if (entryId === id)
                return Math.min(2, section);
        }

        return fallbackSection;
    }

    function barEntryInSection(id, section, fallbackSection) {
        return barEntryEnabled(id) && barEntrySection(id, fallbackSection) === section;
    }

    function statusEnabled(id) {
        const status = configValue("bar.status", ({}));
        if (status && typeof status === "object" && id in status)
            return configBool("bar.status." + id, true);

        const aliases = {
            audio: "showAudio",
            microphone: "showMicrophone",
            keyboard: "showKbLayout",
            network: "showNetwork",
            wifi: "showWifi",
            bluetooth: "showBluetooth",
            battery: "showBattery",
            lockStatus: "showLockStatus"
        };
        const alias = aliases[id] || "";
        if (alias.length > 0 && status && typeof status === "object" && alias in status)
            return configBool("bar.status." + alias, true);

        return true;
    }

    function visibleStatusItemCount() {
        let count = 0;
        if (statusEnabled("audio"))
            count++;
        if (statusEnabled("microphone"))
            count++;
        if (statusEnabled("privacy") && privacyActive())
            count++;
        if (statusEnabled("keyboard"))
            count++;
        if (statusEnabled("lockStatus") && capsLockOn())
            count++;
        if (statusEnabled("lockStatus") && numLockOn())
            count++;
        if (networkStatusVisible())
            count++;
        if (statusEnabled("weather") && weatherAvailable())
            count++;
        if (statusEnabled("bluetooth") && bluetoothAvailable())
            count++;
        if (statusEnabled("brightness") && backlight.value.length > 0)
            count++;
        if (statusEnabled("idleInhibit") && idleInhibitEnabled())
            count++;
        if (statusEnabled("updates") && updateCount() > 0)
            count++;
        if (statusEnabled("temperature") && temperatureHot())
            count++;
        return count;
    }

    function quickToggleEnabled(id) {
        const toggles = configValue("utilities.quickToggles", ({}));
        if (Array.isArray(toggles)) {
            for (let i = 0; i < toggles.length; i++) {
                const entry = toggles[i] || {};
                if (`${entry.id || ""}` === id)
                    return entry.enabled !== false;
            }

            return false;
        }

        return configBool("utilities.quickToggles." + id, true);
    }

    function screenName() {
        if (modelData && modelData.name !== undefined && modelData.name.length > 0)
            return modelData.name;
        return "";
    }

    function focusedMonitor() {
        if (Quickshell.screens.length <= 1)
            return true;
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== undefined)
            return Hyprland.focusedMonitor.name === screenName();
        const monitor = Hyprland.monitorFor(modelData);
        return monitor && monitor.focused === true;
    }

    function stringListValue(path) {
        const value = configValue(path, []);
        if (Array.isArray(value))
            return value;
        if (typeof value === "string" && value.length > 0)
            return [value];
        return [];
    }

    function stringListContains(values, needle) {
        if (needle.length === 0)
            return false;

        for (let i = 0; i < values.length; i++) {
            if (`${values[i]}` === needle)
                return true;
        }

        return false;
    }

    function stringListContainsLower(values, needles) {
        for (let i = 0; i < values.length; i++) {
            const value = `${values[i]}`.toLowerCase();
            if (value.length === 0)
                continue;

            for (let j = 0; j < needles.length; j++) {
                const needle = `${needles[j]}`.toLowerCase();
                if (needle.length > 0 && (value === needle || needle.indexOf(value) !== -1))
                    return true;
            }
        }

        return false;
    }

    function screenConfigPrefix() {
        const name = screenName();
        return name.length > 0 ? "monitors." + name + "." : "";
    }

    function screenBarEnabled() {
        const name = screenName();
        if (!configBool("bar.enabled", true))
            return false;
        if (stringListContains(stringListValue("bar.excludedScreens"), name))
            return false;
        if (name.length > 0 && !configBool(screenConfigPrefix() + "bar.enabled", true))
            return false;
        return true;
    }

    function barPersistent() {
        return configBool("bar.persistent", true);
    }

    function barShowOnHover() {
        return configBool("bar.showOnHover", false);
    }

    function barDragThreshold() {
        return Math.round(configNumber("bar.dragThreshold", 20, 0, 160));
    }

    function barRevealHeight() {
        return Math.max(4, Math.min(24, Math.round(barDragThreshold() / 2)));
    }

    function hoverIntentDelay() {
        return Math.max(0, Math.min(240, barDragThreshold() * 4));
    }

    function topBarVisible() {
        if (!screenBarEnabled())
            return false;
        if (barPersistent())
            return true;
        if (!barShowOnHover())
            return false;
        return revealHover || topBarHover || openDropdown !== "";
    }

    function scrollActionEnabled(id) {
        return configBool("bar.scrollActions." + id, true);
    }

    function popoutEnabled(id) {
        return configBool("bar.popouts." + id, true);
    }

    function trayBackgroundEnabled() {
        return configBool("bar.tray.background", true);
    }

    function trayCompactEnabled() {
        return configBool("bar.tray.compact", false);
    }

    function trayRecolourEnabled() {
        return configBool("bar.tray.recolour", false);
    }

    function trayIconSize() {
        return Math.round(configNumber("bar.tray.iconSize", 16, 12, 24));
    }

    function activeWindowCompactEnabled() {
        return configBool("bar.activeWindow.compact", false);
    }

    function activeWindowInvertedEnabled() {
        return configBool("bar.activeWindow.inverted", false);
    }

    function activeWindowShowOnHoverEnabled() {
        return configBool("bar.activeWindow.showOnHover", true);
    }

    function clockBackgroundEnabled() {
        return configBool("bar.clock.background", true);
    }

    function toggleStatusDropdown(name) {
        if (popoutEnabled("statusIcons"))
            toggleDropdown(name);
    }

    function workspaceShownCount() {
        return Math.round(configNumber("bar.workspaces.shown", 10, 1, 20));
    }

    function workspaceActiveIndicatorEnabled() {
        return configBool("bar.workspaces.activeIndicator", true);
    }

    function workspaceOccupiedBgEnabled() {
        return configBool("bar.workspaces.occupiedBg", true);
    }

    function workspaceShowWindowsEnabled() {
        return configBool("bar.workspaces.showWindows", true);
    }

    function workspaceShowWindowsOnSpecialEnabled() {
        return configBool("bar.workspaces.showWindowsOnSpecialWorkspaces", true);
    }

    function workspaceWheelThreshold() {
        return Math.max(40, Math.min(360, Math.round(configNumber("bar.workspaces.wheelThreshold", 120, 40, 360))));
    }

    function workspaceWheelCooldownMs() {
        return Math.max(0, Math.min(600, Math.round(configNumber("bar.workspaces.wheelCooldownMs", 180, 0, 600))));
    }

    function workspaceWheelMaxSteps() {
        return Math.max(1, Math.min(8, Math.round(configNumber("bar.workspaces.wheelMaxSteps", 3, 1, 8))));
    }

    function workspaceActiveTrailEnabled() {
        return configBool("bar.workspaces.activeTrail", true);
    }

    function workspacePerMonitorEnabled() {
        return configBool("bar.workspaces.perMonitorWorkspaces", true);
    }

    function workspaceCapitalisation() {
        return configString("bar.workspaces.capitalisation", "preserve").toLowerCase();
    }

    function formatWorkspaceLabel(value) {
        const text = `${value}`;
        const mode = workspaceCapitalisation();
        if (mode === "upper")
            return text.toUpperCase();
        if (mode === "lower")
            return text.toLowerCase();
        if (mode === "title")
            return text.replace(/\b\w/g, letter => letter.toUpperCase());
        return text;
    }

    function workspaceLabelText(id, active, occupied) {
        const activeLabel = configString("bar.workspaces.activeLabel", "");
        if (active && activeLabel.length > 0)
            return formatWorkspaceLabel(activeLabel);

        const occupiedLabel = configString("bar.workspaces.occupiedLabel", "");
        if (occupied && occupiedLabel.length > 0)
            return formatWorkspaceLabel(occupiedLabel);

        const label = configString("bar.workspaces.label", "");
        if (label.length > 0)
            return formatWorkspaceLabel(label);

        return `${id}`;
    }

    function workspaceMaxWindowIcons() {
        return Math.round(configNumber("bar.workspaces.maxWindowIcons", 9, 1, 99));
    }

    function workspaceWindowCountLabel(count) {
        const max = workspaceMaxWindowIcons();
        return count > max ? `${max}+` : `${count}`;
    }

    function audioIncrement() {
        return configNumber("services.audioIncrement", 0.05, 0.01, 0.5);
    }

    function brightnessIncrement() {
        return configNumber("services.brightnessIncrement", 0.05, 0.01, 0.5);
    }

    function maxVolume() {
        return configNumber("services.maxVolume", 1.5, 0.1, 2);
    }

    function pollInterval(path, fallbackValue, minValue, maxValue) {
        return Math.round(configNumber(path, fallbackValue, minValue, maxValue));
    }

    function resourcePollInterval() {
        const dashboardInterval = globalConfigValue("dashboard.resourceUpdateInterval", null);
        if (dashboardInterval !== null && dashboardInterval !== undefined)
            return Math.round(Math.max(500, Math.min(60000, Number(dashboardInterval) || 3000)));
        return pollInterval("services.intervals.resources", 3000, 500, 60000);
    }

    function slowResourcePollInterval() {
        return pollInterval("services.intervals.slowResources", 15000, 1000, 300000);
    }

    function statusPollInterval() {
        return pollInterval("services.intervals.status", 5000, 500, 120000);
    }

    function fastStatusPollInterval() {
        return pollInterval("services.intervals.fastStatus", 1000, 250, 30000);
    }

    function toolPollInterval() {
        return pollInterval("services.intervals.tools", 30000, 1000, 600000);
    }

    function weatherPollInterval() {
        return pollInterval("services.intervals.weather", 1800000, 60000, 7200000);
    }

    function updatePollInterval() {
        return pollInterval("services.intervals.updates", 1800000, 60000, 7200000);
    }

    function sharedCpuPercentCommand() {
        const ttl = Math.max(250, Math.round(resourcePollInterval() * 0.8));
        return "dir=\"${XDG_RUNTIME_DIR:-/tmp}\"; base=\"$dir/dotfiles-cpu-${USER:-user}\"; cache=\"$base.value\"; state=\"$base.state\"; lock=\"$base.lock\"; ttl=" + ttl + "; now=$(date +%s%3N 2>/dev/null || printf '%s000' \"$(date +%s)\"); read cached_at cached_value < \"$cache\" 2>/dev/null || true; if [ -n \"$cached_at\" ] && [ $((now - cached_at)) -lt \"$ttl\" ] 2>/dev/null; then printf '%s' \"${cached_value:-0%}\"; exit 0; fi; { flock -x 9 2>/dev/null || true; now=$(date +%s%3N 2>/dev/null || printf '%s000' \"$(date +%s)\"); read cached_at cached_value < \"$cache\" 2>/dev/null || true; if [ -n \"$cached_at\" ] && [ $((now - cached_at)) -lt \"$ttl\" ] 2>/dev/null; then printf '%s' \"${cached_value:-0%}\"; exit 0; fi; read _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat; idle_now=$((idle + iowait)); total_now=$((user + nice + system + idle + iowait + irq + softirq + steal)); out=0; if read total_prev idle_prev < \"$state\" 2>/dev/null; then total_delta=$((total_now - total_prev)); idle_delta=$((idle_now - idle_prev)); if [ \"$total_delta\" -gt 0 ] 2>/dev/null; then out=$(((100 * (total_delta - idle_delta)) / total_delta)); fi; fi; value=\"${out}%\"; printf '%s %s\\n' \"$total_now\" \"$idle_now\" > \"$state\"; printf '%s %s\\n' \"$now\" \"$value\" > \"$cache\"; printf '%s' \"$value\"; } 9>\"$lock\"";
    }

    function sharedUpdateStatusCommand() {
        const ttl = Math.max(60000, Math.round(updatePollInterval() * 0.9));
        return "dir=\"${XDG_RUNTIME_DIR:-/tmp}\"; base=\"$dir/dotfiles-updates-${USER:-user}\"; cache=\"$base.value\"; lock=\"$base.lock\"; ttl=" + ttl + "; now=$(date +%s%3N 2>/dev/null || printf '%s000' \"$(date +%s)\"); cached_at=$(sed -n '1p' \"$cache\" 2>/dev/null); cached_value=$(sed -n '2p' \"$cache\" 2>/dev/null); if [ -n \"$cached_at\" ] && [ $((now - cached_at)) -lt \"$ttl\" ] 2>/dev/null; then printf '%s' \"${cached_value:-0|0|0}\"; exit 0; fi; { flock -x 9 2>/dev/null || true; now=$(date +%s%3N 2>/dev/null || printf '%s000' \"$(date +%s)\"); cached_at=$(sed -n '1p' \"$cache\" 2>/dev/null); cached_value=$(sed -n '2p' \"$cache\" 2>/dev/null); if [ -n \"$cached_at\" ] && [ $((now - cached_at)) -lt \"$ttl\" ] 2>/dev/null; then printf '%s' \"${cached_value:-0|0|0}\"; exit 0; fi; pac=0; aur=0; if command -v checkupdates >/dev/null 2>&1; then pac=$(timeout 20 checkupdates 2>/dev/null | wc -l); fi; if command -v paru >/dev/null 2>&1; then aur=$(timeout 20 paru -Qua 2>/dev/null | wc -l); elif command -v yay >/dev/null 2>&1; then aur=$(timeout 20 yay -Qua 2>/dev/null | wc -l); fi; total=$((pac + aur)); value=\"$total|$pac|$aur\"; printf '%s\\n%s\\n' \"$now\" \"$value\" > \"$cache\"; printf '%s' \"$value\"; } 9>\"$lock\"";
    }

    function configPollInterval() {
        return pollInterval("services.intervals.config", 2000, 500, 60000);
    }

    function mediaPollInterval() {
        const dashboardInterval = globalConfigValue("dashboard.mediaUpdateInterval", null);
        if (dashboardInterval !== null && dashboardInterval !== undefined)
            return Math.round(Math.max(250, Math.min(60000, Number(dashboardInterval) || 5000)));
        return pollInterval("services.intervals.media", 5000, 250, 60000);
    }

    function osdEnabled(kind) {
        if (!configBool("osd.enabled", true))
            return false;
        if (kind === "brightness" && !configBool("osd.enableBrightness", true))
            return false;
        if (kind === "microphone" && !configBool("osd.enableMicrophone", true))
            return false;
        return true;
    }

    function osdHideDelay() {
        return Math.round(configNumber("osd.hideDelay", 1100, 300, 10000));
    }

    function dashboardEnabled() {
        return configBool("dashboard.enabled", true) && configBool("dashboard.showDashboard", true);
    }

    function dashboardShowOnHover() {
        return configBool("dashboard.showOnHover", false);
    }

    function dashboardShowMedia() {
        return configBool("dashboard.showMedia", true);
    }

    function dashboardShowPerformance() {
        return configBool("dashboard.showPerformance", true);
    }

    function dashboardShowWeather() {
        return configBool("dashboard.showWeather", true);
    }

    function dashboardPerformanceEnabled(id) {
        return configBool("dashboard.performance." + id, true);
    }

    function dashboardSummaryColumns() {
        let count = 0;
        if (dashboardPerformanceEnabled("showCpu"))
            count++;
        if (dashboardPerformanceEnabled("showMemory"))
            count++;
        if (dashboardPerformanceEnabled("showGpu") && gpuAvailable())
            count++;
        if (dashboardPerformanceEnabled("showStorage"))
            count++;
        if (dashboardPerformanceEnabled("showNetwork"))
            count++;
        if (dashboardPerformanceEnabled("showBattery") && hasLaptopBattery())
            count++;
        if (count < 3 && dashboardPerformanceEnabled("showTemperature"))
            count++;
        return Math.max(1, Math.min(3, count));
    }

    function dashboardProfileName() {
        const value = userName.value;
        return value.length > 0 ? value : "Desktop";
    }

    function dashboardProfileImage() {
        const configured = configString("dashboard.profileImage", "");
        if (configured.length > 0) {
            if (configured[0] === "/")
                return "file://" + configured;
            if (configured.indexOf("file://") === 0 || configured.indexOf("http://") === 0 || configured.indexOf("https://") === 0)
                return configured;
        }

        return profileImage.value.length > 0 ? "file://" + profileImage.value : "";
    }

    function profileImageItems() {
        if (profileImageCandidates.value.length === 0)
            return [];
        return profileImageCandidates.value.split("\n").filter(line => line.length > 0);
    }

    function profileImageName(path) {
        const parts = `${path || ""}`.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : "Image";
    }

    function chooseProfileImage(path) {
        const file = `${path || ""}`;
        if (file.length === 0)
            return;
        closeDropdown();
        run("cp " + shellQuote(file) + " \"$HOME/.face\"; command -v notify-send >/dev/null 2>&1 && notify-send 'Profile picture updated' '~/.face was updated'");
    }

    function dashboardUptime() {
        return uptime.value.length > 0 ? uptime.value : "-";
    }

    function clockPattern() {
        if (configBool("services.useTwelveHourClock", false))
            return configBool("bar.clock.showDate", true) ? "MM.dd ddd AP h:mm" : "AP h:mm";
        return configBool("bar.clock.showDate", true) ? "MM.dd ddd HH:mm" : "HH:mm";
    }

    function dropdownWidth() {
        if (openDropdown === "dashboard")
            return 380;
        if (openDropdown === "media")
            return 440;
        if (openDropdown === "calendar")
            return 330;
        if (openDropdown === "system")
            return 260;
        if (openDropdown === "audio")
            return 360;
        if (openDropdown === "network")
            return 360;
        if (openDropdown === "nexus")
            return 390;
        if (openDropdown === "bluetooth")
            return 360;
        if (openDropdown === "keyboard")
            return 320;
        if (openDropdown === "brightness")
            return 320;
        if (openDropdown === "activewindow")
            return 380;
        if (openDropdown === "power")
            return 260;
        if (openDropdown === "idlesettings")
            return 380;
        if (openDropdown === "theme")
            return 360;
        if (openDropdown === "quick")
            return 320;
        if (openDropdown === "clipboard")
            return 380;
        if (openDropdown === "profileimage")
            return 380;
        if (openDropdown === "updates")
            return 300;
        if (openDropdown === "tray")
            return 260;
        return 1;
    }

    function dropdownHeight() {
        const panelMaxHeight = Math.max(120, modelData.height - barHeight() - 20);

        if (openDropdown === "dashboard")
            return Math.min(Math.max(160, dashboardPanelContent.implicitHeight), Math.min(620, panelMaxHeight));
        if (openDropdown === "media")
            return Math.min(Math.max(160, mediaPanelContent.implicitHeight + 32), Math.min(560, panelMaxHeight));
        if (openDropdown === "calendar")
            return calendarPickerOpen ? 530 : 405;
        if (openDropdown === "system")
            return 330;
        if (openDropdown === "audio")
            return 250;
        if (openDropdown === "network")
            return 360;
        if (openDropdown === "nexus")
            return 430;
        if (openDropdown === "bluetooth")
            return 360;
        if (openDropdown === "keyboard")
            return 190;
        if (openDropdown === "brightness")
            return 150;
        if (openDropdown === "activewindow")
            return 250;
        if (openDropdown === "power")
            return Math.min(powerColumn.implicitHeight + powerColumn.panelPadding * 2, panelMaxHeight);
        if (openDropdown === "idlesettings")
            return 430;
        if (openDropdown === "theme")
            return 430;
        if (openDropdown === "quick")
            return 430;
        if (openDropdown === "clipboard")
            return 430;
        if (openDropdown === "profileimage")
            return 430;
        if (openDropdown === "updates")
            return 230;
        if (openDropdown === "tray")
            return Math.min(420, Math.max(120, trayMenuContent.implicitHeight + (trayMenuHeader.visible ? trayMenuHeader.height + trayMenuColumn.spacing : 0) + 16));
        return 1;
    }

    function dropdownX() {
        if (openDropdown === "dashboard")
            return 10;
        if (openDropdown === "media")
            return 10;
        if (openDropdown === "activewindow")
            return 120;
        if (openDropdown === "calendar")
            return Math.max(10, (topBar.width - dropdownWidth()) / 2);
        if (openDropdown === "system" || openDropdown === "power" || openDropdown === "idlesettings" || openDropdown === "audio" || openDropdown === "network" || openDropdown === "nexus" || openDropdown === "bluetooth" || openDropdown === "keyboard" || openDropdown === "brightness" || openDropdown === "theme" || openDropdown === "quick" || openDropdown === "clipboard" || openDropdown === "profileimage" || openDropdown === "updates")
            return Math.max(10, topBar.width - dropdownWidth() - 10);
        if (openDropdown === "tray")
            return Math.max(10, Math.min(trayDropdownX, topBar.width - dropdownWidth() - 10));
        return 10;
    }

    function monthDayKey(date) {
        const month = `${date.getMonth() + 1}`.padStart(2, "0");
        const day = `${date.getDate()}`.padStart(2, "0");
        return `${month}-${day}`;
    }

    function dateKey(date) {
        return `${date.getFullYear()}-${monthDayKey(date)}`;
    }

    function holidayName(date) {
        const map = {
            "01-01": "신정",
            "03-01": "삼일절",
            "05-05": "어린이날",
            "06-06": "현충일",
            "08-15": "광복절",
            "10-03": "개천절",
            "10-09": "한글날",
            "12-25": "성탄절"
        };
        return map[monthDayKey(date)] || "";
    }

    function viewedMonth() {
        const date = new Date();
        date.setDate(1);
        date.setMonth(date.getMonth() + calendarMonthOffset);
        return date;
    }

    function monthTitle() {
        return Qt.formatDate(viewedMonth(), "yyyy년 M월");
    }

    function calendarDays() {
        const view = viewedMonth();
        const start = new Date(view.getFullYear(), view.getMonth(), 1 - new Date(view.getFullYear(), view.getMonth(), 1).getDay());
        const today = new Date();
        const days = [];

        for (let i = 0; i < 42; i++) {
            const date = new Date(start);
            date.setDate(start.getDate() + i);
            const holiday = holidayName(date);
            days.push({
                label: `${date.getDate()}`,
                key: dateKey(date),
                currentMonth: date.getMonth() === view.getMonth(),
                weekend: date.getDay() === 0 || date.getDay() === 6,
                holiday: holiday.length > 0,
                today: date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate(),
                detail: `${Qt.formatDate(date, "yyyy년 M월 d일 ddd")}${holiday.length > 0 ? " · " + holiday : ""}`
            });
        }

        return days;
    }

    function selectedCalendarDetail() {
        const days = calendarDays();
        for (let i = 0; i < days.length; i++) {
            if (days[i].key === selectedCalendarKey)
                return days[i].detail;
        }
        return Qt.formatDate(new Date(), "yyyy년 M월 d일 ddd");
    }

    function daysUntil(target) {
        const today = new Date();
        const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        const end = new Date(target.getFullYear(), target.getMonth(), target.getDate());
        return Math.round((end - start) / 86400000);
    }

    function nextHolidaySummary() {
        const today = new Date();
        for (let i = 0; i < 370; i++) {
            const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
            const name = holidayName(date);
            if (name.length > 0) {
                const days = daysUntil(date);
                return days === 0 ? `${name} 오늘` : `${name} D-${days}`;
            }
        }
        return "공휴일 -";
    }

    function weekendSummary() {
        const today = new Date();
        for (let i = 0; i < 8; i++) {
            const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
            if (date.getDay() === 0 || date.getDay() === 6) {
                const days = daysUntil(date);
                return days === 0 ? "주말 오늘" : `주말 D-${days}`;
            }
        }
        return "주말 -";
    }

    function run(command) {
        runner.exec(["sh", "-c", command]);
    }

    function shellQuote(value) {
        return "'" + `${value}`.replace(/'/g, "'\\''") + "'";
    }

    function commandFromValue(value) {
        if (Array.isArray(value)) {
            const parts = [];
            for (let i = 0; i < value.length; i++)
                parts.push(shellQuote(value[i]));
            return parts.join(" ");
        }
        if (typeof value === "string")
            return value;
        return "";
    }

    function playerSearchText(value) {
        if (!value)
            return "";

        return `${value.identity || ""} ${value.desktopEntry || ""} ${value.dbusName || ""}`.toLowerCase();
    }

    function playerIsBrowser(value) {
        const search = playerSearchText(value);
        return search.indexOf("chrome") !== -1 || search.indexOf("chromium") !== -1 || search.indexOf("browser-integration") !== -1;
    }

    function playerGroupKey(value) {
        if (!value)
            return "";

        if (playerIsBrowser(value)) {
            return "browser:chrome";
        }

        const desktopEntry = `${value.desktopEntry || ""}`.toLowerCase();
        if (desktopEntry.length > 0)
            return "desktop:" + desktopEntry;
        return "dbus:" + `${value.dbusName || value.identity || ""}`.toLowerCase();
    }

    function playerQuality(value) {
        if (!value)
            return -1;

        const search = playerSearchText(value);
        let score = playerPriority(value);
        if (value.isPlaying)
            score += 40;
        const title = `${value.trackTitle || ""}`.trim();
        const artist = `${value.trackArtist || ""}`.trim();
        const album = `${value.trackAlbum || ""}`.trim();
        if (title.length > 0 && title !== "YouTube Music")
            score += 20;
        if (artist.length > 0)
            score += 12;
        if (album.length > 0)
            score += 8;
        if (mediaArtIsUsable(value, value.trackArtUrl))
            score += 8;
        if (search.indexOf("plasma-browser-integration") !== -1)
            score += 25;
        if (search.indexOf("chromium.instance") !== -1)
            score -= 15;
        return score;
    }

    function mediaPlayers() {
        const players = Mpris.players.values || [];
        const grouped = ({});
        const order = [];

        for (let i = 0; i < players.length; i++) {
            const current = players[i];
            const key = playerGroupKey(current);
            if (key.length === 0)
                continue;
            if (!(key in grouped)) {
                grouped[key] = current;
                order.push(key);
                continue;
            }
            if (playerQuality(current) > playerQuality(grouped[key]))
                grouped[key] = current;
        }

        const result = [];
        for (let i = 0; i < order.length; i++)
            result.push(grouped[order[i]]);
        return result;
    }

    function configuredPlayerAliases() {
        const defaults = [
            { match: "spotify", label: "Spotify", priority: 100 },
            { match: "youtube music", label: "YouTube Music", priority: 98 },
            { match: "youtube", label: "YouTube", priority: 96 },
            { match: "chromium", label: "Chromium Media", priority: 86 },
            { match: "chrome", label: "Chrome Media", priority: 86 },
            { match: "firefox", label: "Firefox Media", priority: 82 },
            { match: "vlc", label: "VLC", priority: 70 },
            { match: "mpv", label: "mpv", priority: 70 },
            { match: "elisa", label: "Elisa", priority: 65 },
            { match: "kdeconnect", label: "KDE Connect", priority: 50 },
            { match: "kde connect", label: "KDE Connect", priority: 50 }
        ];
        const custom = configValue("services.playerAliases", []);
        return Array.isArray(custom) ? custom.concat(defaults) : defaults;
    }

    function playerAlias(value) {
        const search = playerSearchText(value);
        const aliases = configuredPlayerAliases();
        for (let i = 0; i < aliases.length; i++) {
            const alias = aliases[i] || {};
            const match = `${alias.match || alias.from || ""}`.toLowerCase();
            if (match.length > 0 && search.indexOf(match) !== -1)
                return alias;
        }

        return null;
    }

    function playerPriority(value) {
        const defaultPlayer = configString("services.defaultPlayer", "");
        if (defaultPlayer.length > 0 && playerSearchText(value).indexOf(defaultPlayer.toLowerCase()) !== -1)
            return 1000;

        const alias = playerAlias(value);
        return alias && alias.priority !== undefined ? Number(alias.priority) : 0;
    }

    function chooseMediaPlayer(players) {
        if (!players || players.length === 0)
            return null;

        let best = players[0];
        let bestPriority = playerQuality(best);
        for (let i = 0; i < players.length; i++) {
            const priority = playerQuality(players[i]);
            if (priority > bestPriority) {
                best = players[i];
                bestPriority = priority;
            }
        }

        return best;
    }

    function displayPlayer(value) {
        if (!value)
            return "Media";

        const alias = playerAlias(value);
        if (alias) {
            const label = `${alias.label || alias.to || ""}`;
            if (label.length > 0)
                return label;
        }

        return value.identity || "Media";
    }

    function mediaTitle() {
        return player ? player.trackTitle : "";
    }

    function mediaSubtitle() {
        if (!player)
            return "";

        return [player.trackArtist, player.trackAlbum].filter(value => value && value.length > 0).join(" · ");
    }

    function mediaArtIsUsable(value, artUrl) {
        const art = `${artUrl || ""}`.toLowerCase();
        if (art.length === 0)
            return false;

        if (!playerIsBrowser(value))
            return true;

        const looksLikeBrowserIcon =
            art.indexOf("google-chrome") !== -1 ||
            art.indexOf("chrome.png") !== -1 ||
            art.indexOf("chromium") !== -1 ||
            art.indexOf("browser-integration") !== -1 ||
            art.indexOf("image://icon/chrome") !== -1 ||
            art.indexOf("image://icon/google-chrome") !== -1 ||
            art.indexOf("image://icon/chromium") !== -1;

        return !looksLikeBrowserIcon;
    }

    function mediaArtUrl() {
        if (mediaArtIsUsable(player, player ? player.trackArtUrl : ""))
            return player.trackArtUrl;

        const group = playerGroupKey(player);
        if (group.length === 0)
            return "";

        const players = Mpris.players.values || [];
        let best = "";
        let bestScore = -1;
        for (let i = 0; i < players.length; i++) {
            const current = players[i];
            const art = `${current.trackArtUrl || ""}`;
            if (!mediaArtIsUsable(current, art) || playerGroupKey(current) !== group)
                continue;

            const score = playerQuality(current);
            if (score > bestScore) {
                best = art;
                bestScore = score;
            }
        }
        return best;
    }

    function mediaCommandPlayer(capability) {
        if (!player)
            return null;

        if (player[capability])
            return player;

        const group = playerGroupKey(player);
        if (group.length === 0)
            return null;

        const players = Mpris.players.values || [];
        let best = null;
        let bestScore = -1;
        for (let i = 0; i < players.length; i++) {
            const current = players[i];
            if (!current || playerGroupKey(current) !== group || !current[capability])
                continue;

            const score = playerQuality(current);
            if (score > bestScore) {
                best = current;
                bestScore = score;
            }
        }

        return best;
    }

    function mediaCan(capability) {
        return mediaCommandPlayer(capability) !== null;
    }

    function mediaTogglePlaying() {
        const target = mediaCommandPlayer("canTogglePlaying");
        if (target)
            target.togglePlaying();
    }

    function mediaPrevious() {
        const target = mediaCommandPlayer("canGoPrevious");
        if (target)
            target.previous();
    }

    function mediaNext() {
        const target = mediaCommandPlayer("canGoNext");
        if (target)
            target.next();
    }

    function mediaSupportsShuffle() {
        return player && !playerIsBrowser(player) && player.shuffleSupported;
    }

    function mediaSupportsLoop() {
        return player && !playerIsBrowser(player) && player.loopSupported;
    }

    function lyricsEnabled() {
        const backend = configString("services.lyricsBackend", "Local").toLowerCase();
        return backend !== "none" && backend !== "off" && backend !== "disabled";
    }

    function lyricsDir() {
        return configString("paths.lyricsDir", "~/Music/lyrics");
    }

    function lyricsLookupCommand() {
        if (!lyricsEnabled() || !player)
            return "exit 0";

        const title = player.trackTitle || "";
        const artist = player.trackArtist || "";
        if (title.length === 0)
            return "exit 0";

        return "dir=" + shellQuote(lyricsDir()) + "; title=" + shellQuote(title) + "; artist=" + shellQuote(artist) + "; " +
            "case \"$dir\" in '~') dir=\"$HOME\";; '~/'*) dir=\"$HOME/${dir#~/}\";; esac; [ -d \"$dir\" ] || exit 0; " +
            "norm() { printf '%s' \"$1\" | tr '[:upper:]' '[:lower:]' | sed 's/\\[[^]]*\\]//g; s/([^)]*)//g; s/[^a-z0-9가-힣]/ /g; s/[[:space:]]\\+/ /g; s/^ //; s/ $//'; }; " +
            "needle=\"$(norm \"$artist $title\")\"; needle2=\"$(norm \"$title\")\"; best=; " +
            "while IFS= read -r f; do base=$(basename \"$f\"); key=$(norm \"${base%.*}\"); if [ \"$key\" = \"$needle\" ] || [ \"$key\" = \"$needle2\" ] || { [ -n \"$needle2\" ] && printf '%s' \"$key\" | grep -F \"$needle2\" >/dev/null 2>&1; }; then best=\"$f\"; break; fi; done < <(find \"$dir\" -type f \\( -iname '*.lrc' -o -iname '*.txt' \\) 2>/dev/null | sort); " +
            "[ -n \"$best\" ] || exit 0; sed -E 's/^\\[[0-9:.]+\\][[:space:]]*//; s/<[^>]*>//g' \"$best\" | awk 'NF {print; n++} n>=8 {exit}'";
    }

    function mediaLyricsText() {
        return mediaLyrics.value.trim();
    }

    function playerKey(value) {
        if (!value)
            return "";
        return `${value.dbusName || ""}|${value.desktopEntry || ""}|${value.identity || ""}`;
    }

    function playerByKey(key) {
        const players = mediaPlayers();
        for (let i = 0; i < players.length; i++) {
            if (playerKey(players[i]) === key)
                return players[i];
        }
        return null;
    }

    function selectPlayer(value) {
        selectedPlayerKey = playerKey(value);
    }

    function volumePercent() {
        return Math.round(currentVolume() * 100);
    }

    function currentVolume() {
        if (volumeOverride >= 0)
            return volumeOverride;

        const parts = volumeStatus.value.split("|");
        if (parts.length > 1 && parts[1].length > 0)
            return Number(parts[1]) / 100;

        return sink && sink.audio ? sink.audio.volume : 0;
    }

    function volumeMuted() {
        if (muteOverride >= 0)
            return muteOverride === 1;

        const parts = volumeStatus.value.split("|");
        if (parts.length > 0 && parts[0].length > 0)
            return parts[0] === "muted";

        return sink && sink.audio && sink.audio.muted;
    }

    function setVolume(nextValue) {
        const limit = maxVolume();
        const value = Math.max(0, Math.min(limit, nextValue));
        volumeOverride = value;
        volumeOverrideTimer.restart();
        showOsd("volume", value, limit, volumeMuted());
        runner.exec(["wpctl", "set-volume", "-l", `${limit}`, "@DEFAULT_AUDIO_SINK@", `${Math.round(value * 100)}%`]);
    }

    function adjustVolume(delta) {
        setVolume(currentVolume() + delta);
    }

    function toggleMute() {
        muteOverride = volumeMuted() ? 0 : 1;
        muteOverrideTimer.restart();
        showOsd("volume", currentVolume(), maxVolume(), muteOverride === 1);
        runner.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    function currentBrightness() {
        if (brightnessOverride >= 0)
            return brightnessOverride;

        const value = Number(backlight.value.replace("%", ""));
        if (!Number.isNaN(value))
            return Math.max(0, Math.min(1, value / 100));

        return 0;
    }

    function brightnessPercent() {
        return Math.round(currentBrightness() * 100);
    }

    function setBrightness(nextValue) {
        const value = Math.max(0.01, Math.min(1, nextValue));
        brightnessOverride = value;
        brightnessOverrideTimer.restart();
        showOsd("brightness", value, 1, false);
        runner.exec(["brightnessctl", "set", `${Math.round(value * 100)}%`]);
    }

    function adjustBrightness(delta) {
        setBrightness(currentBrightness() + delta);
    }

    function setPowerProfile(profile, cliName) {
        PowerProfiles.profile = profile;
        runner.exec(["powerprofilesctl", "set", cliName]);
    }

    function showOsd(kind, value, max, muted) {
        if (!osdEnabled(kind))
            return;

        osdKind = kind;
        osdValue = value;
        osdMax = max;
        osdMuted = muted;
        osdVisible = true;
        osdTimer.restart();
    }

    function osdIcon() {
        if (osdKind === "brightness")
            return "display-brightness-symbolic";
        if (osdKind === "microphone")
            return osdMuted ? "microphone-disabled-symbolic" : "microphone-sensitivity-high-symbolic";
        return osdMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic";
    }

    function osdTitle() {
        if (osdKind === "brightness")
            return "Brightness";
        if (osdKind === "microphone")
            return osdMuted ? "Mic muted" : "Mic live";
        return osdMuted ? "Muted" : "Volume";
    }

    function osdPercent() {
        return Math.round(osdValue * 100);
    }

    function percentNumber(value) {
        const text = `${value || ""}`.replace("%", "").trim();
        const next = Number(text);
        return Number.isNaN(next) ? 0 : Math.max(0, Math.min(100, next));
    }

    function temperatureNumber() {
        const raw = `${temperature.value || ""}`;
        const text = raw.replace("°C", "").replace("°F", "").trim();
        const value = Number(text);
        if (Number.isNaN(value))
            return 0;
        if (raw.indexOf("°F") !== -1)
            return (value - 32) * 5 / 9;
        return value;
    }

    function temperatureHot() {
        return temperatureNumber() >= 70;
    }

    function temperatureDanger() {
        return temperatureNumber() >= 85;
    }

    function storagePercent() {
        const parts = storage.value.split("|");
        return parts.length > 1 ? percentNumber(parts[1]) : 0;
    }

    function storageLabel() {
        const parts = storage.value.split("|");
        return parts.length > 0 && parts[0].length > 0 ? parts[0] : "-";
    }

    function powerProfileIcon() {
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "power-profile-power-saver-symbolic";
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "power-profile-performance-symbolic";
        return "power-profile-balanced-symbolic";
    }

    function powerProfileLabel() {
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "save";
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "perf";
        return "balanced";
    }

    function hasLaptopBattery() {
        return UPower.displayDevice !== null && UPower.displayDevice.isPresent && UPower.displayDevice.percentage > 0;
    }

    function batteryParts() {
        return batteryInfo.value.length > 0 ? batteryInfo.value.split("|") : [];
    }

    function batteryState() {
        const parts = batteryParts();
        return parts.length > 0 && parts[0].length > 0 ? parts[0] : "unknown";
    }

    function batteryTime() {
        const parts = batteryParts();
        return parts.length > 1 && parts[1].length > 0 ? parts[1] : "-";
    }

    function batteryPrefix() {
        const state = batteryState();
        if (state.indexOf("charging") !== -1 && state.indexOf("discharging") === -1)
            return "+";
        if (state.indexOf("fully") !== -1 || state === "full")
            return "=";
        return "";
    }

    function batteryAccent(percentage) {
        if (batteryState().indexOf("charging") !== -1 && batteryState().indexOf("discharging") === -1)
            return Theme.accent;
        if (percentage <= 15)
            return Theme.danger;
        if (percentage <= 30)
            return Theme.warning;
        return Theme.success;
    }

    function batteryWarnLevels() {
        const configured = configValue("general.battery.warnLevels", []);
        if (Array.isArray(configured) && configured.length > 0)
            return configured;

        return [
            { level: 20, title: "Low battery", message: "Battery is getting low", icon: "battery-caution-symbolic", critical: false },
            { level: 10, title: "Very low battery", message: "Plug in power soon", icon: "battery-low-symbolic", critical: false },
            { level: 5, title: "Critical battery", message: "Suspending soon unless power is connected", icon: "battery-empty-symbolic", critical: true }
        ];
    }

    function batteryWarningCommand() {
        const percentage = hasLaptopBattery() ? Math.round(UPower.displayDevice.percentage) : -1;
        const state = batteryState();
        const criticalLevel = Math.round(configNumber("general.battery.criticalLevel", 3, 1, 50));
        const action = configString("general.battery.criticalAction", "none");
        const warnJson = JSON.stringify(batteryWarnLevels()).replace(/'/g, "'\\''");

        return "pct=" + shellQuote(percentage) + "; state=" + shellQuote(state) + "; critical=" + shellQuote(criticalLevel) + "; action=" + shellQuote(action) + "; levels='" + warnJson + "'; " +
            "store=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles\"; file=\"$store/quickshell-battery-warning-level\"; mkdir -p \"$store\"; " +
            "case \"$state\" in *charging*|fully-charged|full) rm -f \"$file\"; exit 0;; esac; " +
            "[ \"$pct\" -ge 0 ] 2>/dev/null || exit 0; last=$(cat \"$file\" 2>/dev/null || printf 101); " +
            "entry=$(printf '%s' \"$levels\" | jq -r --argjson pct \"$pct\" '[.[] | select((.level // 0) >= $pct)] | sort_by(.level) | .[0] // empty' 2>/dev/null); " +
            "[ -n \"$entry\" ] || exit 0; level=$(printf '%s' \"$entry\" | jq -r '.level // empty'); [ -n \"$level\" ] || exit 0; " +
            "[ \"$level\" -lt \"$last\" ] 2>/dev/null || exit 0; " +
            "title=$(printf '%s' \"$entry\" | jq -r '.title // \"Low battery\"'); msg=$(printf '%s' \"$entry\" | jq -r '.message // \"Plug in power\"'); icon=$(printf '%s' \"$entry\" | jq -r '.icon // \"battery-caution-symbolic\"'); critical_flag=$(printf '%s' \"$entry\" | jq -r 'if .critical == true then true else false end'); " +
            "urgency=normal; [ \"$critical_flag\" = true ] && urgency=critical; command -v notify-send >/dev/null 2>&1 && notify-send -u \"$urgency\" -i \"$icon\" \"$title\" \"$msg\"; printf '%s' \"$level\" > \"$file\"; " +
            "if [ \"$pct\" -le \"$critical\" ] 2>/dev/null; then case \"$action\" in suspend) systemctl suspend;; hibernate) systemctl hibernate;; suspendThenHibernate|suspend-then-hibernate) systemctl suspend-then-hibernate;; poweroff) systemctl poweroff;; esac; fi";
    }

    function applyTheme(name) {
        closeDropdown();
        const command = "cd \"$HOME/dotfiles\" && ./apply-theme.sh " + shellQuote(name);
        runner.exec(["sh", "-c", "setsid sh -c " + shellQuote(command) + " >/tmp/quickshell-apply-theme.log 2>&1 &"]);
    }

    function themeModeLabel(mode) {
        if (mode === "light")
            return "Light";
        return "Dark";
    }

    function colorSchemeLabel(name) {
        for (let i = 0; i < colorSchemes.length; i++) {
            if (colorSchemes[i].name === name || colorSchemes[i].family === name)
                return colorSchemes[i].familyLabel || colorSchemes[i].label;
        }
        return name;
    }

    function currentThemeOption() {
        for (let i = 0; i < colorSchemes.length; i++) {
            if (colorSchemes[i].name === Theme.name)
                return colorSchemes[i];
        }
        return null;
    }

    function currentThemeFamily() {
        const option = currentThemeOption();
        if (option)
            return option.family;
        return Theme.colorScheme || Theme.name;
    }

    function themeForMode(mode) {
        const family = currentThemeFamily();
        for (let i = 0; i < colorSchemes.length; i++) {
            if (colorSchemes[i].family === family && colorSchemes[i].mode === mode)
                return colorSchemes[i];
        }
        return null;
    }

    function canApplyMode(mode) {
        const option = themeForMode(mode);
        return option !== null && option.name !== Theme.name;
    }

    function applyThemeMode(mode) {
        const option = themeForMode(mode);
        if (option)
            applyTheme(option.name);
    }

    function dndEnabled() {
        return dndStatus.value === "true";
    }

    function toggleDnd() {
        runner.exec(["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-dnd.enabled\"; mkdir -p \"$(dirname \"$state\")\"; if [ \"$(cat \"$state\" 2>/dev/null)\" = true ]; then printf false > \"$state\"; else printf true > \"$state\"; fi"]);
    }

    function idleInhibitAvailable() {
        return idleInhibitStatus.value.length > 0 && idleInhibitStatus.value !== "missing";
    }

    function idleInhibitEnabled() {
        return idleInhibitStatus.value === "active";
    }

    function toggleIdleInhibit() {
        idleInhibitRefreshNonce++;
        runner.exec(["sh", "-c", "if command -v qs-idle-inhibit >/dev/null 2>&1; then qs-idle-inhibit toggle; else ~/.local/bin/qs-idle-inhibit toggle; fi"]);
    }

    function idleSettingsObject() {
        return parseConfigText(idleSettings.value);
    }

    function idleBool(key, fallbackValue) {
        const settings = idleSettingsObject();
        if (settings && typeof settings === "object" && key in settings)
            return settings[key] === true || settings[key] === "true" || settings[key] === 1;
        return fallbackValue;
    }

    function idleSeconds(key, fallbackValue) {
        const settings = idleSettingsObject();
        const raw = settings && typeof settings === "object" && key in settings ? Number(settings[key]) : fallbackValue;
        return Number.isFinite(raw) ? Math.max(0, Math.round(raw)) : fallbackValue;
    }

    function idleMinutesLabel(key, fallbackValue) {
        const seconds = idleSeconds(key, fallbackValue);
        if (seconds <= 0)
            return "Off";
        return `${Math.round(seconds / 60)} min`;
    }

    function setIdleValue(key, value) {
        idleSettingsRefreshNonce++;
        runner.exec(["sh", "-c", "~/.local/bin/hypr-idle-settings set " + shellQuote(key) + " " + shellQuote(`${value}`)]);
    }

    function toggleIdleSetting(key, fallbackValue) {
        setIdleValue(key, idleBool(key, fallbackValue) ? "false" : "true");
    }

    function adjustIdleTimeout(key, fallbackValue, deltaMinutes, minSeconds, maxSeconds) {
        const next = Math.max(minSeconds, Math.min(maxSeconds, idleSeconds(key, fallbackValue) + deltaMinutes * 60));
        setIdleValue(key, next);
    }

    function applyIdleSettings() {
        idleSettingsRefreshNonce++;
        runner.exec(["sh", "-c", "~/.local/bin/hypr-idle-settings apply"]);
    }

    function gameModeEnabled() {
        return gameModeStatus.value === "true";
    }

    function toggleGameMode() {
        runner.exec(["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-game-mode.enabled\"; mkdir -p \"$(dirname \"$state\")\"; if [ \"$(cat \"$state\" 2>/dev/null)\" = true ]; then printf false > \"$state\"; hyprctl reload >/dev/null 2>&1 || true; else printf true > \"$state\"; hyprctl keyword animations:enabled 0 >/dev/null 2>&1 || true; hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1 || true; fi"]);
    }

    function recordingAvailable() {
        return recordingTool.value === "wf-recorder";
    }

    function recordingActive() {
        return recordingStatus.value === "active";
    }

    function recordingDetail() {
        if (recordingActive())
            return "Recording active. Click to stop.";
        if (recordingRegionTool.value === "slurp")
            return "Select a region and save it";
        return "Record the current screen";
    }

    function toggleRecording() {
        if (recordingActive()) {
            runner.exec(["sh", "-c", "pkill -INT -x wf-recorder >/dev/null 2>&1 || true"]);
            return;
        }

        runner.exec(["sh", "-c", "mkdir -p \"$HOME/Videos/Recordings\"; out=\"$HOME/Videos/Recordings/recording-$(date +%Y%m%d-%H%M%S).mp4\"; if command -v slurp >/dev/null 2>&1; then wf-recorder -g \"$(slurp)\" -f \"$out\" >/dev/null 2>&1 & else wf-recorder -f \"$out\" >/dev/null 2>&1 & fi"]);
    }

    function updateParts() {
        return updateStatus.value.length > 0 ? updateStatus.value.split("|") : ["0", "0", "0"];
    }

    function updateCount() {
        const parts = updateParts();
        return parts.length > 0 ? Number(parts[0]) : 0;
    }

    function updateLabel() {
        const parts = updateParts();
        if (parts.length < 3)
            return "0 updates";

        return `${parts[0]} updates · pacman ${parts[1]} · aur ${parts[2]}`;
    }

    function updateCommand() {
        const terminal = configuredAppCommand("terminal", ["kitty", "alacritty"]);
        if (terminal.length > 0)
            return terminal + " -e paru -Syu";
        return "paru -Syu";
    }

    function appCandidates(id, fallback) {
        const configured = configValue("general.apps." + id, []);
        if (Array.isArray(configured) && configured.length > 0)
            return configured;
        if (typeof configured === "string" && configured.length > 0)
            return [configured];
        return fallback;
    }

    function commandName(command) {
        return `${command}`.trim().split(/\s+/)[0];
    }

    function configuredAppDetectCommand(id, fallback) {
        const candidates = appCandidates(id, fallback);
        let script = "";
        for (let i = 0; i < candidates.length; i++) {
            const command = `${candidates[i]}`;
            const binary = commandName(command);
            if (binary.length === 0)
                continue;
            script += "if command -v " + shellQuote(binary) + " >/dev/null 2>&1; then printf %s " + shellQuote(command) + "; exit 0; fi; ";
        }
        return script;
    }

    function configuredAppCommand(id, fallback) {
        const candidates = appCandidates(id, fallback);
        return candidates.length > 0 ? `${candidates[0]}` : "";
    }

    function terminalCommand(command) {
        const terminal = configuredAppCommand("terminal", ["kitty", "alacritty"]);
        if (terminal.length > 0)
            return terminal + " -e " + command;
        return command;
    }

    function sessionCommandFromValue(commandValue, fallback) {
        if (typeof commandValue === "string" && commandValue.length > 0)
            return commandValue;

        if (Array.isArray(commandValue)) {
            if (commandValue.length === 0)
                return fallback;
            if (`${commandValue[0]}` === "logout")
                return "hyprctl dispatch exit";
            if (`${commandValue[0]}` === "poweroff")
                return "systemctl poweroff";
            if (`${commandValue[0]}` === "reboot")
                return "systemctl reboot";
            if (`${commandValue[0]}` === "hibernate")
                return "systemctl hibernate";
            if (`${commandValue[0]}` === "suspendThenHibernate")
                return "systemctl suspend-then-hibernate";

            return commandValue.map(part => shellQuote(part)).join(" ");
        }

        return fallback;
    }

    function defaultLockCommand() {
        return "if command -v hyprlock >/dev/null 2>&1; then pidof hyprlock >/dev/null 2>&1 || hyprlock; else loginctl lock-session; fi";
    }

    function sessionCommand(id, fallback) {
        const lockCommand = configValue("lock.commands." + id, "");
        if (lockCommand !== "")
            return sessionCommandFromValue(lockCommand, fallback);

        return sessionCommandFromValue(configValue("session.commands." + id, ""), fallback);
    }

    function sessionIcon(id, fallback) {
        return configString("session.icons." + id, fallback);
    }

    function clipboardAvailable() {
        return clipboardTool.value.length > 0;
    }

    function clipboardItems() {
        if (!clipboardAvailable() || clipboardHistory.value.length === 0)
            return [];
        return clipboardHistory.value.split("\n").filter(line => line.length > 0);
    }

    function clipboardPreview(value) {
        const text = `${value || ""}`.replace(/\t/g, "  ").replace(/\s+/g, " ").trim();
        return text.length > 0 ? text : "Clipboard item";
    }

    function restoreClipboardItem(value) {
        const item = `${value || ""}`;
        if (item.length === 0)
            return;
        closeDropdown();
        run("printf %s " + shellQuote(item) + " | cliphist decode | wl-copy");
    }

    function gpuParts() {
        return gpuStatus.value.length > 0 ? gpuStatus.value.split("|") : [];
    }

    function gpuAvailable() {
        return gpuParts().length > 1;
    }

    function gpuLabel() {
        const parts = gpuParts();
        if (parts.length < 3)
            return "-";
        return `${parts[0]} · ${parts[2]}`;
    }

    function temperatureStatusCommand() {
        const unit = configBool("services.useFahrenheitPerformance", false) ? "f" : "c";
        return "unit=" + shellQuote(unit) + "; for f in /sys/class/thermal/thermal_zone*/temp; do [ -r \"$f\" ] || continue; v=$(cat \"$f\"); [ \"$v\" -gt 0 ] 2>/dev/null || continue; c=$((v / 1000)); if [ \"$unit\" = f ]; then printf '%d°F' $((c * 9 / 5 + 32)); else printf '%d°C' \"$c\"; fi; exit; done";
    }

    function gpuStatusCommand() {
        const type = configString("services.gpuType", "").toLowerCase();
        const unit = configBool("services.useFahrenheitPerformance", false) ? "f" : "c";
        const unitPrefix = "unit=" + shellQuote(unit) + "; ";
        const nvidia = unitPrefix + "if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F', *' -v unit=\"$unit\" 'NR==1 {temp=$3; suffix=\"°C\"; if (unit == \"f\") {temp=int(temp * 9 / 5 + 32); suffix=\"°F\"}; printf \"%s|%s|%s%s\", $1, $2, temp, suffix}'; exit 0; fi";
        const drm = unitPrefix + "for busy in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$busy\" ] || continue; pct=$(cat \"$busy\" 2>/dev/null); [ -n \"$pct\" ] || continue; temp=\"\"; for hw in /sys/class/drm/$(basename \"$(dirname \"$(dirname \"$busy\")\")\")/device/hwmon/hwmon*/temp1_input /sys/class/hwmon/hwmon*/temp1_input; do [ -r \"$hw\" ] || continue; v=$(cat \"$hw\" 2>/dev/null); [ \"$v\" -gt 0 ] 2>/dev/null || continue; c=$((v / 1000)); if [ \"$unit\" = f ]; then temp=\"$((c * 9 / 5 + 32))°F\"; else temp=\"${c}°C\"; fi; break; done; printf 'GPU|%s|%s' \"$pct\" \"${temp:-active}\"; exit 0; done";
        const intel = "for freq in /sys/class/drm/card*/gt_cur_freq_mhz; do [ -r \"$freq\" ] || continue; cur=$(cat \"$freq\" 2>/dev/null); maxfile=$(dirname \"$freq\")/gt_max_freq_mhz; max=$(cat \"$maxfile\" 2>/dev/null || printf 0); pct=0; if [ \"$max\" -gt 0 ] 2>/dev/null; then pct=$((cur * 100 / max)); fi; printf 'Intel GPU|%s|%sMHz' \"$pct\" \"$cur\"; exit 0; done";

        if (type === "nvidia")
            return nvidia + "; exit 0";
        if (type === "amd")
            return drm + "; exit 0";
        if (type === "intel")
            return intel + "; exit 0";
        return nvidia + "; " + drm + "; " + intel;
    }

    function gpuPercent() {
        const parts = gpuParts();
        return parts.length > 1 ? Number(parts[1]) : 0;
    }

    function workspaceOccupied(id) {
        return workspaceWindowCount(id) > 0;
    }

    function workspaceWindowCount(id) {
        const rows = workspaceStatus.value.length > 0 ? workspaceStatus.value.split("|") : [];
        for (let i = 0; i < rows.length; i++) {
            const parts = rows[i].split(":");
            if (Number(parts[0]) === id)
                return parts.length > 1 ? Number(parts[1]) : 0;
        }
        return 0;
    }

    function workspaceStatusCommand() {
        const monitor = shellQuote(screenName());
        if (workspacePerMonitorEnabled())
            return "monitor=" + monitor + "; hyprctl -j workspaces 2>/dev/null | jq -r --arg monitor \"$monitor\" '.[] | select(.id > 0 and .id <= 20 and (.monitor == $monitor or .monitorID == $monitor)) | \"\\(.id):\\(.windows // 0)\"' 2>/dev/null | paste -sd '|' -";

        return "hyprctl -j workspaces 2>/dev/null | jq -r '.[] | select(.id > 0 and .id <= 20) | \"\\(.id):\\(.windows // 0)\"' 2>/dev/null | paste -sd '|' -";
    }

    function workspaceWindowsCommand() {
        const monitor = shellQuote(screenName());
        if (workspacePerMonitorEnabled())
            return "monitor=" + monitor + "; mid=$(hyprctl -j monitors 2>/dev/null | jq -r --arg monitor \"$monitor\" '([.[] | select(.name == $monitor)][0].id // \"\")' 2>/dev/null); hyprctl -j clients 2>/dev/null | jq -c --arg mid \"${mid:-__missing__}\" '[.[] | select((.workspace.id // 0) > 0 and (.workspace.id // 0) <= 20 and ((.monitor // \"\") | tostring) == $mid) | {w:(.workspace.id // 0), c:(.class // .initialClass // \"\"), t:(.title // \"\")} ]' 2>/dev/null || printf '[]'";

        return "hyprctl -j clients 2>/dev/null | jq -c '[.[] | select((.workspace.id // 0) > 0 and (.workspace.id // 0) <= 20) | {w:(.workspace.id // 0), c:(.class // .initialClass // \"\"), t:(.title // \"\")} ]' 2>/dev/null || printf '[]'";
    }

    function workspaceWindowEntries(id) {
        if (!workspaceShowWindowsEnabled())
            return [];

        let rows = [];
        try {
            rows = JSON.parse(workspaceWindows.value.length > 0 ? workspaceWindows.value : "[]");
        } catch (error) {
            return [];
        }

        const out = [];
        const max = workspaceMaxWindowIcons();
        for (let i = 0; i < rows.length && out.length < max; i++) {
            const row = rows[i] || {};
            if (Number(row.w) !== id)
                continue;

            const icon = workspaceWindowIconSource(row.c || "", row.t || "");
            out.push({
                icon: icon,
                label: workspaceWindowFallback(row.c || "", row.t || "")
            });
        }

        return out;
    }

    function workspaceWindowIconSource(klass, title) {
        const mappedIcon = mappedWindowIconSource(klass, title);
        if (mappedIcon.length > 0)
            return mappedIcon;

        const base = `${klass || ""}`;
        const candidates = [
            base,
            base.toLowerCase(),
            base.replace(/\s+/g, "-").toLowerCase(),
            "org." + base.toLowerCase()
        ];

        for (let i = 0; i < candidates.length; i++) {
            if (candidates[i].length > 0 && Quickshell.hasThemeIcon(candidates[i]))
                return Quickshell.iconPath(candidates[i]);
        }

        return trayIconSource("application-x-executable-symbolic");
    }

    function workspaceWindowFallback(klass, title) {
        const value = `${klass || title || ""}`.trim();
        return value.length > 0 ? value[0].toUpperCase() : "•";
    }

    function specialWorkspaceName() {
        const parts = specialWorkspaceStatus.value.length > 0 ? specialWorkspaceStatus.value.split("|") : [];
        return parts.length > 0 ? parts[0] : "";
    }

    function specialWorkspaceVisible() {
        return specialWorkspaceName().length > 0;
    }

    function specialWorkspaceTarget() {
        const value = specialWorkspaceName();
        return value.indexOf("special:") === 0 ? value.slice(8) : value;
    }

    function specialWorkspaceLabel() {
        const value = specialWorkspaceTarget();
        return formatWorkspaceLabel(value.length > 0 ? value : "special");
    }

    function specialWorkspaceWindowCount() {
        const parts = specialWorkspaceStatus.value.length > 0 ? specialWorkspaceStatus.value.split("|") : [];
        if (parts.length > 1 && parts[1].length > 0)
            return Number(parts[1]);
        return 0;
    }

    function specialWorkspaceWindowSuffix() {
        const count = specialWorkspaceWindowCount();
        if (!workspaceShowWindowsOnSpecialEnabled() || count <= 0)
            return "";
        return ` ${workspaceWindowCountLabel(count)}`;
    }

    function specialWorkspaceIconSource() {
        const mappings = configValue("bar.workspaces.specialWorkspaceIcons", []);
        const target = specialWorkspaceTarget().toLowerCase();
        if (!Array.isArray(mappings) || target.length === 0)
            return "";

        for (let i = 0; i < mappings.length; i++) {
            const entry = mappings[i] || {};
            const name = `${entry.name || ""}`.toLowerCase();
            const icon = `${entry.icon || ""}`;
            if (name.length > 0 && icon.length > 0 && (name === target || target.indexOf(name) !== -1))
                return trayIconSource(icon);
        }

        return "";
    }

    function dispatchWorkspaceWheel(deltaY) {
        if (specialWorkspaceVisible()) {
            Hyprland.dispatch("togglespecialworkspace " + specialWorkspaceTarget());
            return;
        }

        Hyprland.dispatch(deltaY > 0 ? "workspace r-1" : "workspace r+1");
    }

    function handleWorkspaceWheel(deltaY) {
        if (deltaY === 0)
            return;

        const now = Date.now();
        if (now - workspaceWheelLastAt < workspaceWheelCooldownMs())
            return;

        if ((workspaceWheelAccum > 0 && deltaY < 0) || (workspaceWheelAccum < 0 && deltaY > 0))
            workspaceWheelAccum = 0;

        workspaceWheelAccum += deltaY;
        if (Math.abs(workspaceWheelAccum) < workspaceWheelThreshold())
            return;

        const direction = workspaceWheelAccum > 0 ? 1 : -1;
        const threshold = workspaceWheelThreshold();
        const steps = Math.min(workspaceWheelMaxSteps(), Math.floor(Math.abs(workspaceWheelAccum) / threshold));
        workspaceWheelAccum = direction * (Math.abs(workspaceWheelAccum) % threshold);
        workspaceWheelLastAt = now;
        for (let i = 0; i < steps; i++)
            dispatchWorkspaceWheel(direction);
    }

    function fullscreenActive() {
        return Number(activeFullscreen.value || "0") > 0;
    }

    function fullscreenQuiet() {
        return fullscreenActive() && !configBool("general.showOverFullscreen", false) && openDropdown === "";
    }

    function osId() {
        const value = osRelease.value || "";
        return value.length > 0 ? value.toLowerCase() : "linux";
    }

    function osIcon() {
        const configured = configString("general.logo", "");
        if (configured.length > 0)
            return configured;

        const id = osId();
        const map = {
            arch: "archlinux-logo",
            archlinux: "archlinux-logo",
            cachyos: "cachyos",
            endeavour: "endeavouros",
            endeavouros: "endeavouros",
            fedora: "fedora-logo-icon",
            ubuntu: "ubuntu-logo-icon",
            debian: "debian-logo",
            manjaro: "manjaro",
            opensuse: "opensuse",
            nixos: "nix-snowflake",
            garuda: "garuda"
        };

        return map[id] || "start-here-symbolic";
    }

    function osFallbackLabel() {
        const id = osId();
        if (id.indexOf("arch") !== -1)
            return "A";
        if (id.indexOf("ubuntu") !== -1)
            return "U";
        if (id.indexOf("fedora") !== -1)
            return "F";
        return "L";
    }

    function activeWindowClass() {
        if (Hyprland.activeToplevel === null)
            return "";
        const object = Hyprland.activeToplevel.lastIpcObject || {};
        return object.class || object.initialClass || "";
    }

    function activeWindowIconSource() {
        const klass = activeWindowClass();
        const mappedIcon = mappedWindowIconSource(klass, Hyprland.activeToplevel !== null ? Hyprland.activeToplevel.title : "");
        if (mappedIcon.length > 0)
            return mappedIcon;

        const candidates = [
            klass,
            klass.toLowerCase(),
            klass.replace(/\s+/g, "-").toLowerCase(),
            "org." + klass.toLowerCase()
        ];

        for (let i = 0; i < candidates.length; i++) {
            if (candidates[i].length > 0 && Quickshell.hasThemeIcon(candidates[i]))
                return Quickshell.iconPath(candidates[i]);
        }

        return trayIconSource("applications-system-symbolic");
    }

    function mappedWindowIconSource(klass, title) {
        const mappings = configValue("bar.workspaces.windowIcons", []);
        if (!Array.isArray(mappings))
            return "";

        const target = `${klass || ""} ${title || ""}`;
        for (let i = 0; i < mappings.length; i++) {
            const entry = mappings[i] || {};
            const pattern = `${entry.regex || entry.name || ""}`;
            const icon = `${entry.icon || ""}`;
            if (pattern.length === 0 || icon.length === 0)
                continue;

            try {
                if (new RegExp(pattern, "i").test(target))
                    return trayIconSource(icon);
            } catch (error) {
                if (target.toLowerCase().indexOf(pattern.toLowerCase()) !== -1)
                    return trayIconSource(icon);
            }
        }

        return "";
    }

    function vpnInstalled() {
        return vpnParts().length >= 4 && vpnParts()[0] !== "missing";
    }

    function vpnConnected() {
        const parts = vpnParts();
        return parts.length > 2 && parts[2] === "connected";
    }

    function vpnLabel() {
        const parts = vpnParts();
        if (parts.length < 4 || parts[0] === "missing")
            return "Not installed";
        return parts[3] || parts[2] || "unknown";
    }

    function vpnTitle() {
        const parts = vpnParts();
        return parts.length > 1 && parts[1].length > 0 ? parts[1] : "VPN";
    }

    function vpnParts() {
        return vpnStatus.value.length > 0 ? vpnStatus.value.split("|") : [];
    }

    function vpnCommand() {
        const parts = vpnParts();
        if (parts.length < 6)
            return "";
        return vpnConnected() ? parts[5] : parts[4];
    }

    function vpnProviderConfig() {
        const vpn = configValue("utilities.vpn", ({}));
        if (vpn && typeof vpn === "object" && vpn.enabled === false)
            return ({ enabled: false });

        const providers = vpn && typeof vpn === "object" && Array.isArray(vpn.provider) ? vpn.provider : [];
        for (let i = 0; i < providers.length; i++) {
            const provider = providers[i] || {};
            if (provider.enabled !== false)
                return provider;
        }

        return ({ name: "nordvpn", displayName: "NordVPN", enabled: true });
    }

    function vpnStatusCommand() {
        const provider = vpnProviderConfig();
        if (provider.enabled === false)
            return "printf 'missing'";

        const name = `${provider.name || "nordvpn"}`.toLowerCase();
        const display = shellQuote(`${provider.displayName || provider.name || "VPN"}`);
        if (name === "nordvpn") {
            return "if ! command -v nordvpn >/dev/null 2>&1; then printf missing; exit 0; fi; raw=$(nordvpn status 2>/dev/null); state=$(printf '%s\\n' \"$raw\" | awk -F': ' '/^Status:/ {print $2; exit}'); server=$(printf '%s\\n' \"$raw\" | awk -F': ' '/^Current server:/ {print $2; exit}'); [ -n \"$state\" ] || state=Unknown; norm=$(printf '%s' \"$state\" | tr '[:upper:]' '[:lower:]'); [ \"$norm\" = connected ] && flag=connected || flag=disconnected; detail=\"$state\"; [ -n \"$server\" ] && detail=\"$detail · $server\"; printf 'nordvpn|%s|%s|%s|nordvpn connect|nordvpn disconnect' " + display + " \"$flag\" \"$detail\"";
        }

        if (name === "wireguard" || name === "wg") {
            const iface = shellQuote(`${provider.interface || ""}`);
            return "iface=" + iface + "; [ -n \"$iface\" ] || { printf missing; exit 0; }; if ! command -v wg >/dev/null 2>&1; then printf missing; exit 0; fi; if wg show \"$iface\" >/dev/null 2>&1; then flag=connected; detail=\"connected · $iface\"; else flag=disconnected; detail=\"disconnected · $iface\"; fi; printf 'wireguard|%s|%s|%s|wg-quick up %s|wg-quick down %s' " + display + " \"$flag\" \"$detail\" \"$iface\" \"$iface\"";
        }

        const connection = shellQuote(`${provider.interface || provider.connection || provider.name || ""}`);
        return "conn=" + connection + "; [ -n \"$conn\" ] || { printf missing; exit 0; }; if ! command -v nmcli >/dev/null 2>&1; then printf missing; exit 0; fi; active=$(nmcli -t -f NAME connection show --active 2>/dev/null | grep -Fx \"$conn\" || true); if [ -n \"$active\" ]; then flag=connected; detail=\"connected · $conn\"; else flag=disconnected; detail=\"disconnected · $conn\"; fi; printf 'nmcli|%s|%s|%s|nmcli connection up %s|nmcli connection down %s' " + display + " \"$flag\" \"$detail\" \"$conn\" \"$conn\"";
    }

    function sourceMuted() {
        if (sourceMuteOverride >= 0)
            return sourceMuteOverride === 1;

        const parts = micStatus.value.split("|");
        return parts.length > 0 && parts[0] === "muted";
    }

    function sourcePercent() {
        const parts = micStatus.value.split("|");
        return parts.length > 1 ? parts[1] : "-";
    }

    function toggleSourceMute() {
        sourceMuteOverride = sourceMuted() ? 0 : 1;
        sourceMuteOverrideTimer.restart();
        showOsd("microphone", 1, 1, sourceMuteOverride === 1);
        runner.exec(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]);
    }

    function privacyParts() {
        return privacyStatus.value.length > 0 ? privacyStatus.value.split("|") : ["0", "0", "0"];
    }

    function privacyMicActive() {
        const parts = privacyParts();
        return parts.length > 0 && Number(parts[0]) > 0;
    }

    function privacyCameraActive() {
        const parts = privacyParts();
        return parts.length > 1 && Number(parts[1]) > 0;
    }

    function privacyScreenActive() {
        const parts = privacyParts();
        return parts.length > 2 && Number(parts[2]) > 0;
    }

    function privacyActive() {
        return privacyMicActive() || privacyCameraActive() || privacyScreenActive();
    }

    function privacyLabel() {
        const active = [];
        if (privacyMicActive())
            active.push("mic");
        if (privacyCameraActive())
            active.push("camera");
        if (privacyScreenActive())
            active.push("screen");
        return active.length > 0 ? active.join(", ") : "inactive";
    }

    function privacyIcon() {
        if (privacyCameraActive())
            return "camera-web-symbolic";
        if (privacyScreenActive())
            return "video-display-symbolic";
        return "microphone-sensitivity-high-symbolic";
    }

    function keyboardParts() {
        return keyboardStatus.value.length > 0 ? keyboardStatus.value.split("|") : [];
    }

    function keyboardLabel() {
        const parts = keyboardParts();
        const keymap = parts.length > 0 ? parts[0].toLowerCase() : "";
        if (keymap.indexOf("korean") !== -1 || keymap.indexOf("hangul") !== -1)
            return "한";
        if (keymap.indexOf("english") !== -1 || keymap.indexOf("us") !== -1)
            return "EN";
        return keymap.length > 0 ? keymap.slice(0, 2).toUpperCase() : "KB";
    }

    function keyboardDetail() {
        const parts = keyboardParts();
        return parts.length > 0 ? parts[0] : "Unknown";
    }

    function capsLockOn() {
        const parts = keyboardParts();
        return parts.length > 3 && parts[3] === "true";
    }

    function numLockOn() {
        const parts = keyboardParts();
        return parts.length > 4 && parts[4] === "true";
    }

    function networkParts() {
        return networkStatus.value.length > 0 ? networkStatus.value.split("|") : [];
    }

    function wifiSignal() {
        const parts = networkParts();
        if (parts.length > 2 && parts[2].length > 0)
            return Number(parts[2]);
        return -1;
    }

    function networkIcon() {
        const parts = networkParts();
        const type = parts.length > 0 ? parts[0] : "";
        if (type === "wifi") {
            const signal = wifiSignal();
            if (signal >= 80)
                return "network-wireless-signal-excellent-symbolic";
            if (signal >= 55)
                return "network-wireless-signal-good-symbolic";
            if (signal >= 30)
                return "network-wireless-signal-ok-symbolic";
            if (signal >= 1)
                return "network-wireless-signal-weak-symbolic";
            return "network-wireless-connected-symbolic";
        }
        if (type === "ethernet")
            return "network-wired-symbolic";
        return "network-offline-symbolic";
    }

    function networkLabel() {
        const parts = networkParts();
        if (parts.length < 2)
            return "offline";
        return parts[1] || parts[0] || "network";
    }

    function networkShortLabel() {
        const parts = networkParts();
        if (parts.length === 0)
            return "off";
        if (parts[0] === "wifi") {
            const signal = wifiSignal();
            return signal >= 0 ? `${signal}%` : "wifi";
        }
        if (parts[0] === "ethernet")
            return "eth";
        return parts[0] || "net";
    }

    function networkOffline() {
        return networkParts().length === 0;
    }

    function networkStatusVisible() {
        const parts = networkParts();
        if (parts.length > 0 && parts[0] === "wifi")
            return statusEnabled("wifi");
        if (parts.length > 0)
            return statusEnabled("network");
        if (!statusEnabled("network") && !statusEnabled("wifi"))
            return false;
        return true;
    }

    function networkSignalLabel() {
        const signal = wifiSignal();
        return signal >= 0 ? `${signal}%` : "-";
    }

    function nexusEnabled() {
        return configBool("nexus.enabled", true);
    }

    function nexusNetworkRescanInterval() {
        return Math.round(configNumber("nexus.networkRescanInterval", 120000, 15000, 1800000));
    }

    function nexusNetworkRows() {
        return rows(nexusWifiNetworks.value);
    }

    function wifiRadioAvailable() {
        return wifiRadioStatus.value.length > 0 && wifiRadioStatus.value !== "missing";
    }

    function wifiRadioEnabled() {
        return wifiRadioStatus.value === "enabled";
    }

    function toggleWifiRadio() {
        runner.exec(["sh", "-c", wifiRadioEnabled() ? "nmcli radio wifi off" : "nmcli radio wifi on"]);
    }

    function bluetoothLabel() {
        const parts = bluetoothParts();
        if (parts.length === 0 || parts[0] === "missing")
            return "not available";
        if (parts[0] === "off")
            return "off";
        if (parts[0] === "connected")
            return `${bluetoothConnectedCount()} connected`;
        return "ready";
    }

    function bluetoothParts() {
        return bluetoothStatus.value.length > 0 ? bluetoothStatus.value.split("|") : [];
    }

    function bluetoothAvailable() {
        const parts = bluetoothParts();
        return parts.length > 0 && parts[0] !== "missing";
    }

    function bluetoothEnabled() {
        const parts = bluetoothParts();
        return bluetoothAvailable() && parts[0] !== "off";
    }

    function bluetoothConnectedCount() {
        const parts = bluetoothParts();
        if (parts.length > 1 && parts[1].length > 0)
            return Number(parts[1]);
        return 0;
    }

    function bluetoothIcon() {
        if (!bluetoothEnabled())
            return "bluetooth-disabled-symbolic";
        if (bluetoothConnectedCount() > 0)
            return "bluetooth-active-symbolic";
        return "bluetooth-symbolic";
    }

    function weatherParts() {
        return weatherStatus.value.length > 0 ? weatherStatus.value.split("|") : [];
    }

    function weatherAvailable() {
        return weatherParts().length > 1;
    }

    function weatherIcon() {
        const summary = weatherParts().length > 0 ? weatherParts()[0].toLowerCase() : "";
        if (summary.indexOf("rain") !== -1 || summary.indexOf("shower") !== -1)
            return "weather-showers-symbolic";
        if (summary.indexOf("cloud") !== -1 || summary.indexOf("overcast") !== -1)
            return "weather-overcast-symbolic";
        if (summary.indexOf("fog") !== -1 || summary.indexOf("mist") !== -1)
            return "weather-fog-symbolic";
        return "weather-clear-symbolic";
    }

    function weatherLabel() {
        const parts = weatherParts();
        return parts.length > 1 ? parts[1] : "";
    }

    function weatherDetail() {
        const parts = weatherParts();
        if (parts.length < 3)
            return "Set services.weatherLocation";
        return `${parts[2]} · ${parts[0]}`;
    }

    function weatherStatusCommand() {
        const configured = configString("services.weatherLocation", "");
        const unit = configBool("services.useFahrenheit", false) ? "u" : "m";
        if (configured.length > 0) {
            const loc = shellQuote(configured);
            return "loc=" + loc + "; loc=$(printf '%s' \"$loc\" | sed 's/[[:space:]]*$//' | sed 's/ /%20/g'); [ -n \"$loc\" ] || exit 0; out=$(curl -fsS --max-time 5 \"https://wttr.in/${loc}?" + unit + "&format=%C|%t|%l\" 2>/dev/null || true); printf '%s' \"$out\"";
        }

        return "loc_file=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/weather-location\"; [ -r \"$loc_file\" ] || exit 0; loc=$(head -n1 \"$loc_file\" | sed 's/[[:space:]]*$//' | sed 's/ /%20/g'); [ -n \"$loc\" ] || exit 0; out=$(curl -fsS --max-time 5 \"https://wttr.in/${loc}?" + unit + "&format=%C|%t|%l\" 2>/dev/null || true); printf '%s' \"$out\"";
    }

    function wallpaperParts() {
        return wallpaperStatus.value.length > 0 ? wallpaperStatus.value.split("|") : [];
    }

    function wallpaperAvailable() {
        const parts = wallpaperParts();
        return parts.length > 2 && Number(parts[1]) > 0;
    }

    function wallpaperDetail() {
        const parts = wallpaperParts();
        if (parts.length < 3)
            return configString("paths.wallpaperDir", "~/Pictures/Wallpapers");
        const path = parts[2];
        const name = path.split("/").pop();
        return `${parts[0]} · ${parts[1]} images · ${name}`;
    }

    function wallpaperDirShell() {
        const path = configString("paths.wallpaperDir", "~/Pictures/Wallpapers");
        return "dir=" + shellQuote(path) + "; if [ \"$dir\" = \"~\" ]; then dir=\"$HOME\"; elif [ \"${dir#~/}\" != \"$dir\" ]; then dir=\"$HOME/${dir#~/}\"; fi; ";
    }

    function wallpaperFindShell() {
        return wallpaperDirShell() + "[ -d \"$dir\" ] || exit 0; find \"$dir\" -maxdepth 1 -type f | grep -Ei '\\.(jpg|jpeg|png|webp)$'";
    }

    function smartSchemeCommand(fileExpression) {
        const value = configValue("services.smartScheme", false);
        if (value === false || value === "false" || value === "off" || value === "none" || value === "")
            return "";

        if (value && typeof value === "object") {
            if (value.enabled === false)
                return "";
            const command = commandFromValue(value.command);
            if (command.length > 0)
                return "SMART_WALLPAPER=" + fileExpression + " " + command;

            const scheme = `${value.colorScheme || value.scheme || ""}`;
            const mode = `${value.mode || ""}`;
            if (scheme.length > 0 && mode.length > 0)
                return "cd \"$HOME/dotfiles\" && ./apply-theme.sh --colorScheme " + shellQuote(scheme) + " --mode " + shellQuote(mode);
            if (scheme.length > 0)
                return "cd \"$HOME/dotfiles\" && ./apply-theme.sh --colorScheme " + shellQuote(scheme);
            if (mode === "light" || mode === "dark")
                return "cd \"$HOME/dotfiles\" && ./apply-theme.sh --mode " + shellQuote(mode);
        }

        const text = `${value}`.toLowerCase();
        if (text === "light" || text === "dark")
            return "cd \"$HOME/dotfiles\" && ./apply-theme.sh --mode " + shellQuote(text);
        if (text !== "true" && text !== "auto" && text !== "dynamic")
            return "cd \"$HOME/dotfiles\" && ./apply-theme.sh --colorScheme " + shellQuote(text);

        return "if command -v magick >/dev/null 2>&1; then lum=$(magick " + fileExpression + " -resize 1x1! -colorspace Gray -format '%[fx:int(255*u)]' info: 2>/dev/null || printf 0); mode=dark; [ \"${lum:-0}\" -gt 150 ] 2>/dev/null && mode=light; cd \"$HOME/dotfiles\" && ./apply-theme.sh --mode \"$mode\"; fi";
    }

    function wallpaperCommand() {
        const pick = "file=$(" + wallpaperFindShell() + " | shuf -n 1); [ -n \"$file\" ] || exit 0; ";
        const tool = wallpaperParts().length > 0 ? wallpaperParts()[0] : "";
        if (tool === "swww")
            return pick + "swww img \"$file\"; " + smartSchemeCommand("$file");
        if (tool === "hyprpaper")
            return pick + "hyprctl hyprpaper preload \"$file\"; hyprctl hyprpaper wallpaper \",$file\"; " + smartSchemeCommand("$file");
        return "";
    }

    function rows(value) {
        return value.length > 0 ? value.split("\n").filter(row => row.length > 0) : [];
    }

    function rowPart(row, index) {
        const parts = row.split("|");
        return parts.length > index ? parts[index] : "";
    }

    function themedIcon(icon) {
        return trayIconSource(icon);
    }

    function trayIconSource(icon) {
        if (!icon || icon.length === 0)
            return "";

        if (icon[0] === "/")
            return "file://" + icon;

        if (icon === "input-keyboard-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/devices/input-keyboard-symbolic.svg";
        if (icon === "audio-volume-high-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/audio-volume-high-symbolic.svg";
        if (icon === "network-wired-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/devices/network-wired-symbolic.svg";
        if (icon === "network-wireless-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-wireless-signal-good-symbolic.svg";
        if (icon === "network-wireless-signal-excellent-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-wireless-signal-excellent-symbolic.svg";
        if (icon === "network-wireless-signal-good-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-wireless-signal-good-symbolic.svg";
        if (icon === "network-wireless-signal-ok-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-wireless-signal-ok-symbolic.svg";
        if (icon === "network-wireless-signal-weak-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-wireless-signal-weak-symbolic.svg";
        if (icon === "network-wireless-connected-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-wireless-connected-symbolic.svg";
        if (icon === "network-offline-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-offline-symbolic.svg";
        if (icon === "bluetooth-active-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/bluetooth-active-symbolic.svg";
        if (icon === "bluetooth-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/bluetooth-active-symbolic.svg";
        if (icon === "bluetooth-disabled-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/bluetooth-disabled-symbolic.svg";
        if (icon === "microphone-sensitivity-high-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/microphone-sensitivity-high-symbolic.svg";
        if (icon === "microphone-disabled-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/microphone-disabled-symbolic.svg";
        if (icon === "system-lock-screen-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/system-lock-screen-symbolic.svg";
        if (icon === "system-log-out-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/system-log-out-symbolic.svg";
        if (icon === "system-reboot-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/system-reboot-symbolic.svg";
        if (icon === "system-shutdown-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/system-shutdown-symbolic.svg";
        if (icon === "media-playback-pause-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/media-playback-pause-symbolic.svg";
        if (icon === "media-playback-start-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/media-playback-start-symbolic.svg";
        if (icon === "media-skip-backward-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/media-skip-backward-symbolic.svg";
        if (icon === "media-skip-forward-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/media-skip-forward-symbolic.svg";
        if (icon === "media-playlist-shuffle-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/media-playlist-shuffle-symbolic.svg";
        if (icon === "media-playlist-repeat-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/media-playlist-repeat-symbolic.svg";
        if (icon === "audio-volume-muted-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/audio-volume-muted-symbolic.svg";
        if (icon === "display-brightness-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/display-brightness-symbolic.svg";
        if (icon === "preferences-system-notifications-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/legacy/preferences-system-notifications-symbolic.svg";
        if (icon === "preferences-system-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/categories/preferences-system-symbolic.svg";
        if (icon === "camera-photo-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/devices/camera-photo-symbolic.svg";
        if (icon === "edit-paste-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/edit-paste-symbolic.svg";
        if (icon === "system-file-manager-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/legacy/system-file-manager-symbolic.svg";
        if (icon === "preferences-desktop-wallpaper-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/legacy/preferences-desktop-wallpaper-symbolic.svg";
        if (icon === "camera-web-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/devices/camera-web-symbolic.svg";
        if (icon === "video-display-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/devices/video-display-symbolic.svg";
        if (icon === "notifications-disabled-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/notifications-disabled-symbolic.svg";
        if (icon === "software-update-available-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/software-update-available-symbolic.svg";
        if (icon === "weather-clear-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/weather-clear-symbolic.svg";
        if (icon === "weather-overcast-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/weather-overcast-symbolic.svg";
        if (icon === "weather-showers-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/weather-showers-symbolic.svg";
        if (icon === "weather-fog-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/weather-fog-symbolic.svg";
        if (icon === "alarm-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/alarm-symbolic.svg";
        if (icon === "night-light-disabled-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/night-light-disabled-symbolic.svg";
        if (icon === "window-close-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/ui/window-close-symbolic.svg";
        if (icon === "view-fullscreen-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/view-fullscreen-symbolic.svg";
        if (icon === "window-restore-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/ui/window-restore-symbolic.svg";
        if (icon === "view-pin-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/actions/view-pin-symbolic.svg";
        if (icon === "network-vpn-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/network-vpn-symbolic.svg";
        if (icon === "applications-system-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg";
        if (icon === "application-x-executable-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/mimetypes/application-x-executable-symbolic.svg";
        if (icon === "avatar-default-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/avatar-default-symbolic.svg";
        if (icon === "power-profile-balanced-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/power-profile-balanced-symbolic.svg";
        if (icon === "power-profile-power-saver-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/power-profile-power-saver-symbolic.svg";
        if (icon === "power-profile-performance-symbolic")
            return "file:///usr/share/icons/Adwaita/symbolic/status/power-profile-performance-symbolic.svg";

        if (Quickshell.hasThemeIcon(icon))
            return Quickshell.iconPath(icon);

        return "";
    }

    function trayItemIconSource(item) {
        if (!item)
            return "";

        const candidates = trayItemCandidates(item);
        const substituted = trayIconSubstitution(candidates);
        if (substituted.length > 0)
            return substituted;

        if (trayItemIsInputMethod(item))
            return "";

        const icon = `${item.icon || ""}`;
        if (icon.length === 0)
            return trayIconSource("application-x-executable-symbolic");

        if (icon[0] === "/")
            return "file://" + icon;

        return icon;
    }

    function trayItemLabel(item) {
        if (trayItemIsInputMethod(item))
            return trayInputMethodLabel(item);
        return "";
    }

    function trayInputMethodLabel(item) {
        const label = keyboardLabel();
        if (label !== "KB")
            return label;

        const icon = `${item && item.icon ? item.icon : ""}`.toLowerCase();
        const tooltip = `${item && item.tooltipTitle ? item.tooltipTitle : ""} ${item && item.tooltipDescription ? item.tooltipDescription : ""}`.toLowerCase();
        if (icon.indexOf("hangul") !== -1 || tooltip.indexOf("hangul") !== -1 || tooltip.indexOf("korean") !== -1)
            return "한";
        if (icon.indexOf("keyboard") !== -1 || tooltip.indexOf("english") !== -1 || tooltip.indexOf("us") !== -1)
            return "EN";
        return "KB";
    }

    function trayItemIsInputMethod(item) {
        if (!item)
            return false;

        const candidates = trayItemCandidates(item);
        for (let i = 0; i < candidates.length; i++) {
            const value = candidates[i];
            if (value.indexOf("fcitx") !== -1 || value.indexOf("input method") !== -1)
                return true;
        }
        return false;
    }

    function trayIconSubstitution(candidates) {
        const iconSubs = configValue("bar.tray.iconSubs", ({}));
        if (Array.isArray(iconSubs)) {
            for (let i = 0; i < iconSubs.length; i++) {
                const entry = iconSubs[i] || {};
                const key = `${entry.from || entry.match || entry.name || entry.id || ""}`.toLowerCase();
                const icon = `${entry.to || entry.icon || ""}`;
                for (let j = 0; j < candidates.length; j++) {
                    const candidate = candidates[j];
                    if (key.length > 0 && icon.length > 0 && candidate.length > 0 && (key === candidate || candidate.indexOf(key) !== -1))
                        return trayIconSource(icon);
                }
            }
        } else if (iconSubs && typeof iconSubs === "object") {
            const keys = Object.keys(iconSubs);
            for (let i = 0; i < keys.length; i++) {
                const key = `${keys[i]}`.toLowerCase();
                for (let j = 0; j < candidates.length; j++) {
                    const candidate = candidates[j];
                    if (key.length > 0 && candidate.length > 0 && (key === candidate || candidate.indexOf(key) !== -1))
                        return trayIconSource(`${iconSubs[keys[i]]}`);
                }
            }
        }

        return "";
    }

    function trayItemCandidates(item) {
        if (!item)
            return [];

        const values = [
            item.id || "",
            item.title || "",
            item.icon || "",
            item.tooltipTitle || "",
            item.tooltipDescription || ""
        ];
        const out = [];
        for (let i = 0; i < values.length; i++) {
            const value = `${values[i]}`.toLowerCase();
            if (value.length > 0 && out.indexOf(value) === -1)
                out.push(value);
        }
        return out;
    }

    function trayItemVisible(item) {
        return !stringListContainsLower(stringListValue("bar.tray.hiddenIcons"), trayItemCandidates(item));
    }

    function trayPreferNativeMenu() {
        return configBool("bar.tray.preferNativeMenu", false);
    }

    function trayNativeMenuFallbackEnabled() {
        return configBool("bar.tray.nativeMenuFallback", true);
    }

    function trayNativeSubmenuFallbackEnabled() {
        return configBool("bar.tray.nativeSubmenuFallback", false);
    }

    function visibleTrayItemCount() {
        let count = 0;
        const items = SystemTray.items.values;
        for (let i = 0; i < items.length; i++) {
            if (trayItemVisible(items[i]))
                count++;
        }
        return count;
    }

    function trayFallback(item) {
        const title = item && item.title ? item.title : item && item.id ? item.id : "";
        return title.length > 0 ? title[0].toUpperCase() : "T";
    }

    function openTrayMenu(item, x) {
        if (!item)
            return;

        if (trayPreferNativeMenu()) {
            displayNativeTrayMenu(item, x);
            return;
        }

        activeTrayItem = item;
        pendingNativeTrayTarget = item;
        pendingNativeTrayX = x;
        trayMenuParents = [];
        trayMenuTitles = [];
        activeTraySubmenu = null;
        traySubmenuModel.menu = null;
        trayDropdownX = x;
        trayMenuModel.menu = item.menu;
        if (item.menu && item.menu.sendOpened)
            item.menu.sendOpened();
        openDropdown = "tray";
        if (trayNativeMenuFallbackEnabled())
            trayNativeFallbackTimer.restart();
    }

    function openTraySubmenu(entry) {
        if (!entry)
            return;

        if (entry.updateLayout)
            entry.updateLayout();

        if (!entry.hasChildren && (!entry.children || entry.children.length === 0)) {
            if (trayNativeSubmenuFallbackEnabled()) {
                pendingNativeTrayTarget = entry;
                pendingNativeTrayX = trayDropdownX + dropdownWidth() - 8;
                displayNativeTrayMenu(entry, pendingNativeTrayX);
            }
            return;
        }

        const currentMenu = activeTraySubmenu || trayMenuModel.menu;
        trayMenuParents = trayMenuParents.concat([currentMenu]);
        trayMenuTitles = trayMenuTitles.concat([entry.text || "Menu"]);
        pendingNativeTrayTarget = entry;
        pendingNativeTrayX = trayDropdownX + dropdownWidth() - 8;
        activeTraySubmenu = entry;
        traySubmenuModel.menu = entry;
        if (entry.sendOpened)
            entry.sendOpened();
        if (entry.updateLayout)
            entry.updateLayout();
    }

    function triggerTrayEntry(entry) {
        if (!entry)
            return;
        if (entry.sendTriggered)
            entry.sendTriggered();
        else if (entry.triggered)
            entry.triggered();
    }

    function trayMenuBack() {
        if (trayMenuParents.length === 0)
            return;

        if (activeTraySubmenu && activeTraySubmenu.sendClosed)
            activeTraySubmenu.sendClosed();

        const nextParents = trayMenuParents.slice(0, trayMenuParents.length - 1);
        const nextTitles = trayMenuTitles.slice(0, trayMenuTitles.length - 1);
        const previous = trayMenuParents[trayMenuParents.length - 1];
        if (nextParents.length === 0) {
            activeTraySubmenu = null;
            traySubmenuModel.menu = null;
            trayMenuModel.menu = previous;
        } else {
            activeTraySubmenu = previous;
            traySubmenuModel.menu = previous;
        }
        trayMenuParents = nextParents;
        trayMenuTitles = nextTitles;
    }

    function trayMenuTitle() {
        if (trayMenuTitles.length > 0)
            return trayMenuTitles[trayMenuTitles.length - 1];
        return activeTrayItem ? activeTrayItem.title || activeTrayItem.id : "Tray";
    }

    function trayMenuChildCount() {
        const model = activeTraySubmenu !== null ? traySubmenuModel : trayMenuModel;
        if (!model.children)
            return 0;
        if (model.children.values)
            return model.children.values.length;
        return model.children.length || 0;
    }

    function displayNativeTrayMenu(target, x) {
        if (!target || !target.display)
            return false;

        const localX = Math.max(0, Math.round(x));
        target.display(topBar, localX, topBar.height + 6);
        return true;
    }

    function maybeFallbackToNativeTrayMenu() {
        if (!trayNativeMenuFallbackEnabled() || openDropdown !== "tray" || trayMenuChildCount() > 0)
            return;
        if (trayMenuParents.length > 0 && !trayNativeSubmenuFallbackEnabled())
            return;

        const target = pendingNativeTrayTarget || activeTrayItem;
        if (displayNativeTrayMenu(target, pendingNativeTrayX))
            closeDropdown();
    }

    function handleTrayItemClick(item, button, x) {
        closeDropdown();
        if (!item)
            return;

        if (button === Qt.MiddleButton && item.secondaryActivate) {
            item.secondaryActivate();
            return;
        }

        if (item.hasMenu && popoutEnabled("tray")) {
            openTrayMenu(item, x);
        } else if (item.activate) {
            item.activate();
        }
    }

    Process {
        id: runner
    }

    Timer {
        id: volumeOverrideTimer
        interval: 2500
        repeat: false
        onTriggered: bar.volumeOverride = -1
    }

    Timer {
        id: muteOverrideTimer
        interval: 1200
        repeat: false
        onTriggered: bar.muteOverride = -1
    }

    Timer {
        id: sourceMuteOverrideTimer
        interval: 1200
        repeat: false
        onTriggered: bar.sourceMuteOverride = -1
    }

    Timer {
        id: brightnessOverrideTimer
        interval: 1500
        repeat: false
        onTriggered: bar.brightnessOverride = -1
    }

    Timer {
        id: osdTimer
        interval: bar.osdHideDelay()
        repeat: false
        onTriggered: bar.osdVisible = false
    }

    PollText {
        id: cpu
        interval: bar.resourcePollInterval()
        command: ["sh", "-c", "awk '{printf \"load %.2f\", $1}' /proc/loadavg 2>/dev/null || true"]
    }

    PollText {
        id: cpuPercent
        interval: bar.resourcePollInterval()
        command: ["sh", "-c", bar.sharedCpuPercentCommand()]
    }

    PollText {
        id: memory
        interval: bar.resourcePollInterval()
        command: ["sh", "-c", "free 2>/dev/null | awk '/Mem:/ {printf \"%d%%\", $3 / $2 * 100}' || true"]
    }

    PollText {
        id: userName
        interval: 60000
        command: ["sh", "-c", "name=$(getent passwd \"$USER\" 2>/dev/null | cut -d: -f5 | cut -d, -f1 | sed 's/[[:space:]]*$//'); [ -n \"$name\" ] && printf '%s' \"$name\" || printf '%s' \"${USER:-user}\""]
    }

    PollText {
        id: profileImage
        interval: 5000
        command: ["sh", "-c", "[ -r \"$HOME/.face\" ] && printf '%s' \"$HOME/.face\""]
    }

    PollText {
        id: profileImageCandidates
        interval: bar.openDropdown === "profileimage" ? 5000 : 60000
        command: ["sh", "-c", "nonce=" + bar.profileImageRefreshNonce + "; for dir in \"$HOME/Pictures\" \"$HOME/Downloads\" \"$HOME\"; do [ -d \"$dir\" ] || continue; find \"$dir\" -maxdepth 2 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null; done | awk '!seen[$0]++' | head -80"]
    }

    PollText {
        id: uptime
        interval: 60000
        command: ["sh", "-c", "uptime -p 2>/dev/null | sed 's/^up //' || true"]
    }

    PollText {
        id: temperature
        interval: bar.statusPollInterval()
        command: ["sh", "-c", bar.temperatureStatusCommand()]
    }

    PollText {
        id: gpuStatus
        interval: bar.statusPollInterval()
        command: ["sh", "-c", bar.gpuStatusCommand()]
    }

    PollText {
        id: storage
        interval: bar.slowResourcePollInterval()
        command: ["sh", "-c", "df -h \"$HOME\" 2>/dev/null | awk 'NR==2 {printf \"%s / %s|%s\", $3, $2, $5}' || true"]
    }

    PollText {
        id: networkTraffic
        interval: bar.resourcePollInterval()
        command: ["sh", "-c", "state=\"/tmp/dotfiles-net-${USER:-user}\"; now=$(date +%s); set -- $(awk -F'[: ]+' '$2!=\"lo\" {rx+=$3; tx+=$11} END {print rx+0, tx+0}' /proc/net/dev 2>/dev/null); rx=${1:-0}; tx=${2:-0}; out='↓ 0KB/s ↑ 0KB/s'; if read prx ptx pts < \"$state\" 2>/dev/null; then dt=$((now - pts)); if [ \"$dt\" -gt 0 ] 2>/dev/null; then dr=$(((rx - prx) / dt / 1024)); dtb=$(((tx - ptx) / dt / 1024)); out=\"↓ ${dr}KB/s ↑ ${dtb}KB/s\"; fi; fi; printf '%s %s %s\\n' \"$rx\" \"$tx\" \"$now\" > \"$state\"; printf '%s' \"$out\""]
    }

    PollText {
        id: workspaceStatus
        interval: 2000
        command: ["sh", "-c", bar.workspaceStatusCommand()]
    }

    PollText {
        id: workspaceWindows
        interval: 2000
        command: ["sh", "-c", bar.workspaceWindowsCommand()]
    }

    PollText {
        id: specialWorkspaceStatus
        interval: 1000
        command: ["sh", "-c", "name=$(hyprctl monitors -j 2>/dev/null | jq -r '([.[] | select(.focused == true)][0].specialWorkspace.name // \"\")' 2>/dev/null); [ -n \"$name\" ] || exit 0; windows=$(hyprctl workspaces -j 2>/dev/null | jq -r --arg name \"$name\" '([.[] | select(.name == $name)][0].windows // 0)' 2>/dev/null); printf '%s|%s' \"$name\" \"${windows:-0}\""]
    }

    PollText {
        id: activeFullscreen
        interval: bar.fastStatusPollInterval()
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | jq -r '.fullscreen // 0' 2>/dev/null"]
    }

    PollText {
        id: backlight
        interval: bar.statusPollInterval()
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] || continue; b=$(cat \"$d/brightness\"); m=$(cat \"$d/max_brightness\"); [ \"$m\" -gt 0 ] 2>/dev/null || continue; printf '%d%%' $((b * 100 / m)); exit; done"]
    }

    PollText {
        id: volumeStatus
        interval: bar.fastStatusPollInterval()
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ muted=($3==\"[MUTED]\") ? \"muted\" : \"live\"; printf \"%s|%d\", muted, $2 * 100 }'"]
    }

    PollText {
        id: soundTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", bar.configuredAppDetectCommand("audio", ["pavucontrol", "pwvucontrol"])]
    }

    PollText {
        id: networkTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", bar.configuredAppDetectCommand("network", ["nm-connection-editor", bar.terminalCommand("nmtui")])]
    }

    PollText {
        id: bluetoothTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", "if command -v blueman-manager >/dev/null 2>&1; then printf blueman-manager; fi"]
    }

    PollText {
        id: settingsTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", bar.configuredAppDetectCommand("settings", ["gnome-control-center", "systemsettings"])]
    }

    PollText {
        id: explorerTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", bar.configuredAppDetectCommand("explorer", ["nautilus", "thunar", "dolphin"])]
    }

    PollText {
        id: playbackTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", bar.configuredAppDetectCommand("playback", ["spotify", "youtube-music", "mpv", "vlc", "elisa"])]
    }

    PollText {
        id: clipboardTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", "if command -v cliphist >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then printf cliphist; fi"]
    }

    PollText {
        id: clipboardHistory
        interval: bar.openDropdown === "clipboard" ? 1200 : 10000
        command: ["sh", "-c", "nonce=" + bar.clipboardRefreshNonce + "; if command -v cliphist >/dev/null 2>&1; then cliphist list | head -40; fi"]
    }

    PollText {
        id: recordingTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", "if command -v wf-recorder >/dev/null 2>&1; then printf wf-recorder; fi"]
    }

    PollText {
        id: recordingRegionTool
        interval: bar.toolPollInterval()
        command: ["sh", "-c", "if command -v slurp >/dev/null 2>&1; then printf slurp; fi"]
    }

    PollText {
        id: recordingStatus
        interval: 1000
        command: ["sh", "-c", "if pgrep -x wf-recorder >/dev/null 2>&1; then printf active; else printf inactive; fi"]
    }

    PollText {
        id: batteryInfo
        interval: bar.toolPollInterval()
        command: ["sh", "-c", "if ! command -v upower >/dev/null 2>&1; then exit 0; fi; bat=$(upower -e 2>/dev/null | grep -m1 'BAT'); [ -n \"$bat\" ] || exit 0; upower -i \"$bat\" 2>/dev/null | awk -F': *' '/state:/ {state=$2} /time to empty:/ {time=$2} /time to full:/ {time=$2} END {printf \"%s|%s\", state, time}'"]
    }

    PollText {
        id: batteryWarning
        interval: 60000
        command: ["sh", "-c", bar.batteryWarningCommand()]
    }

    PollText {
        id: mediaLyrics
        interval: bar.mediaPollInterval()
        command: ["sh", "-c", bar.lyricsLookupCommand()]
    }

    PollText {
        id: micStatus
        interval: bar.resourcePollInterval()
        command: ["sh", "-c", "mute=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}'); vol=$(pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | awk -F/ 'NR==1 {gsub(/ /,\"\",$2); print $2}'); [ \"$mute\" = yes ] && printf muted || printf live; printf '|%s' \"${vol:--}\""]
    }

    PollText {
        id: privacyStatus
        interval: bar.resourcePollInterval()
        command: ["sh", "-c", "mic=$(pactl list source-outputs short 2>/dev/null | wc -l); cam=0; for dev in /dev/video*; do [ -e \"$dev\" ] || continue; if fuser \"$dev\" >/dev/null 2>&1; then cam=1; break; fi; done; screen=0; if pgrep -x wf-recorder >/dev/null 2>&1 || pgrep -x obs >/dev/null 2>&1 || pgrep -x kooha >/dev/null 2>&1 || pgrep -x gpu-screen-recorder >/dev/null 2>&1 || pgrep -x simplescreenrecorder >/dev/null 2>&1; then screen=1; fi; printf '%s|%s|%s' \"$mic\" \"$cam\" \"$screen\""]
    }

    PollText {
        id: keyboardStatus
        interval: 500
        command: ["sh", "-c", "sh \"$HOME/.config/quickshell/scripts/keyboard-status.sh\""]
    }

    PollText {
        id: networkStatus
        interval: bar.statusPollInterval()
        command: ["sh", "-c", "if ! command -v nmcli >/dev/null 2>&1; then exit 0; fi; row=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\" && $1==\"wifi\" {print $1\"|\"$3; exit}'); if [ -n \"$row\" ]; then sig=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\" {print $2; exit}'); printf '%s|%s' \"$row\" \"${sig:-0}\"; exit 0; fi; nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\" && $1==\"ethernet\" {print $1\"|\"$3\"|\"; exit}'"]
    }

    PollText {
        id: wifiRadioStatus
        interval: bar.statusPollInterval()
        command: ["sh", "-c", "if ! command -v nmcli >/dev/null 2>&1; then printf missing; exit 0; fi; nmcli radio wifi 2>/dev/null | awk '{print $1}'"]
    }

    PollText {
        id: weatherStatus
        interval: bar.weatherPollInterval()
        command: ["sh", "-c", bar.weatherStatusCommand()]
    }

    PollText {
        id: wallpaperStatus
        interval: bar.toolPollInterval()
        command: ["sh", "-c", "tool=; if command -v swww >/dev/null 2>&1; then tool=swww; elif command -v hyprctl >/dev/null 2>&1 && pgrep -x hyprpaper >/dev/null 2>&1; then tool=hyprpaper; fi; [ -n \"$tool\" ] || exit 0; files=$(" + bar.wallpaperFindShell() + "); [ -n \"$files\" ] || exit 0; count=$(printf '%s\\n' \"$files\" | wc -l); sample=$(printf '%s\\n' \"$files\" | shuf -n 1); printf '%s|%s|%s' \"$tool\" \"$count\" \"$sample\""]
    }

    PollText {
        id: networkConnections
        interval: bar.slowResourcePollInterval()
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\" {print $1\"|\"$2}' | head -8"]
    }

    PollText {
        id: nexusWifiNetworks
        interval: bar.nexusNetworkRescanInterval()
        command: ["sh", "-c", "if ! command -v nmcli >/dev/null 2>&1; then exit 0; fi; nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | awk -F: 'length($2)>0 {print $2\"|\"$3\"|\"$4\"|\"$1}' | head -10"]
    }

    PollText {
        id: bluetoothStatus
        interval: bar.statusPollInterval()
        command: ["sh", "-c", "if ! command -v bluetoothctl >/dev/null 2>&1 || ! bluetoothctl show >/dev/null 2>&1; then printf 'missing|0'; exit 0; fi; powered=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}'); c=$(bluetoothctl devices Connected 2>/dev/null | wc -l); if [ \"$powered\" != yes ]; then printf 'off|%s' \"$c\"; elif [ \"$c\" -gt 0 ]; then printf 'connected|%s' \"$c\"; else printf 'ready|0'; fi"]
    }

    PollText {
        id: bluetoothDevices
        interval: bar.slowResourcePollInterval()
        command: ["sh", "-c", "bluetoothctl devices Paired 2>/dev/null | sed -E 's/^Device ([^ ]+) (.*)$/\\1|\\2/' | head -8"]
    }

    PollText {
        id: dndStatus
        interval: 1000
        command: ["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-dnd.enabled\"; [ \"$(cat \"$state\" 2>/dev/null)\" = true ] && printf true || printf false"]
    }

    PollText {
        id: notificationCount
        interval: 1000
        command: ["sh", "-c", "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-notification-count\" 2>/dev/null || printf 0"]
    }

    PollText {
        id: idleInhibitStatus
        interval: 1000
        command: ["sh", "-c", "nonce=" + bar.idleInhibitRefreshNonce + "; if command -v qs-idle-inhibit >/dev/null 2>&1; then qs-idle-inhibit status; elif [ -x \"$HOME/.local/bin/qs-idle-inhibit\" ]; then \"$HOME/.local/bin/qs-idle-inhibit\" status; else printf missing; fi"]
    }

    PollText {
        id: idleSettings
        interval: bar.openDropdown === "idlesettings" ? 1000 : 10000
        command: ["sh", "-c", "nonce=" + bar.idleSettingsRefreshNonce + "; if command -v hypr-idle-settings >/dev/null 2>&1; then hypr-idle-settings get; elif [ -x \"$HOME/.local/bin/hypr-idle-settings\" ]; then \"$HOME/.local/bin/hypr-idle-settings\" get; fi"]
    }

    PollText {
        id: gameModeStatus
        interval: 1000
        command: ["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-game-mode.enabled\"; [ \"$(cat \"$state\" 2>/dev/null)\" = true ] && printf true || printf false"]
    }

    PollText {
        id: updateStatus
        interval: bar.updatePollInterval()
        command: ["sh", "-c", bar.sharedUpdateStatusCommand()]
    }

    PollText {
        id: vpnStatus
        interval: bar.statusPollInterval()
        command: ["sh", "-c", bar.vpnStatusCommand()]
    }

    PollText {
        id: osRelease
        interval: 60000
        command: ["sh", "-c", ". /etc/os-release 2>/dev/null; printf '%s' \"${ID:-linux}\""]
    }

    PollText {
        id: shellConfig
        interval: bar.configPollInterval()
        command: ["sh", "-c", "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/quickshell.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
    }

    PollText {
        id: monitorConfig
        interval: bar.configPollInterval()
        command: ["sh", "-c", "name=" + bar.shellQuote(bar.screenName()) + "; [ -n \"$name\" ] || exit 0; cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/monitors/$name/quickshell.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
    }

    PanelWindow {
        id: revealZone

        screen: bar.modelData
        visible: bar.screenBarEnabled() && !bar.barPersistent() && bar.barShowOnHover()
        implicitHeight: bar.barRevealHeight()
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
        }

        HoverHandler {
            onHoveredChanged: bar.revealHover = hovered
        }
    }

    PanelWindow {
        id: topBar

        screen: bar.modelData
        visible: bar.topBarVisible()
        implicitHeight: bar.barHeight()
        color: "transparent"
        exclusiveZone: visible && bar.barPersistent() ? bar.barHeight() : 0
        exclusionMode: ExclusionMode.Normal

        anchors {
            top: true
            left: true
            right: true
        }

        Item {
            anchors.fill: parent

            HoverHandler {
                onHoveredChanged: bar.topBarHover = hovered
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: bar.appearancePadding(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: bar.appearanceSpacing(8)

                IconButton {
                    width: 34
                    height: 34
                    visible: bar.barEntryEnabled("logo")
                    icon: bar.osIcon()
                    fallbackLabel: bar.osFallbackLabel()
                    onClicked: bar.run("qs ipc call launcher toggle")
                }

                IconButton {
                    width: 34
                    height: 34
                    visible: bar.barEntryEnabled("dashboard") && bar.dashboardEnabled() && !bar.fullscreenQuiet()
                    icon: "applications-system-symbolic"
                    fallbackLabel: "D"
                    active: bar.openDropdown === "dashboard"
                    onClicked: bar.toggleDropdown("dashboard")

                    HoverHandler {
                        onHoveredChanged: if (hovered && bar.dashboardShowOnHover()) bar.openDropdown = "dashboard"
                    }
                }

                BarGroup {
                    id: workspaceGroup

                    visible: bar.barEntryEnabled("workspaces")
                    property bool hovered: false
                    property bool expanded: hovered
                    property int motionMs: bar.appearanceDuration(280)

                    height: 34
                    width: expanded ? workspacesRow.implicitWidth + 18 : 48
                    clip: true

                    Behavior on width { NumberAnimation { duration: workspaceGroup.motionMs; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 24
                        radius: height / 2
                        color: Theme.accent
                        border.color: Theme.accent
                        border.width: 1
                        opacity: workspaceGroup.expanded ? 0 : 1
                        scale: workspaceGroup.expanded ? 0.86 : 1

                        Behavior on opacity { NumberAnimation { duration: bar.appearanceDuration(180); easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: workspaceGroup.motionMs; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: Hyprland.focusedWorkspace !== null ? Hyprland.focusedWorkspace.id : 1
                            color: Theme.accentFg
                            font.family: bar.workspaceFontFamily()
                            font.pixelSize: bar.barLabelFontSize()
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        visible: workspaceGroup.expanded && bar.workspaceActiveTrailEnabled()
                        anchors.left: workspacesRow.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(8, Math.min(workspacesRow.implicitWidth, ((Hyprland.focusedWorkspace !== null ? Hyprland.focusedWorkspace.id : 1) / bar.workspaceShownCount()) * workspacesRow.implicitWidth))
                        height: 3
                        radius: 2
                        color: Theme.accent
                        opacity: 0.42

                        Behavior on width { NumberAnimation { duration: workspaceGroup.motionMs; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: bar.appearanceDuration(160) } }
                    }

                    Row {
                        id: workspacesRow
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        opacity: workspaceGroup.expanded ? 1 : 0
                        scale: workspaceGroup.expanded ? 1 : 0.98
                        transformOrigin: Item.Left

                        Behavior on opacity { NumberAnimation { duration: bar.appearanceDuration(210); easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: workspaceGroup.motionMs; easing.type: Easing.OutCubic } }

                        Repeater {
                            model: bar.workspaceShownCount()

                            WorkspaceButton {
                                required property int index
                                workspaceId: index + 1
                                enabled: workspaceGroup.expanded
                                opacity: workspaceGroup.expanded ? 1 : 0
                                scale: workspaceGroup.expanded ? 1 : 0.88

                                Behavior on opacity {
                                    SequentialAnimation {
                                        PauseAnimation { duration: workspaceGroup.expanded ? bar.appearanceDuration(index * 14) : 0 }
                                        NumberAnimation { duration: bar.appearanceDuration(150); easing.type: Easing.OutCubic }
                                    }
                                }

                                Behavior on scale {
                                    SequentialAnimation {
                                        PauseAnimation { duration: workspaceGroup.expanded ? bar.appearanceDuration(index * 10) : 0 }
                                        NumberAnimation { duration: bar.appearanceDuration(180); easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: workspaceHover

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onContainsMouseChanged: {
                            if (containsMouse)
                                workspaceIntentTimer.restart();
                            else {
                                workspaceIntentTimer.stop();
                                workspaceGroup.hovered = false;
                            }
                        }
                        onWheel: function(event) {
                            if (bar.scrollActionEnabled("workspaces")) {
                                bar.handleWorkspaceWheel(event.angleDelta.y);
                                event.accepted = true;
                            }
                        }
                    }

                    Timer {
                        id: workspaceIntentTimer
                        interval: bar.hoverIntentDelay()
                        repeat: false
                        onTriggered: workspaceGroup.hovered = workspaceHover.containsMouse
                    }
                }

                Pill {
                    visible: bar.barEntryEnabled("workspaces") && bar.specialWorkspaceVisible()
                    iconSource: bar.specialWorkspaceIconSource()
                    label: `scratch ${bar.specialWorkspaceLabel()}${bar.specialWorkspaceWindowSuffix()}`
                    maxWidth: 132
                    onClicked: Hyprland.dispatch("togglespecialworkspace " + bar.specialWorkspaceTarget())
                }

                BarGroup {
                    id: activeWindowGroup

                    property bool compact: bar.activeWindowCompactEnabled()
                    property bool expanded: !compact || (bar.activeWindowShowOnHoverEnabled() && activeWindowMouse.containsMouse) || bar.openDropdown === "activewindow"
                    property bool inverted: bar.activeWindowInvertedEnabled()

                    visible: bar.barEntryInSection("activeWindow", 0, 0) && !bar.fullscreenQuiet()
                    height: 34
                    width: expanded ? 330 : 44
                    color: inverted ? Theme.accent : Theme.bgAlt
                    border.color: inverted ? Theme.accent : Theme.border
                    clip: true

                    Behavior on width { NumberAnimation { duration: bar.appearanceDuration(220); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: bar.appearanceDuration(180) } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 7
                            color: activeWindowGroup.inverted ? Qt.rgba(1, 1, 1, 0.16) : Theme.surface
                            border.color: activeWindowGroup.inverted ? Qt.rgba(1, 1, 1, 0.25) : Theme.border
                            border.width: 1
                            clip: true

                            IconImage {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: bar.activeWindowIconSource()
                            }
                        }

                        Text {
                            width: 274
                            visible: activeWindowGroup.expanded
                            opacity: activeWindowGroup.expanded ? 1 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: Hyprland.activeToplevel !== null && Hyprland.activeToplevel.title.length > 0 ? Hyprland.activeToplevel.title : "Desktop"
                            color: activeWindowGroup.inverted ? Theme.bg : Theme.fg
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.barBodyFontSize()
                            font.weight: Font.Medium

                            Behavior on opacity { NumberAnimation { duration: bar.appearanceDuration(140) } }
                        }
                    }

                    MouseArea {
                        id: activeWindowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (bar.popoutEnabled("activeWindow")) bar.toggleDropdown("activewindow")
                    }
                }

                BarGroup {
                    visible: bar.barEntryInSection("media", 0, 0) && bar.mediaTitle().length > 0 && !bar.fullscreenQuiet()
                    height: 34
                    width: mediaSummary.implicitWidth + 20

                    Row {
                        id: mediaSummary
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: player && player.isPlaying ? "▶" : "Ⅱ"
                            color: Theme.accent
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.barLabelFontSize()
                            font.bold: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(190, implicitWidth)
                            text: bar.mediaTitle()
                            color: Theme.fg
                            elide: Text.ElideRight
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.barBodyFontSize()
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleDropdown("media")
                    }
                }

                BarSystemModule { section: 0 }
                BarPowerStatusModule { section: 0 }
                BarStatusIconsModule { section: 0 }
                BarTrayModule { section: 0 }
                BarAppearanceModule { section: 0 }
                BarQuickUtilitiesModule { section: 0 }
                BarNexusModule { section: 0 }
                BarNotificationsModule { section: 0 }
                BarPowerButtonModule { section: 0 }
            }

            Row {
                anchors.centerIn: parent
                spacing: bar.appearanceSpacing(8)

                BarGroup {
                    property bool compact: bar.activeWindowCompactEnabled()
                    property bool expanded: !compact || (bar.activeWindowShowOnHoverEnabled() && centerActiveWindowMouse.containsMouse) || bar.openDropdown === "activewindow"
                    property bool inverted: bar.activeWindowInvertedEnabled()

                    visible: bar.barEntryInSection("activeWindow", 1, 0) && !bar.fullscreenQuiet()
                    height: 34
                    width: expanded ? 300 : 44
                    color: inverted ? Theme.accent : Theme.bgAlt
                    border.color: inverted ? Theme.accent : Theme.border
                    clip: true

                    Behavior on width { NumberAnimation { duration: bar.appearanceDuration(220); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: bar.appearanceDuration(180) } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 7
                            color: parent.parent.inverted ? Qt.rgba(1, 1, 1, 0.16) : Theme.surface
                            border.color: parent.parent.inverted ? Qt.rgba(1, 1, 1, 0.25) : Theme.border
                            border.width: 1
                            clip: true

                            IconImage {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: bar.activeWindowIconSource()
                            }
                        }

                        Text {
                            width: 244
                            visible: parent.parent.expanded
                            opacity: parent.parent.expanded ? 1 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: Hyprland.activeToplevel !== null && Hyprland.activeToplevel.title.length > 0 ? Hyprland.activeToplevel.title : "Desktop"
                            color: parent.parent.inverted ? Theme.bg : Theme.fg
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.barBodyFontSize()
                            font.weight: Font.Medium

                            Behavior on opacity { NumberAnimation { duration: bar.appearanceDuration(140) } }
                        }
                    }

                    MouseArea {
                        id: centerActiveWindowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (bar.popoutEnabled("activeWindow")) bar.toggleDropdown("activewindow")
                    }
                }

                BarGroup {
                    visible: bar.barEntryInSection("media", 1, 0) && bar.mediaTitle().length > 0 && !bar.fullscreenQuiet()
                    height: 34
                    width: centerMediaSummary.implicitWidth + 20

                    Row {
                        id: centerMediaSummary
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: player && player.isPlaying ? "▶" : "Ⅱ"
                            color: Theme.accent
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.barLabelFontSize()
                            font.bold: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(190, implicitWidth)
                            text: bar.mediaTitle()
                            color: Theme.fg
                            elide: Text.ElideRight
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.barBodyFontSize()
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleDropdown("media")
                    }
                }

                BarSystemModule { section: 1 }
                BarPowerStatusModule { section: 1 }
                BarStatusIconsModule { section: 1 }
                BarTrayModule { section: 1 }
                BarAppearanceModule { section: 1 }
                BarQuickUtilitiesModule { section: 1 }
                BarNexusModule { section: 1 }
                BarNotificationsModule { section: 1 }
                BarPowerButtonModule { section: 1 }

                BarGroup {
                    visible: bar.barEntryInSection("clock", 1, 1)
                    width: centerClockRow.implicitWidth + 28
                    height: 34
                    color: bar.clockBackgroundEnabled() ? Theme.bgAlt : "transparent"
                    border.color: bar.clockBackgroundEnabled() ? Theme.border : "transparent"
                    border.width: bar.clockBackgroundEnabled() ? 1 : 0

                    Row {
                        id: centerClockRow
                        anchors.centerIn: parent
                        spacing: 7

                        Item {
                            visible: bar.configBool("bar.clock.showIcon", false)
                            width: 15
                            height: 15
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                id: centerClockIcon
                                anchors.fill: parent
                                source: bar.themedIcon("alarm-symbolic")
                                opacity: 0
                            }

                            ColorOverlay {
                                visible: centerClockIcon.source.toString().length > 0
                                anchors.fill: centerClockIcon
                                source: centerClockIcon
                                color: Theme.accent
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(clock.date, bar.clockPattern())
                            color: Theme.fg
                            font.family: bar.clockFontFamily()
                            font.pixelSize: bar.barClockFontSize()
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleDropdown("calendar")
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: bar.appearancePadding(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: bar.appearanceSpacing(8)

                BarGroup {
                    visible: bar.barEntryInSection("clock", 2, 1)
                    width: rightClockRow.implicitWidth + 28
                    height: 34
                    color: bar.clockBackgroundEnabled() ? Theme.bgAlt : "transparent"
                    border.color: bar.clockBackgroundEnabled() ? Theme.border : "transparent"
                    border.width: bar.clockBackgroundEnabled() ? 1 : 0

                    Row {
                        id: rightClockRow
                        anchors.centerIn: parent
                        spacing: 7

                        Item {
                            visible: bar.configBool("bar.clock.showIcon", false)
                            width: 15
                            height: 15
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                id: rightClockIcon
                                anchors.fill: parent
                                source: bar.themedIcon("alarm-symbolic")
                                opacity: 0
                            }

                            ColorOverlay {
                                visible: rightClockIcon.source.toString().length > 0
                                anchors.fill: rightClockIcon
                                source: rightClockIcon
                                color: Theme.accent
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(clock.date, bar.clockPattern())
                            color: Theme.fg
                            font.family: bar.clockFontFamily()
                            font.pixelSize: bar.barClockFontSize()
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleDropdown("calendar")
                    }
                }

                BarGroup {
                    visible: bar.barEntryInSection("system", 2, 2)
                    height: 34
                    width: systemSummary.implicitWidth + 22

                    Row {
                        id: systemSummary
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CPU"
                            color: Theme.accent2
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.barLabelFontSize()
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cpuPercent.value || "0%"
                            color: Theme.fg
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.barBodyFontSize()
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: 14
                            color: Theme.border
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "MEM"
                            color: Theme.accent2
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.barLabelFontSize()
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: memory.value || "-"
                            color: Theme.fg
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.barBodyFontSize()
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleDropdown("system")
                    }
                }

                BatteryPill {
                    visible: bar.barEntryInSection("power", 2, 2) && bar.statusEnabled("battery") && bar.hasLaptopBattery()
                    onClicked: bar.toggleDropdown("power")
                }

                PowerProfilePill {
                    visible: bar.barEntryInSection("power", 2, 2) && !bar.hasLaptopBattery()
                    onClicked: bar.toggleDropdown("power")
                }

                BarGroup {
                    visible: bar.barEntryInSection("statusIcons", 2, 2) && bar.visibleStatusItemCount() > 0
                    height: 34
                    width: statusItems.implicitWidth + 12

                    Row {
                        id: statusItems
                        anchors.centerIn: parent
                        spacing: 4

                        StatusPill {
                            visible: bar.statusEnabled("audio")
                            icon: bar.volumeMuted() ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            fallbackLabel: "A"
                            label: bar.volumeMuted() ? "mute" : `${bar.volumePercent()}%`
                            active: bar.openDropdown === "audio"
                            warning: bar.volumeMuted()
                            onClicked: bar.toggleStatusDropdown("audio")
                            onWheeled: function(deltaY) {
                                if (bar.scrollActionEnabled("volume"))
                                    bar.adjustVolume(deltaY > 0 ? bar.audioIncrement() : -bar.audioIncrement());
                            }
                        }

                        StatusButton {
                            visible: bar.statusEnabled("microphone")
                            icon: bar.sourceMuted() ? "microphone-disabled-symbolic" : "microphone-sensitivity-high-symbolic"
                            fallbackLabel: "M"
                            active: bar.openDropdown === "audio"
                            warning: bar.sourceMuted()
                            onClicked: bar.toggleStatusDropdown("audio")
                        }

                        StatusButton {
                            visible: bar.statusEnabled("privacy") && bar.privacyActive()
                            icon: bar.privacyIcon()
                            fallbackLabel: "P"
                            active: true
                            warning: true
                            onClicked: bar.toggleStatusDropdown("quick")
                        }

                        StatusButton {
                            visible: bar.statusEnabled("keyboard")
                            label: bar.keyboardLabel()
                            active: bar.openDropdown === "keyboard"
                            onClicked: bar.toggleStatusDropdown("keyboard")
                        }

                        StatusButton {
                            visible: bar.statusEnabled("lockStatus") && bar.capsLockOn()
                            label: "C"
                            active: true
                            warning: true
                            onClicked: bar.toggleStatusDropdown("keyboard")
                        }

                        StatusButton {
                            visible: bar.statusEnabled("lockStatus") && bar.numLockOn()
                            label: "1"
                            active: true
                            warning: true
                            onClicked: bar.toggleStatusDropdown("keyboard")
                        }

                        StatusPill {
                            visible: bar.networkStatusVisible()
                            icon: bar.networkIcon()
                            fallbackLabel: "N"
                            label: bar.networkShortLabel()
                            active: bar.openDropdown === "network"
                            warning: bar.networkOffline()
                            onClicked: bar.toggleStatusDropdown("network")
                        }

                        StatusPill {
                            visible: bar.statusEnabled("weather") && bar.weatherAvailable()
                            icon: bar.weatherIcon()
                            fallbackLabel: "W"
                            label: bar.weatherLabel()
                            onClicked: bar.toggleStatusDropdown("quick")
                        }

                        StatusButton {
                            visible: bar.statusEnabled("bluetooth") && bar.bluetoothAvailable()
                            icon: bar.bluetoothIcon()
                            fallbackLabel: "B"
                            active: bar.openDropdown === "bluetooth" || bar.bluetoothConnectedCount() > 0
                            warning: bar.bluetoothAvailable() && !bar.bluetoothEnabled()
                            onClicked: bar.toggleStatusDropdown("bluetooth")
                        }

                        StatusPill {
                            visible: bar.statusEnabled("brightness") && backlight.value.length > 0
                            icon: "display-brightness-symbolic"
                            fallbackLabel: "L"
                            label: `${bar.brightnessPercent()}%`
                            active: bar.openDropdown === "brightness"
                            onClicked: bar.toggleStatusDropdown("brightness")
                            onWheeled: function(deltaY) {
                                if (bar.scrollActionEnabled("brightness"))
                                    bar.adjustBrightness(deltaY > 0 ? bar.brightnessIncrement() : -bar.brightnessIncrement());
                            }
                        }

                        StatusButton {
                            visible: bar.statusEnabled("idleInhibit") && bar.idleInhibitEnabled()
                            icon: "night-light-disabled-symbolic"
                            fallbackLabel: "I"
                            active: true
                            warning: true
                            onClicked: bar.toggleStatusDropdown("quick")
                        }

                        StatusPill {
                            visible: bar.statusEnabled("updates") && bar.updateCount() > 0
                            icon: "software-update-available-symbolic"
                            fallbackLabel: "U"
                            label: `${bar.updateCount()}`
                            active: bar.openDropdown === "updates"
                            warning: true
                            onClicked: bar.toggleStatusDropdown("updates")
                        }

                        StatusPill {
                            visible: bar.statusEnabled("temperature") && bar.temperatureHot()
                            icon: "preferences-system-symbolic"
                            fallbackLabel: "T"
                            label: temperature.value
                            active: true
                            warning: !bar.temperatureDanger()
                            danger: bar.temperatureDanger()
                            onClicked: bar.toggleStatusDropdown("system")
                        }
                    }

                }

                BarGroup {
                    visible: bar.barEntryInSection("tray", 2, 2) && bar.visibleTrayItemCount() > 0 && !bar.fullscreenQuiet()
                    height: bar.trayCompactEnabled() ? 30 : 34
                    width: trayItems.implicitWidth + 12
                    color: bar.trayBackgroundEnabled() ? Theme.bgAlt : "transparent"
                    border.color: bar.trayBackgroundEnabled() ? Theme.border : "transparent"
                    border.width: bar.trayBackgroundEnabled() ? 1 : 0

                    Row {
                        id: trayItems
                        anchors.centerIn: parent
                        spacing: bar.trayCompactEnabled() ? 2 : 4

                        Repeater {
                            model: SystemTray.items

                            IconButton {
                                id: trayButton

                                required property var modelData
                                visible: bar.trayItemVisible(modelData)
                                width: bar.trayCompactEnabled() ? 24 : 28
                                height: bar.trayCompactEnabled() ? 24 : 28
                                iconSize: bar.trayIconSize()
                                iconSource: bar.trayItemIconSource(modelData)
                                label: bar.trayItemLabel(modelData)
                                fallbackLabel: ""
                                tintIcon: bar.trayRecolourEnabled()

                                onClicked: function(button) {
                                    const point = trayButton.mapToItem(null, 0, 0);
                                    bar.handleTrayItemClick(modelData, button, point.x + trayButton.width - bar.dropdownWidth());
                                }
                            }
                        }
                    }
                }

                ThemeButton {
                    visible: bar.barEntryInSection("appearance", 2, 2) && !bar.fullscreenQuiet()
                    active: bar.openDropdown === "theme"
                    onClicked: bar.toggleDropdown("theme")
                }

                IconButton {
                    width: 34
                    height: 34
                    visible: bar.barEntryInSection("quickUtilities", 2, 2) && !bar.fullscreenQuiet()
                    icon: "preferences-system-symbolic"
                    fallbackLabel: "Q"
                    active: bar.openDropdown === "quick"
                    onClicked: bar.toggleDropdown("quick")
                }

                IconButton {
                    width: 34
                    height: 34
                    visible: bar.barEntryInSection("nexus", 2, 2) && bar.nexusEnabled() && !bar.fullscreenQuiet()
                    icon: "network-wireless-symbolic"
                    fallbackLabel: "X"
                    active: bar.openDropdown === "nexus"
                    warning: bar.networkOffline()
                    onClicked: bar.toggleDropdown("nexus")
                }

                IconButton {
                    id: notificationButton
                    width: 34
                    height: 34
                    visible: bar.barEntryInSection("notifications", 2, 2) && !bar.fullscreenQuiet()
                    icon: bar.dndEnabled() ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
                    fallbackLabel: "N"
                    warning: bar.dndEnabled()
                    onClicked: bar.run("qs ipc call notifications toggle")

                    Rectangle {
                        visible: Number(notificationCount.value) > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2
                        anchors.rightMargin: -2
                        width: Math.max(16, countLabel.implicitWidth + 8)
                        height: 16
                        radius: 8
                        color: Theme.danger
                        border.color: Theme.bg
                        border.width: 1

                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: Number(notificationCount.value) > 9 ? "9+" : notificationCount.value
                            color: Theme.accentFg
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.barBadgeFontSize()
                            font.weight: Font.DemiBold
                        }
                    }
                }

                IconButton {
                    width: 34
                    height: 34
                    visible: bar.barEntryInSection("power", 2, 2)
                    icon: "system-shutdown-symbolic"
                    fallbackLabel: "P"
                    danger: true
                    onClicked: bar.toggleDropdown("power")
                }
            }
        }

        onVisibleChanged: {
            if (!visible)
                bar.topBarHover = false;
        }
    }

    PanelWindow {
        id: osdWindow

        screen: bar.modelData
        visible: bar.screenBarEnabled() && bar.osdVisible
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: true
        }

        margins {
            bottom: 68
        }

        implicitWidth: 280
        implicitHeight: 76

        Rectangle {
            anchors.fill: parent
            radius: bar.appearanceRounding(18)
            color: Theme.bg
            border.color: Theme.border
            border.width: 1
            opacity: osdWindow.visible ? bar.osdOpacity() : 0
            scale: osdWindow.visible ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: bar.appearanceDuration(170); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: bar.appearanceDuration(210); easing.type: Easing.OutCubic } }

            Row {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Rectangle {
                    width: 42
                    height: 42
                    radius: 14
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    IconImage {
                        id: osdIconImage
                        anchors.centerIn: parent
                        implicitSize: 22
                        source: bar.themedIcon(bar.osdIcon())
                        opacity: 0
                    }

                    ColorOverlay {
                        visible: osdIconImage.source.toString().length > 0
                        anchors.fill: osdIconImage
                        source: osdIconImage
                        color: bar.osdMuted ? Theme.warning : Theme.accent
                    }
                }

                Column {
                    width: parent.width - 54
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            width: parent.width - 56
                            text: bar.osdTitle()
                            color: Theme.fg
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.panelLabelFontSize()
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: 48
                            text: `${bar.osdPercent()}%`
                            color: Theme.fgMuted
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.panelMetaFontSize()
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 7
                        radius: 4
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(7, parent.width * Math.min(1, bar.osdValue / bar.osdMax))
                            radius: 4
                            color: bar.osdMuted ? Theme.warning : Theme.accent
                        }
                    }
                }
            }
        }
    }

    QsMenuOpener {
        id: trayMenuModel
    }

    QsMenuOpener {
        id: traySubmenuModel
    }

    Timer {
        id: trayNativeFallbackTimer
        interval: 140
        repeat: false
        onTriggered: bar.maybeFallbackToNativeTrayMenu()
    }

    PopupWindow {
        id: dropdownPopup

        visible: bar.screenBarEnabled() && bar.openDropdown !== ""
        implicitWidth: bar.dropdownWidth()
        implicitHeight: bar.dropdownHeight()
        color: "transparent"
        grabFocus: true

        anchor.window: topBar
        anchor.rect.x: bar.dropdownX()
        anchor.rect.y: topBar.height + 6

        onVisibleChanged: {
            if (!visible && bar.openDropdown !== "")
                bar.closeDropdown();
        }

        Connections {
            target: topBar

            function onVisibleChanged() {
                if (!topBar.visible && bar.openDropdown !== "")
                    bar.closeDropdown();
            }
        }

    DropPanel {
        visible: bar.openDropdown === "tray" && bar.activeTrayItem !== null
        anchors.fill: parent

        Column {
            id: trayMenuColumn

            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            TrayMenuHeader {
                id: trayMenuHeader

                visible: bar.trayMenuParents.length > 0
                title: bar.trayMenuTitle()
                onClicked: bar.trayMenuBack()
            }

            Flickable {
                id: trayMenuScroller

                width: parent.width
                height: Math.max(0, parent.height - (trayMenuHeader.visible ? trayMenuHeader.height + parent.spacing : 0))
                contentHeight: trayMenuContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: trayMenuContent

                    width: trayMenuScroller.width
                    spacing: 3

                    Repeater {
                        model: bar.activeTraySubmenu !== null ? traySubmenuModel.children : trayMenuModel.children

                        TrayMenuItem {
                            required property var modelData

                            entry: modelData
                            onClicked: {
                                if (modelData.isSeparator)
                                    return;

                                if (modelData.hasChildren) {
                                    bar.openTraySubmenu(modelData);
                                } else {
                                    bar.triggerTrayEntry(modelData);
                                    bar.closeDropdown();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "dashboard"
        anchors.fill: parent

        Flickable {
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentHeight: dashboardPanelContent.implicitHeight

        Column {
            id: dashboardPanelContent

            width: parent.width
            padding: 14
            spacing: 10

            Row {
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: 58
                spacing: 12

                Rectangle {
                    width: 52
                    height: 52
                    radius: 16
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        fillMode: Image.PreserveAspectCrop
                        source: bar.dashboardProfileImage()
                        visible: source.toString().length > 0
                    }

                    Text {
                        visible: bar.dashboardProfileImage().length === 0
                        anchors.centerIn: parent
                        text: bar.dashboardProfileName().length > 0 ? bar.dashboardProfileName()[0].toUpperCase() : "D"
                        color: Theme.accent
                        font.pixelSize: bar.panelHeroFontSize()
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.toggleDropdown("profileimage")
                    }
                }

                Column {
                    width: parent.width - 64
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: bar.dashboardProfileName()
                        color: Theme.fg
                        font.pixelSize: bar.panelTitleFontSize()
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: `${Qt.formatDateTime(clock.date, "yyyy.MM.dd ddd")} · up ${bar.dashboardUptime()}`
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        elide: Text.ElideRight
                    }
                }
            }

            PowerAction {
                width: parent.width - parent.leftPadding - parent.rightPadding
                label: "Set profile picture"
                icon: "avatar-default-symbolic"
                onClicked: bar.toggleDropdown("profileimage")
            }

            Row {
                width: parent.width - parent.leftPadding - parent.rightPadding
                visible: bar.dashboardShowPerformance()
                spacing: 8

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showCpu")
                    columns: bar.dashboardSummaryColumns()
                    title: "CPU"
                    value: cpuPercent.value || "0%"
                    accent: Theme.accent
                }

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showMemory")
                    columns: bar.dashboardSummaryColumns()
                    title: "MEM"
                    value: memory.value || "-"
                    accent: Theme.accent2
                }

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showGpu") && bar.gpuAvailable()
                    columns: bar.dashboardSummaryColumns()
                    title: "GPU"
                    value: bar.gpuLabel()
                    accent: Theme.warning
                }

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showStorage")
                    columns: bar.dashboardSummaryColumns()
                    title: "DISK"
                    value: bar.storageLabel()
                    accent: Theme.success
                }

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showNetwork")
                    columns: bar.dashboardSummaryColumns()
                    title: "NET"
                    value: networkTraffic.value || "-"
                    accent: Theme.accent2
                }

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showBattery") && bar.hasLaptopBattery()
                    columns: bar.dashboardSummaryColumns()
                    title: "BAT"
                    value: UPower.displayDevice !== null ? `${Math.round(UPower.displayDevice.percentage)}%` : "-"
                    accent: UPower.displayDevice !== null ? bar.batteryAccent(Math.round(UPower.displayDevice.percentage)) : Theme.success
                }

                DashboardMetric {
                    visible: bar.dashboardPerformanceEnabled("showTemperature")
                    columns: bar.dashboardSummaryColumns()
                    title: "TEMP"
                    value: temperature.value || "-"
                    accent: bar.temperatureDanger() ? Theme.danger : Theme.warning
                }
            }

            Column {
                visible: bar.dashboardShowMedia() && player !== null
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 8

                PanelTitle { text: "Now playing" }

                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 12
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 54
                            height: 54
                            radius: 10
                            color: Theme.bgAlt
                            border.color: Theme.border
                            border.width: 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                fillMode: Image.PreserveAspectCrop
                                source: bar.mediaArtUrl()
                                visible: source.toString().length > 0
                            }

                            Text {
                                visible: bar.mediaArtUrl().length === 0
                                anchors.centerIn: parent
                                text: "♪"
                                color: Theme.fgMuted
                                font.pixelSize: bar.panelHeroFontSize()
                                font.bold: true
                            }
                        }

                        Column {
                            width: parent.width - 118
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: player ? player.trackTitle : ""
                                color: Theme.fg
                                font.family: bar.appearanceFontFamily("label", "")
                                font.pixelSize: bar.panelLabelFontSize()
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: bar.mediaSubtitle()
                                color: Theme.fgMuted
                                font.family: bar.appearanceFontFamily("body", "")
                                font.pixelSize: bar.panelMetaFontSize()
                                elide: Text.ElideRight
                            }
                        }

                        MediaIconControl {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: player && player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                            fallbackLabel: player && player.isPlaying ? "II" : ">"
                            enabled: bar.mediaCan("canTogglePlaying")
                            primary: true
                            onClicked: bar.mediaTogglePlaying()
                        }
                    }
                }
            }

            Column {
                visible: bar.dashboardShowPerformance()
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 8

                PanelTitle { text: "Performance" }
                ResourceMeter {
                    visible: bar.dashboardPerformanceEnabled("showCpu")
                    title: "CPU"
                    detail: cpu.value || "-"
                    percent: bar.percentNumber(cpuPercent.value)
                    accent: Theme.accent
                }
                ResourceMeter {
                    visible: bar.dashboardPerformanceEnabled("showMemory")
                    title: "Memory"
                    detail: memory.value || "-"
                    percent: bar.percentNumber(memory.value)
                    accent: Theme.accent2
                }
                ResourceMeter {
                    visible: bar.dashboardPerformanceEnabled("showGpu") && bar.gpuAvailable()
                    title: "GPU"
                    detail: bar.gpuLabel()
                    percent: bar.gpuPercent()
                    accent: Theme.warning
                }
                ResourceMeter {
                    visible: bar.dashboardPerformanceEnabled("showStorage")
                    title: "Storage"
                    detail: bar.storageLabel()
                    percent: bar.storagePercent()
                    accent: Theme.success
                }
                ResourceMeter {
                    visible: bar.dashboardPerformanceEnabled("showNetwork")
                    title: "Network"
                    detail: networkTraffic.value || "-"
                    percent: 0
                    accent: Theme.accent2
                }
                ResourceMeter {
                    visible: bar.dashboardPerformanceEnabled("showBattery") && bar.hasLaptopBattery()
                    title: "Battery"
                    detail: UPower.displayDevice !== null ? bar.batteryState() : "-"
                    percent: UPower.displayDevice !== null ? Math.round(UPower.displayDevice.percentage) : 0
                    accent: UPower.displayDevice !== null ? bar.batteryAccent(Math.round(UPower.displayDevice.percentage)) : Theme.success
                }
            }

            Rectangle {
                visible: bar.dashboardShowWeather() && bar.weatherAvailable()
                width: parent.width - parent.leftPadding - parent.rightPadding
                height: 48
                radius: 12
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Item {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            id: dashboardWeatherIcon
                            anchors.fill: parent
                            source: bar.themedIcon(bar.weatherIcon())
                            opacity: 0
                        }

                        ColorOverlay {
                            visible: dashboardWeatherIcon.source.toString().length > 0
                            anchors.fill: dashboardWeatherIcon
                            source: dashboardWeatherIcon
                            color: Theme.accent2
                        }
                    }

                    Text {
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.weatherDetail()
                        color: Theme.fg
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        elide: Text.ElideRight
                    }
                }
            }
        }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "profileimage"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 10

                PanelTitle {
                    width: parent.width - 42
                    text: "Profile Picture"
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 32
                    height: 28
                    radius: 8
                    color: profileImageRefreshMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: Theme.fg
                        font.family: bar.appearanceFontFamily("label", "")
                        font.pixelSize: bar.panelLabelFontSize()
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: profileImageRefreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.profileImageRefreshNonce++
                    }
                }
            }

            Text {
                visible: bar.profileImageItems().length === 0
                width: parent.width
                text: "No images found in Pictures, Downloads, or home"
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.panelBodyFontSize()
                wrapMode: Text.WordWrap
            }

            Flickable {
                width: parent.width
                height: Math.max(0, parent.height - 42)
                contentHeight: profileImageListContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: profileImageListContent

                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: bar.profileImageItems()

                        ProfileImageItem {
                            required property string modelData

                            path: modelData
                            onClicked: bar.chooseProfileImage(modelData)
                        }
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "system"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "System" }
            StatRow { name: "Profile"; value: bar.powerProfileLabel() }
            StatRow { name: "Network"; value: networkTraffic.value || "-" }
            StatRow { name: "Temp"; value: temperature.value || "-" }

            ResourceMeter { title: "CPU"; detail: cpu.value || "-"; percent: bar.percentNumber(cpuPercent.value); accent: Theme.accent }
            ResourceMeter { title: "Memory"; detail: memory.value || "-"; percent: bar.percentNumber(memory.value); accent: Theme.accent2 }
            ResourceMeter {
                visible: bar.gpuAvailable()
                title: "GPU"
                detail: bar.gpuLabel()
                percent: bar.gpuPercent()
                accent: Theme.warning
            }
            ResourceMeter { title: "Storage"; detail: bar.storageLabel(); percent: bar.storagePercent(); accent: Theme.success }
            ResourceMeter {
                visible: backlight.value.length > 0
                title: "Backlight"
                detail: backlight.value || "-"
                percent: bar.percentNumber(backlight.value)
                accent: Theme.warning
            }
            ResourceMeter {
                visible: UPower.displayDevice !== null && UPower.displayDevice.isPresent
                title: "Battery"
                detail: UPower.displayDevice !== null && UPower.displayDevice.isPresent ? `${Math.round(UPower.displayDevice.percentage)}% ${bar.batteryState()}` : "-"
                percent: UPower.displayDevice !== null && UPower.displayDevice.isPresent ? Math.round(UPower.displayDevice.percentage) : 0
                accent: UPower.displayDevice !== null ? bar.batteryAccent(Math.round(UPower.displayDevice.percentage)) : Theme.success
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "quick"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "Quick Utilities" }

            Row {
                width: parent.width
                spacing: 6

                CompactAction {
                    visible: bar.quickToggleEnabled("wifi") && bar.wifiRadioAvailable()
                    label: bar.wifiRadioEnabled() ? "Wi-Fi on" : "Wi-Fi off"
                    command: ""
                    onClicked: bar.toggleWifiRadio()
                }

                CompactAction {
                    visible: bar.quickToggleEnabled("bluetooth") && bar.bluetoothAvailable()
                    label: bar.bluetoothEnabled() ? "BT on" : "BT off"
                    command: bar.bluetoothEnabled() ? "bluetoothctl power off" : "bluetoothctl power on"
                }

                CompactAction {
                    visible: bar.quickToggleEnabled("mic")
                    label: bar.sourceMuted() ? "Mic muted" : "Mic on"
                    command: ""
                    danger: bar.sourceMuted()
                    onClicked: bar.toggleSourceMute()
                }
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("privacy") && bar.privacyActive()
                title: "Privacy active"
                detail: bar.privacyLabel()
                icon: bar.privacyIcon()
                active: true
                onClicked: bar.closeDropdown()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("dnd")
                title: "Do not disturb"
                detail: bar.dndEnabled() ? "Notification toasts are muted" : "Notification toasts are visible"
                icon: bar.dndEnabled() ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
                active: bar.dndEnabled()
                onClicked: bar.toggleDnd()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("idleInhibit") && bar.idleInhibitAvailable()
                title: "Idle inhibit"
                detail: bar.idleInhibitEnabled() ? "Lock and sleep are paused" : "Lock and sleep follow hypridle"
                icon: bar.idleInhibitEnabled() ? "night-light-disabled-symbolic" : "alarm-symbolic"
                active: bar.idleInhibitEnabled()
                onClicked: bar.toggleIdleInhibit()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("gameMode")
                title: "Game mode"
                detail: bar.gameModeEnabled() ? "Animations and blur are disabled" : "Hyprland effects are normal"
                icon: "applications-system-symbolic"
                active: bar.gameModeEnabled()
                onClicked: bar.toggleGameMode()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("weather") && bar.weatherAvailable()
                title: "Weather"
                detail: bar.weatherDetail()
                icon: bar.weatherIcon()
                active: false
                onClicked: bar.closeDropdown()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("vpn") && bar.vpnInstalled()
                title: bar.vpnTitle()
                detail: bar.vpnLabel()
                icon: "network-vpn-symbolic"
                active: bar.vpnConnected()
                command: bar.vpnCommand()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("explorer") && explorerTool.value.length > 0
                title: "File manager"
                detail: `Open with ${explorerTool.value}`
                icon: "system-file-manager-symbolic"
                command: explorerTool.value
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("clipboard") && bar.clipboardAvailable()
                title: "Clipboard history"
                detail: "Open saved clipboard items"
                icon: "edit-paste-symbolic"
                onClicked: bar.toggleDropdown("clipboard")
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("wallpaper") && bar.wallpaperAvailable()
                title: "Random wallpaper"
                detail: bar.wallpaperDetail()
                icon: "preferences-desktop-wallpaper-symbolic"
                command: bar.wallpaperCommand()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("recording") && bar.recordingAvailable()
                title: "Screen recording"
                detail: bar.recordingDetail()
                icon: "video-display-symbolic"
                active: bar.recordingActive()
                onClicked: bar.toggleRecording()
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("screenshotArea")
                title: "Screenshot area"
                detail: "Select a region and save it"
                icon: "camera-photo-symbolic"
                command: "mkdir -p \"$HOME/Pictures/Screenshots\"; grim -g \"$(slurp)\" \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("screenshotScreen")
                title: "Screenshot screen"
                detail: "Capture the current screen"
                icon: "camera-photo-symbolic"
                command: "mkdir -p \"$HOME/Pictures/Screenshots\"; grim \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""
            }

            UtilityAction {
                visible: bar.quickToggleEnabled("settings") && settingsTool.value.length > 0
                title: "Settings"
                detail: "Open system settings"
                icon: "preferences-system-symbolic"
                command: settingsTool.value
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "clipboard"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 10

                PanelTitle {
                    width: parent.width - 42
                    text: "Clipboard"
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 32
                    height: 28
                    radius: 8
                    color: clipboardRefreshMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: Theme.fg
                        font.family: bar.appearanceFontFamily("label", "")
                        font.pixelSize: bar.panelLabelFontSize()
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: clipboardRefreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bar.clipboardRefreshNonce++
                    }
                }
            }

            Text {
                visible: bar.clipboardItems().length === 0
                width: parent.width
                text: bar.clipboardAvailable() ? "No clipboard history yet" : "Clipboard history is unavailable"
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.panelBodyFontSize()
                wrapMode: Text.WordWrap
            }

            Flickable {
                width: parent.width
                height: Math.max(0, parent.height - 42)
                contentHeight: clipboardListContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: clipboardListContent

                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: bar.clipboardItems()

                        ClipboardHistoryItem {
                            required property string modelData

                            value: modelData
                            onClicked: bar.restoreClipboardItem(modelData)
                        }
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "activewindow"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "Active Window" }
            StatRow { name: "Title"; value: Hyprland.activeToplevel !== null && Hyprland.activeToplevel.title.length > 0 ? Hyprland.activeToplevel.title : "Desktop" }
            StatRow { name: "Class"; value: Hyprland.activeToplevel !== null ? Hyprland.activeToplevel.lastIpcObject.class || "-" : "-" }
            StatRow { name: "Workspace"; value: Hyprland.focusedWorkspace !== null ? `${Hyprland.focusedWorkspace.id}` : "-" }

            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                WindowAction {
                    title: "Floating"
                    icon: "window-restore-symbolic"
                    command: "hyprctl dispatch togglefloating"
                }

                WindowAction {
                    title: "Fullscreen"
                    icon: "view-fullscreen-symbolic"
                    command: "hyprctl dispatch fullscreen"
                }

                WindowAction {
                    title: "Pin"
                    icon: "view-pin-symbolic"
                    command: "hyprctl dispatch pin"
                }

                WindowAction {
                    title: "Screenshot"
                    icon: "camera-photo-symbolic"
                    command: "grim -g \"$(hyprctl activewindow -j | jq -r '\"'\"'\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"'\"'\"')\" - | swappy -f -"
                }
            }

            PowerAction {
                label: "Close active window"
                icon: "window-close-symbolic"
                command: "hyprctl dispatch killactive"
                danger: true
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "audio"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            PanelTitle { text: "Audio" }
            StatRow { name: "Output"; value: `${bar.volumePercent()}%${bar.volumeMuted() ? " muted" : ""}` }

            Row {
                width: parent.width
                spacing: 10

                VolumeSlider {
                    width: parent.width - 46
                    maximum: bar.maxVolume()
                    value: bar.currentVolume()
                    onMoved: function(nextValue) {
                        bar.setVolume(nextValue);
                    }
                }

                MediaIconControl {
                    icon: bar.volumeMuted() ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                    fallbackLabel: "V"
                    active: bar.volumeMuted()
                    onClicked: bar.toggleMute()
                }
            }

            Row {
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width - 46
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width / 2
                        text: "Input"
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                    }

                    Text {
                        width: parent.width / 2
                        text: `${bar.sourcePercent()}${bar.sourceMuted() ? " muted" : ""}`
                        color: Theme.fg
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                }

                MediaIconControl {
                    icon: bar.sourceMuted() ? "microphone-disabled-symbolic" : "microphone-sensitivity-high-symbolic"
                    fallbackLabel: "M"
                    active: bar.sourceMuted()
                    onClicked: bar.toggleSourceMute()
                }
            }

            PowerAction {
                label: "Open audio settings"
                icon: "audio-volume-high-symbolic"
                command: soundTool.value.length > 0 ? soundTool.value : bar.configuredAppCommand("audio", ["pavucontrol"])
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "updates"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "Package Updates" }

            StatRow { name: "Total"; value: `${bar.updateCount()}` }
            StatRow { name: "Pacman"; value: bar.updateParts().length > 1 ? bar.updateParts()[1] : "0" }
            StatRow { name: "AUR"; value: bar.updateParts().length > 2 ? bar.updateParts()[2] : "0" }

            UtilityAction {
                title: "Upgrade packages"
                detail: bar.updateLabel()
                icon: "software-update-available-symbolic"
                active: bar.updateCount() > 0
                command: bar.updateCommand()
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "network"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "Network" }
            StatRow { name: "Connection"; value: bar.networkLabel() }
            StatRow { name: "Type"; value: bar.networkParts().length > 0 ? bar.networkParts()[0] : "offline" }
            StatRow {
                visible: bar.networkParts().length > 0 && bar.networkParts()[0] === "wifi"
                name: "Signal"
                value: bar.networkSignalLabel()
            }

            Row {
                width: parent.width
                spacing: 6

                CompactAction {
                    label: "Wi-Fi"
                    command: "nmcli radio wifi on"
                }

                CompactAction {
                    label: "Off"
                    command: "nmcli radio wifi off"
                    danger: true
                }

                CompactAction {
                    label: "Settings"
                    command: networkTool.value.length > 0 ? networkTool.value : bar.terminalCommand("nmtui")
                }
            }

            Text { text: "Known connections"; color: Theme.fgMuted; font.family: bar.appearanceFontFamily("label", ""); font.pixelSize: bar.panelLabelFontSize(); font.weight: Font.DemiBold }

            Flickable {
                width: parent.width
                height: 190
                clip: true
                contentHeight: networkList.implicitHeight

                Column {
                    id: networkList
                    width: parent.width
                    spacing: 6

                    Text {
                        visible: bar.rows(networkConnections.value).length === 0
                        width: parent.width
                        height: 34
                        text: "No saved connections"
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Repeater {
                        model: bar.rows(networkConnections.value)

                        ListAction {
                            required property string modelData

                            width: networkList.width
                            title: bar.rowPart(modelData, 0)
                            detail: bar.rowPart(modelData, 1) === "802-11-wireless" ? "Wi-Fi" : "Ethernet"
                            command: "nmcli connection up id " + bar.shellQuote(bar.rowPart(modelData, 0))
                        }
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "nexus"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                PanelTitle {
                    width: parent.width - 116
                    text: "Nexus"
                }

                CompactAction {
                    width: 108
                    label: "Network app"
                    command: networkTool.value.length > 0 ? networkTool.value : bar.terminalCommand("nmtui")
                }
            }

            Rectangle {
                width: parent.width
                height: 82
                radius: 12
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        width: parent.width
                        text: bar.networkOffline() ? "Offline" : bar.networkLabel()
                        color: bar.networkOffline() ? Theme.warning : Theme.fg
                        font.family: bar.appearanceFontFamily("label", "")
                        font.pixelSize: bar.panelTitleFontSize()
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: `${bar.networkParts().length > 0 ? bar.networkParts()[0] : "network"} · ${networkTraffic.value || "no traffic"}${bar.wifiSignal() >= 0 ? " · signal " + bar.networkSignalLabel() : ""}`
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Theme.bgAlt

                        Rectangle {
                            width: parent.width * Math.max(0.06, Math.min(1, (bar.wifiSignal() >= 0 ? bar.wifiSignal() : bar.networkOffline() ? 0 : 100) / 100))
                            height: parent.height
                            radius: 3
                            color: bar.networkOffline() ? Theme.warning : Theme.accent
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6

                CompactAction {
                    visible: bar.wifiRadioAvailable()
                    label: bar.wifiRadioEnabled() ? "Wi-Fi on" : "Wi-Fi off"
                    command: ""
                    onClicked: bar.toggleWifiRadio()
                }

                CompactAction {
                    label: "Rescan"
                    command: "nmcli dev wifi rescan"
                }

                CompactAction {
                    label: "nmtui"
                    command: bar.terminalCommand("nmtui")
                }
            }

            Text {
                width: parent.width
                text: "Nearby Wi-Fi"
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.weight: Font.DemiBold
            }

            Flickable {
                width: parent.width
                height: 126
                clip: true
                contentHeight: nexusWifiList.implicitHeight

                Column {
                    id: nexusWifiList
                    width: parent.width
                    spacing: 6

                    Text {
                        visible: bar.nexusNetworkRows().length === 0
                        width: parent.width
                        height: 36
                        text: "No visible Wi-Fi networks"
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Repeater {
                        model: bar.nexusNetworkRows()

                        ListAction {
                            required property string modelData
                            width: nexusWifiList.width
                            title: `${bar.rowPart(modelData, 3) === "yes" ? "● " : ""}${bar.rowPart(modelData, 0)}`
                            detail: `signal ${bar.rowPart(modelData, 1)}% · ${bar.rowPart(modelData, 2).length > 0 ? bar.rowPart(modelData, 2) : "open"}`
                            command: "nmcli dev wifi connect " + bar.shellQuote(bar.rowPart(modelData, 0))
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: "Saved connections"
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.weight: Font.DemiBold
            }

            Flickable {
                width: parent.width
                height: 92
                clip: true
                contentHeight: nexusSavedList.implicitHeight

                Column {
                    id: nexusSavedList
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: bar.rows(networkConnections.value)

                        ListAction {
                            required property string modelData
                            width: nexusSavedList.width
                            title: bar.rowPart(modelData, 0)
                            detail: bar.rowPart(modelData, 1) === "802-11-wireless" ? "Wi-Fi profile" : "Ethernet profile"
                            command: "nmcli connection up id " + bar.shellQuote(bar.rowPart(modelData, 0))
                        }
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "bluetooth"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "Bluetooth" }
            StatRow { name: "Status"; value: bar.bluetoothLabel() }
            StatRow { name: "Connected"; value: `${bar.bluetoothConnectedCount()}` }

            Row {
                width: parent.width
                spacing: 6

                CompactAction { label: "On"; command: "bluetoothctl power on" }
                CompactAction { label: "Off"; command: "bluetoothctl power off"; danger: true }
                CompactAction { label: "Scan"; command: "bluetoothctl scan on" }
            }

            CompactAction {
                width: parent.width
                label: "Settings"
                command: bluetoothTool.value.length > 0 ? bluetoothTool.value : "blueman-manager"
            }

            Text { text: "Paired devices"; color: Theme.fgMuted; font.family: bar.appearanceFontFamily("label", ""); font.pixelSize: bar.panelLabelFontSize(); font.weight: Font.DemiBold }

            Flickable {
                width: parent.width
                height: 190
                clip: true
                contentHeight: bluetoothList.implicitHeight

                Column {
                    id: bluetoothList
                    width: parent.width
                    spacing: 6

                    Text {
                        visible: bar.rows(bluetoothDevices.value).length === 0
                        width: parent.width
                        height: 34
                        text: "No paired devices"
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Repeater {
                        model: bar.rows(bluetoothDevices.value)

                        ListAction {
                            required property string modelData

                            width: bluetoothList.width
                            title: bar.rowPart(modelData, 1)
                            detail: bar.rowPart(modelData, 0)
                            command: "bluetoothctl connect " + bar.shellQuote(bar.rowPart(modelData, 0))
                        }
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "keyboard"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            PanelTitle { text: "Keyboard" }
            StatRow { name: "Layout"; value: bar.keyboardDetail() }
            StatRow { name: "Caps lock"; value: bar.capsLockOn() ? "enabled" : "disabled" }
            StatRow { name: "Num lock"; value: bar.numLockOn() ? "enabled" : "disabled" }
            PowerAction {
                label: "Next layout"
                iconSource: "file:///usr/share/icons/Adwaita/symbolic/devices/input-keyboard-symbolic.svg"
                command: "hyprctl switchxkblayout all next"
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "brightness"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            PanelTitle { text: "Brightness" }
            StatRow { name: "Display"; value: `${bar.brightnessPercent()}%` }

            VolumeSlider {
                width: parent.width
                maximum: 1
                value: bar.currentBrightness()
                onMoved: function(nextValue) {
                    bar.setBrightness(nextValue);
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "theme"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                PanelTitle {
                    width: parent.width - 92
                    text: "Appearance"
                    elide: Text.ElideRight
                }

                Text {
                    width: 84
                    text: `${bar.themeModeLabel(Theme.mode)}`
                    color: Theme.fgMuted
                    font.family: bar.appearanceFontFamily("body", "")
                    font.pixelSize: bar.panelBodyFontSize()
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 54
                radius: 10
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Column {
                        width: (parent.width - 10) / 2
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: "Mode"
                            color: Theme.fgMuted
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.panelLabelFontSize()
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: bar.themeModeLabel(Theme.mode)
                            color: Theme.fg
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.panelLabelFontSize()
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Column {
                        width: (parent.width - 10) / 2
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: "Color scheme"
                            color: Theme.fgMuted
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.panelLabelFontSize()
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: bar.colorSchemeLabel(Theme.colorScheme || Theme.name)
                            color: Theme.fg
                            font.family: bar.appearanceFontFamily("label", "")
                            font.pixelSize: bar.panelLabelFontSize()
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8

                ThemeModeButton {
                    label: "Dark"
                    active: Theme.mode === "dark"
                    enabled: active || bar.canApplyMode("dark")
                    onClicked: bar.applyThemeMode("dark")
                }

                ThemeModeButton {
                    label: "Light"
                    active: Theme.mode === "light"
                    enabled: active || bar.canApplyMode("light")
                    onClicked: bar.applyThemeMode("light")
                }
            }

            ThemeSectionTitle { text: "Wallpaper" }

            UtilityAction {
                title: "Random wallpaper"
                detail: bar.wallpaperAvailable() ? bar.wallpaperDetail() : `No wallpaper backend or images in ${bar.wallpaperDetail()}`
                icon: "preferences-desktop-wallpaper-symbolic"
                command: bar.wallpaperCommand()
                active: false
            }

            Flickable {
                width: parent.width
                height: 182
                clip: true
                contentHeight: themeList.implicitHeight

                Component {
                    id: themeOptionDelegate

                    Rectangle {
                        required property var modelData
                        property bool active: Theme.name === modelData.name

                        width: themeList.width
                        height: 42
                        radius: 10
                        color: active ? Theme.surfaceHover : themeMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.color: active ? Theme.accent : Theme.border
                        border.width: 1

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 42
                                height: 22
                                radius: 8
                                color: modelData.bg
                                border.color: Theme.border
                                border.width: 1
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Rectangle { width: 8; height: 14; radius: 4; color: modelData.accent }
                                    Rectangle { width: 8; height: 14; radius: 4; color: modelData.accent2 }
                                }
                            }

                            Column {
                                width: parent.width - 112
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    width: parent.width
                                    text: modelData.label
                                    color: Theme.fg
                                    font.family: bar.appearanceFontFamily("label", "")
                                    font.pixelSize: bar.panelLabelFontSize()
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: `${bar.themeModeLabel(modelData.mode)} mode · color scheme`
                                    color: Theme.fgMuted
                                    font.family: bar.appearanceFontFamily("body", "")
                                    font.pixelSize: bar.panelMetaFontSize()
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                width: 40
                                text: active ? "active" : "apply"
                                color: active ? Theme.accent : Theme.fgMuted
                                font.family: bar.appearanceFontFamily("label", "")
                                font.pixelSize: bar.panelLabelFontSize()
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: themeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: bar.applyTheme(modelData.name)
                        }
                    }
                }

                Column {
                    id: themeList

                    width: parent.width
                    spacing: 8

                    ThemeSectionTitle { text: "Dark mode color schemes" }

                    Repeater {
                        model: bar.colorSchemes.filter(theme => theme.mode === "dark")
                        delegate: themeOptionDelegate
                    }

                    ThemeSectionTitle { text: "Light mode color schemes" }

                    Repeater {
                        model: bar.colorSchemes.filter(theme => theme.mode === "light")
                        delegate: themeOptionDelegate
                    }
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "power"
        anchors.fill: parent

        Column {
            id: powerColumn
            property int panelPadding: 10

            anchors.fill: parent
            anchors.margins: panelPadding
            spacing: 6

            PowerAction { label: "Lock"; icon: bar.sessionIcon("lock", "system-lock-screen-symbolic"); command: bar.sessionCommand("lock", bar.defaultLockCommand()) }
            PowerAction { label: "Suspend"; icon: "media-playback-pause-symbolic"; command: "systemctl suspend" }
            PowerAction { label: "Logout"; icon: bar.sessionIcon("logout", "system-log-out-symbolic"); command: bar.sessionCommand("logout", "hyprctl dispatch exit") }
            PowerAction { label: "Hibernate"; icon: bar.sessionIcon("hibernate", "media-playback-pause-symbolic"); command: bar.sessionCommand("hibernate", "systemctl hibernate") }
            PowerAction { label: "Reboot"; icon: bar.sessionIcon("reboot", "system-reboot-symbolic"); command: bar.sessionCommand("reboot", "systemctl reboot") }
            PowerAction { label: "Shutdown"; icon: bar.sessionIcon("shutdown", "system-shutdown-symbolic"); command: bar.sessionCommand("shutdown", "systemctl poweroff"); danger: true }
            PowerAction { label: "Idle settings"; icon: "preferences-system-symbolic"; onClicked: bar.toggleDropdown("idlesettings") }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                visible: bar.hasLaptopBattery()
                width: parent.width
                spacing: 4

                StatRow { name: "Battery"; value: UPower.displayDevice !== null ? `${Math.round(UPower.displayDevice.percentage)}%` : "-" }
                StatRow { name: "State"; value: bar.batteryState() }
                StatRow { name: "Time"; value: bar.batteryTime() }
            }

            Text {
                width: parent.width
                text: "Power profile"
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.weight: Font.DemiBold
            }

            Row {
                width: parent.width
                spacing: 6

                ProfileButton {
                    label: "Save"
                    active: PowerProfiles.profile === PowerProfile.PowerSaver
                    onClicked: bar.setPowerProfile(PowerProfile.PowerSaver, "power-saver")
                }

                ProfileButton {
                    label: "Balanced"
                    active: PowerProfiles.profile === PowerProfile.Balanced
                    onClicked: bar.setPowerProfile(PowerProfile.Balanced, "balanced")
                }

                ProfileButton {
                    label: "Perf"
                    visible: PowerProfiles.hasPerformanceProfile
                    active: PowerProfiles.profile === PowerProfile.Performance
                    onClicked: bar.setPowerProfile(PowerProfile.Performance, "performance")
                }
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "idlesettings"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                PanelTitle {
                    width: parent.width - 80
                    text: "Idle Settings"
                    elide: Text.ElideRight
                }

                CompactAction {
                    width: 72
                    label: "Apply"
                    command: ""
                    onClicked: bar.applyIdleSettings()
                }
            }

            Text {
                width: parent.width
                text: idleSettings.value.length > 0 ? "Hypridle restarts when a value changes" : "Idle settings helper is unavailable"
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.panelMetaFontSize()
                wrapMode: Text.WordWrap
            }

            IdleSettingRow {
                title: "Lock"
                detail: "Lock the session after inactivity"
                enabledKey: "lockEnabled"
                timeoutKey: "lockTimeout"
                fallbackEnabled: true
                fallbackTimeout: 300
                minTimeout: 60
                maxTimeout: 7200
                stepMinutes: 1
            }

            IdleSettingRow {
                title: "Display off"
                detail: "Turn monitors off after inactivity"
                enabledKey: "displayEnabled"
                timeoutKey: "displayTimeout"
                fallbackEnabled: true
                fallbackTimeout: 600
                minTimeout: 60
                maxTimeout: 7200
                stepMinutes: 1
            }

            IdleSettingRow {
                title: "Suspend"
                detail: "Enter low-power sleep"
                enabledKey: "suspendEnabled"
                timeoutKey: "suspendTimeout"
                fallbackEnabled: true
                fallbackTimeout: 900
                minTimeout: 300
                maxTimeout: 14400
                stepMinutes: 5
            }

            IdleSettingRow {
                title: "Hibernate"
                detail: "Save memory to disk and power down"
                enabledKey: "hibernateEnabled"
                timeoutKey: "hibernateTimeout"
                fallbackEnabled: false
                fallbackTimeout: 1800
                minTimeout: 600
                maxTimeout: 28800
                stepMinutes: 5
            }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "media" && player !== null
        anchors.fill: parent

        Flickable {
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentHeight: mediaPanelContent.implicitHeight + 32

        Column {
            id: mediaPanelContent

            width: parent.width - 32
            x: 16
            y: 16
            spacing: 12

            Row {
                width: parent.width
                spacing: 14

                Rectangle {
                    width: 108
                    height: 108
                    radius: 12
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        fillMode: Image.PreserveAspectCrop
                        source: bar.mediaArtUrl()
                        visible: source.toString().length > 0
                    }

                    Text {
                        visible: bar.mediaArtUrl().length === 0
                        anchors.centerIn: parent
                        text: "♪"
                        color: Theme.fgMuted
                        font.pixelSize: bar.panelIconFontSize()
                        font.bold: true
                    }

                    Rectangle {
                        visible: bar.mediaArtUrl().length > 0
                        anchors.fill: parent
                        color: "transparent"
                        border.color: Theme.border
                        border.width: 1
                        radius: 10
                    }
                }

                Column {
                    width: parent.width - 122
                    height: 108
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 8
                        Text { width: parent.width - 78; text: bar.displayPlayer(player); color: Theme.accent; font.family: bar.appearanceFontFamily("label", ""); font.pixelSize: bar.panelLabelFontSize(); font.bold: true; elide: Text.ElideRight }
                        Text { width: 70; text: player && player.isPlaying ? "Playing" : "Paused"; color: Theme.fgMuted; font.family: bar.appearanceFontFamily("body", ""); font.pixelSize: bar.panelMetaFontSize(); horizontalAlignment: Text.AlignRight }
                    }

                    Text { width: parent.width; text: player ? player.trackTitle : ""; color: Theme.fg; font.pixelSize: bar.panelTitleFontSize(); font.bold: true; elide: Text.ElideRight; maximumLineCount: 1 }
                    Text { width: parent.width; text: bar.mediaSubtitle(); color: Theme.fgMuted; font.family: bar.appearanceFontFamily("body", ""); font.pixelSize: bar.panelBodyFontSize(); elide: Text.ElideRight; maximumLineCount: 1 }

                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            width: 42
                            text: `${bar.volumePercent()}%`
                            color: Theme.fgMuted
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.panelMetaFontSize()
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        VolumeSlider {
                            width: parent.width - 88
                            maximum: bar.maxVolume()
                            value: bar.currentVolume()
                            onMoved: function(nextValue) {
                                bar.setVolume(nextValue);
                            }
                        }

                        MediaIconControl {
                            icon: bar.volumeMuted() ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            fallbackLabel: bar.volumeMuted() ? "M" : "V"
                            active: bar.volumeMuted()
                            onClicked: bar.toggleMute()
                        }
                    }
                }
            }

            Row {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter

                MediaIconControl { icon: "media-playlist-shuffle-symbolic"; fallbackLabel: "S"; active: player && player.shuffle; enabled: bar.mediaSupportsShuffle(); onClicked: player.shuffle = !player.shuffle }
                MediaIconControl { icon: "media-skip-backward-symbolic"; fallbackLabel: "<"; enabled: bar.mediaCan("canGoPrevious"); onClicked: bar.mediaPrevious() }
                MediaIconControl { icon: player && player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; fallbackLabel: player && player.isPlaying ? "II" : ">"; enabled: bar.mediaCan("canTogglePlaying"); primary: true; onClicked: bar.mediaTogglePlaying() }
                MediaIconControl { icon: "media-skip-forward-symbolic"; fallbackLabel: ">"; enabled: bar.mediaCan("canGoNext"); onClicked: bar.mediaNext() }
                MediaIconControl {
                    icon: "media-playlist-repeat-symbolic"
                    fallbackLabel: "R"
                    active: player && player.loopState === MprisLoopState.Playlist
                    enabled: bar.mediaSupportsLoop()
                    onClicked: player.loopState = player.loopState === MprisLoopState.Playlist ? MprisLoopState.None : MprisLoopState.Playlist
                }
            }

            PowerAction {
                visible: playbackTool.value.length > 0
                label: `Open ${playbackTool.value}`
                icon: "media-playback-start-symbolic"
                command: playbackTool.value
            }

            Rectangle {
                visible: bar.mediaLyricsText().length > 0
                width: parent.width
                height: 92
                radius: 12
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        width: parent.width
                        text: "Lyrics"
                        color: Theme.accent
                        font.family: bar.appearanceFontFamily("label", "")
                        font.pixelSize: bar.panelLabelFontSize()
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: bar.mediaLyricsText()
                        color: Theme.fgMuted
                        font.family: bar.appearanceFontFamily("body", "")
                        font.pixelSize: bar.panelBodyFontSize()
                        lineHeight: 1.12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                visible: bar.mediaPlayers().length > 1
                width: parent.width
                spacing: 6

                Text {
                    width: 50
                    text: "Players"
                    color: Theme.fgMuted
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.weight: Font.DemiBold
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                }

                Flickable {
                    width: parent.width - 56
                    height: 30
                    clip: true
                    contentWidth: playerChips.implicitWidth

                    Row {
                        id: playerChips
                        spacing: 6

                        Repeater {
                            model: bar.mediaPlayers()

                            PlayerChip {
                                required property var modelData
                                mediaPlayer: modelData
                                active: bar.playerKey(modelData) === bar.playerKey(player)
                                onClicked: bar.selectPlayer(modelData)
                            }
                        }
                    }
                }
            }
        }
        }
    }

    DropPanel {
        visible: bar.openDropdown === "calendar"
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 8
                CalendarNav { text: "<"; onClicked: calendarMonthOffset-- }
                Pill { label: bar.monthTitle(); maxWidth: 150; onClicked: calendarPickerOpen = !calendarPickerOpen }
                CalendarNav {
                    text: "오늘"
                    width: 48
                    onClicked: {
                        calendarMonthOffset = 0;
                        selectedCalendarKey = bar.dateKey(new Date());
                        calendarPickerOpen = false;
                    }
                }
                CalendarNav { text: ">"; onClicked: calendarMonthOffset++ }
            }

            Row {
                width: parent.width
                spacing: 8
                Pill { label: bar.weekendSummary(); maxWidth: 130 }
                Pill { label: bar.nextHolidaySummary(); maxWidth: 170 }
            }

            Grid {
                columns: 7
                rowSpacing: 4
                columnSpacing: 4
                Repeater {
                    model: ["일", "월", "화", "수", "목", "금", "토"]
                    Text {
                        required property string modelData
                        width: 40
                        height: 22
                        text: modelData
                        color: modelData === "일" || modelData === "토" ? Theme.warning : Theme.fgMuted
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: bar.appearanceFontFamily("label", "")
                        font.pixelSize: bar.calendarTitleFontSize()
                    }
                }
                Repeater {
                    model: bar.calendarDays()
                    Rectangle {
                        required property var modelData
                        width: 40
                        height: 30
                        radius: 8
                        color: modelData.key === selectedCalendarKey ? Theme.accent : modelData.today ? Theme.surfaceHover : "transparent"
                        border.color: modelData.today ? Theme.accent : "transparent"
                        border.width: modelData.today ? 1 : 0

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: !modelData.currentMonth ? Theme.fgMuted : modelData.holiday ? Theme.danger : modelData.weekend ? Theme.warning : Theme.fg
                            font.family: bar.appearanceFontFamily("body", "")
                            font.pixelSize: bar.calendarDayFontSize()
                            font.bold: modelData.today || modelData.holiday
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: selectedCalendarKey = modelData.key
                        }
                    }
                }
            }

            Column {
                visible: calendarPickerOpen
                spacing: 8
                width: parent.width

                Row {
                    spacing: 8
                    CalendarNav { text: "<<"; onClicked: calendarMonthOffset -= 12 }
                    Text {
                        width: 190
                        text: Qt.formatDate(bar.viewedMonth(), "yyyy년")
                        color: Theme.fg
                        font.family: bar.appearanceFontFamily("label", "")
                        font.pixelSize: bar.calendarLabelFontSize()
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CalendarNav { text: ">>"; onClicked: calendarMonthOffset += 12 }
                }

                Grid {
                    columns: 3
                    rowSpacing: 6
                    columnSpacing: 6
                    Repeater {
                        model: 12
                        CalendarNav {
                            required property int index
                            width: 94
                            text: `${index + 1}월`
                            active: bar.viewedMonth().getMonth() === index
                            onClicked: {
                                const current = new Date();
                                calendarMonthOffset = (bar.viewedMonth().getFullYear() - current.getFullYear()) * 12 + index - current.getMonth();
                            }
                        }
                    }
                }

                CalendarNav {
                    width: parent.width
                    text: "완료"
                    active: true
                    onClicked: calendarPickerOpen = false
                }
            }

            Text {
                width: parent.width
                text: bar.selectedCalendarDetail()
                color: Theme.fgMuted
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.calendarDetailFontSize()
                elide: Text.ElideRight
            }
        }
    }

    }

    component Pill: Rectangle {
        property string label: ""
        property string iconSource: ""
        property int maxWidth: 9999
        signal clicked(int button)

        height: 24
        width: Math.min(maxWidth, content.implicitWidth + (iconSource.length > 0 ? 38 : 18))
        radius: 8
        color: mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: Theme.border
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: 6

            IconImage {
                visible: parent.parent.iconSource.length > 0
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 14
                source: parent.parent.iconSource
            }

            Text {
                id: content
                width: Math.min(implicitWidth, parent.parent.maxWidth - (parent.parent.iconSource.length > 0 ? 38 : 18))
                anchors.verticalCenter: parent.verticalCenter
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: parent.parent.label
                color: Theme.fg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.barLabelFontSize()
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: function(event) {
                parent.clicked(event.button);
            }
        }
    }

    component BarGroup: Rectangle {
        radius: bar.appearanceRounding(height / 2)
        color: Theme.bgAlt
        border.color: Theme.border
        border.width: 1
        opacity: bar.barOpacity()
    }

    component BarSystemModule: BarGroup {
        property int section: 2

        visible: bar.barEntryInSection("system", section, 2)
        height: 34
        width: systemSummary.implicitWidth + 22

        Row {
            id: systemSummary
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CPU"
                color: Theme.accent2
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.barLabelFontSize()
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cpuPercent.value || "0%"
                color: Theme.fg
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.barBodyFontSize()
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Theme.border
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MEM"
                color: Theme.accent2
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.barLabelFontSize()
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: memory.value || "-"
                color: Theme.fg
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.barBodyFontSize()
                font.weight: Font.Medium
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: bar.toggleDropdown("system")
        }
    }

    component BarPowerStatusModule: Item {
        property int section: 2

        visible: bar.barEntryInSection("power", section, 2)
        width: childrenRect.width
        height: 34

        BatteryPill {
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.statusEnabled("battery") && bar.hasLaptopBattery()
            onClicked: bar.toggleDropdown("power")
        }

        PowerProfilePill {
            anchors.verticalCenter: parent.verticalCenter
            visible: !bar.hasLaptopBattery()
            onClicked: bar.toggleDropdown("power")
        }
    }

    component BarStatusIconsModule: BarGroup {
        property int section: 2

        visible: bar.barEntryInSection("statusIcons", section, 2) && bar.visibleStatusItemCount() > 0
        height: 34
        width: statusItems.implicitWidth + 12

        Row {
            id: statusItems
            anchors.centerIn: parent
            spacing: 4

            StatusPill {
                visible: bar.statusEnabled("audio")
                icon: bar.volumeMuted() ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                fallbackLabel: "A"
                label: bar.volumeMuted() ? "mute" : `${bar.volumePercent()}%`
                active: bar.openDropdown === "audio"
                warning: bar.volumeMuted()
                onClicked: bar.toggleStatusDropdown("audio")
                onWheeled: function(deltaY) {
                    if (bar.scrollActionEnabled("volume"))
                        bar.adjustVolume(deltaY > 0 ? bar.audioIncrement() : -bar.audioIncrement());
                }
            }

            StatusButton {
                visible: bar.statusEnabled("microphone")
                icon: bar.sourceMuted() ? "microphone-disabled-symbolic" : "microphone-sensitivity-high-symbolic"
                fallbackLabel: "M"
                active: bar.openDropdown === "audio"
                warning: bar.sourceMuted()
                onClicked: bar.toggleStatusDropdown("audio")
            }

            StatusButton {
                visible: bar.statusEnabled("privacy") && bar.privacyActive()
                icon: bar.privacyIcon()
                fallbackLabel: "P"
                active: true
                warning: true
                onClicked: bar.toggleStatusDropdown("quick")
            }

            StatusButton {
                visible: bar.statusEnabled("keyboard")
                label: bar.keyboardLabel()
                active: bar.openDropdown === "keyboard"
                onClicked: bar.toggleStatusDropdown("keyboard")
            }

            StatusButton {
                visible: bar.statusEnabled("lockStatus") && bar.capsLockOn()
                label: "C"
                active: true
                warning: true
                onClicked: bar.toggleStatusDropdown("keyboard")
            }

            StatusButton {
                visible: bar.statusEnabled("lockStatus") && bar.numLockOn()
                label: "1"
                active: true
                warning: true
                onClicked: bar.toggleStatusDropdown("keyboard")
            }

            StatusPill {
                visible: bar.networkStatusVisible()
                icon: bar.networkIcon()
                fallbackLabel: "N"
                label: bar.networkShortLabel()
                active: bar.openDropdown === "network"
                warning: bar.networkOffline()
                onClicked: bar.toggleStatusDropdown("network")
            }

            StatusPill {
                visible: bar.statusEnabled("weather") && bar.weatherAvailable()
                icon: bar.weatherIcon()
                fallbackLabel: "W"
                label: bar.weatherLabel()
                onClicked: bar.toggleStatusDropdown("quick")
            }

            StatusButton {
                visible: bar.statusEnabled("bluetooth") && bar.bluetoothAvailable()
                icon: bar.bluetoothIcon()
                fallbackLabel: "B"
                active: bar.openDropdown === "bluetooth" || bar.bluetoothConnectedCount() > 0
                warning: bar.bluetoothAvailable() && !bar.bluetoothEnabled()
                onClicked: bar.toggleStatusDropdown("bluetooth")
            }

            StatusPill {
                visible: bar.statusEnabled("brightness") && backlight.value.length > 0
                icon: "display-brightness-symbolic"
                fallbackLabel: "L"
                label: `${bar.brightnessPercent()}%`
                active: bar.openDropdown === "brightness"
                onClicked: bar.toggleStatusDropdown("brightness")
                onWheeled: function(deltaY) {
                    if (bar.scrollActionEnabled("brightness"))
                        bar.adjustBrightness(deltaY > 0 ? bar.brightnessIncrement() : -bar.brightnessIncrement());
                }
            }

            StatusButton {
                visible: bar.statusEnabled("idleInhibit") && bar.idleInhibitEnabled()
                icon: "night-light-disabled-symbolic"
                fallbackLabel: "I"
                active: true
                warning: true
                onClicked: bar.toggleStatusDropdown("quick")
            }

            StatusPill {
                visible: bar.statusEnabled("updates") && bar.updateCount() > 0
                icon: "software-update-available-symbolic"
                fallbackLabel: "U"
                label: `${bar.updateCount()}`
                active: bar.openDropdown === "updates"
                warning: true
                onClicked: bar.toggleStatusDropdown("updates")
            }

            StatusPill {
                visible: bar.statusEnabled("temperature") && bar.temperatureHot()
                icon: "preferences-system-symbolic"
                fallbackLabel: "T"
                label: temperature.value
                active: true
                warning: !bar.temperatureDanger()
                danger: bar.temperatureDanger()
                onClicked: bar.toggleStatusDropdown("system")
            }
        }
    }

    component BarTrayModule: BarGroup {
        property int section: 2

        visible: bar.barEntryInSection("tray", section, 2) && bar.visibleTrayItemCount() > 0 && !bar.fullscreenQuiet()
        height: bar.trayCompactEnabled() ? 30 : 34
        width: trayItems.implicitWidth + 12
        color: bar.trayBackgroundEnabled() ? Theme.bgAlt : "transparent"
        border.color: bar.trayBackgroundEnabled() ? Theme.border : "transparent"
        border.width: bar.trayBackgroundEnabled() ? 1 : 0

        Row {
            id: trayItems
            anchors.centerIn: parent
            spacing: bar.trayCompactEnabled() ? 2 : 4

            Repeater {
                model: SystemTray.items

                IconButton {
                    id: trayButton

                    required property var modelData
                    visible: bar.trayItemVisible(modelData)
                    width: bar.trayCompactEnabled() ? 24 : 28
                    height: bar.trayCompactEnabled() ? 24 : 28
                    iconSize: bar.trayIconSize()
                    iconSource: bar.trayItemIconSource(modelData)
                    label: bar.trayItemLabel(modelData)
                    fallbackLabel: ""
                    tintIcon: bar.trayRecolourEnabled()

                    onClicked: function(button) {
                        const point = trayButton.mapToItem(null, 0, 0);
                        bar.handleTrayItemClick(modelData, button, point.x + trayButton.width - bar.dropdownWidth());
                    }
                }
            }
        }
    }

    component BarAppearanceModule: ThemeButton {
        property int section: 2

        visible: bar.barEntryInSection("appearance", section, 2) && !bar.fullscreenQuiet()
        active: bar.openDropdown === "theme"
        onClicked: bar.toggleDropdown("theme")
    }

    component BarQuickUtilitiesModule: IconButton {
        property int section: 2

        width: 34
        height: 34
        visible: bar.barEntryInSection("quickUtilities", section, 2) && !bar.fullscreenQuiet()
        icon: "preferences-system-symbolic"
        fallbackLabel: "Q"
        active: bar.openDropdown === "quick"
        onClicked: bar.toggleDropdown("quick")
    }

    component BarNexusModule: IconButton {
        property int section: 2

        width: 34
        height: 34
        visible: bar.barEntryInSection("nexus", section, 2) && bar.nexusEnabled() && !bar.fullscreenQuiet()
        icon: "network-wireless-symbolic"
        fallbackLabel: "X"
        active: bar.openDropdown === "nexus"
        warning: bar.networkOffline()
        onClicked: bar.toggleDropdown("nexus")
    }

    component BarNotificationsModule: IconButton {
        property int section: 2

        width: 34
        height: 34
        visible: bar.barEntryInSection("notifications", section, 2) && !bar.fullscreenQuiet()
        icon: bar.dndEnabled() ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
        fallbackLabel: "N"
        warning: bar.dndEnabled()
        onClicked: bar.run("qs ipc call notifications toggle")

        Rectangle {
            visible: Number(notificationCount.value) > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: -2
            width: Math.max(16, countLabel.implicitWidth + 8)
            height: 16
            radius: 8
            color: Theme.danger
            border.color: Theme.bg
            border.width: 1

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: Number(notificationCount.value) > 9 ? "9+" : notificationCount.value
                color: Theme.accentFg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.barBadgeFontSize()
                font.weight: Font.DemiBold
            }
        }
    }

    component BarPowerButtonModule: IconButton {
        property int section: 2

        width: 34
        height: 34
        visible: bar.barEntryInSection("power", section, 2)
        icon: "system-shutdown-symbolic"
        fallbackLabel: "P"
        danger: true
        onClicked: bar.toggleDropdown("power")
    }

    component WorkspaceButton: Rectangle {
        id: workspaceButton

        property int workspaceId: 1
        property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId
        property bool occupied: bar.workspaceOccupied(workspaceId)
        property int windowCount: bar.workspaceWindowCount(workspaceId)
        property var windowIcons: bar.workspaceWindowEntries(workspaceId)
        property bool activeIndicator: bar.workspaceActiveIndicatorEnabled()
        property bool occupiedBg: bar.workspaceOccupiedBgEnabled()
        property bool showWindows: bar.workspaceShowWindowsEnabled()

        width: Math.max(active && activeIndicator ? 30 : occupied && occupiedBg ? 28 : 22, workspaceContents.implicitWidth + 14)
        height: 24
        radius: height / 2
        color: active && activeIndicator ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : occupied && occupiedBg ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        border.color: active && activeIndicator ? Theme.accent : occupied && occupiedBg ? Theme.border : "transparent"
        border.width: (active && activeIndicator) || (occupied && occupiedBg) ? 1 : 0

        Behavior on width { NumberAnimation { duration: bar.appearanceDuration(120) } }
        Behavior on color { ColorAnimation { duration: bar.appearanceDuration(120) } }

        Row {
            id: workspaceContents

            anchors.centerIn: parent
            spacing: 4

            Text {
                id: workspaceText

                anchors.verticalCenter: parent.verticalCenter
                text: bar.workspaceLabelText(workspaceButton.workspaceId, workspaceButton.active, workspaceButton.occupied)
                color: workspaceButton.active && workspaceButton.activeIndicator ? Theme.accentFg : workspaceButton.active ? Theme.accent : Theme.fgMuted
                font.family: bar.workspaceFontFamily()
                font.pixelSize: bar.barLabelFontSize()
                font.weight: workspaceButton.active ? Font.DemiBold : Font.Medium
            }

            Row {
                visible: workspaceButton.showWindows && workspaceButton.occupied && workspaceButton.windowIcons.length > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3

                Repeater {
                    model: workspaceButton.windowIcons

                    Rectangle {
                        required property var modelData

                        width: 14
                        height: 14
                        radius: 5
                        color: workspaceButton.active && workspaceButton.activeIndicator ? Qt.rgba(0, 0, 0, 0.16) : Theme.surface
                        border.color: workspaceButton.active && workspaceButton.activeIndicator ? Qt.rgba(0, 0, 0, 0.22) : Theme.border
                        border.width: 1
                        clip: true

                        IconImage {
                            id: workspaceWindowIcon

                            visible: source.toString().length > 0
                            anchors.centerIn: parent
                            implicitSize: 10
                            source: modelData.icon || ""
                        }

                        Text {
                            visible: !workspaceWindowIcon.visible
                            anchors.centerIn: parent
                            text: modelData.label || "•"
                            color: Theme.fgMuted
                            font.family: bar.workspaceFontFamily()
                            font.pixelSize: bar.barWorkspaceIconFontSize()
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Text {
                visible: workspaceButton.showWindows && workspaceButton.occupied && workspaceButton.windowCount > workspaceButton.windowIcons.length
                anchors.verticalCenter: parent.verticalCenter
                text: `+${workspaceButton.windowCount - workspaceButton.windowIcons.length}`
                color: workspaceButton.active && workspaceButton.activeIndicator ? Theme.accentFg : Theme.fgMuted
                font.family: bar.workspaceFontFamily()
                font.pixelSize: bar.barBadgeFontSize()
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled
            onClicked: Hyprland.dispatch("workspace " + parent.workspaceId)
        }
    }

    component IconButton: Rectangle {
        id: iconButton

        property string icon: ""
        property string iconSource: ""
        property string label: ""
        property string fallbackLabel: "•"
        property bool tintIcon: true
        property bool danger: false
        property bool active: false
        property bool warning: false
        property int iconSize: 16
        property int horizontalPadding: 6
        property int verticalPadding: 6
        signal clicked
        signal wheeled(int deltaY)

        width: Math.max(28, Math.ceil(Math.max(iconButton.iconSize, labelText.visible ? labelText.implicitWidth : 0) + horizontalPadding * 2))
        height: Math.max(28, Math.ceil(Math.max(iconButton.iconSize, labelText.visible ? labelText.implicitHeight : 0) + verticalPadding * 2))
        radius: height / 2
        color: active ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : danger ? Qt.rgba(1, 0.42, 0.42, 0.12) : "transparent"
        border.color: danger ? Theme.danger : warning ? Theme.warning : active ? Theme.accent : "transparent"
        border.width: danger || warning || active ? 1 : 0

        IconImage {
            id: iconImage

            visible: source.toString().length > 0
            anchors.centerIn: parent
            implicitSize: parent.iconSize
            source: parent.iconSource.length > 0 ? parent.iconSource : bar.themedIcon(parent.icon)
            opacity: parent.tintIcon ? 0 : 1
        }

        ColorOverlay {
            visible: parent.tintIcon && iconImage.source.toString().length > 0
            anchors.fill: iconImage
            source: iconImage
            color: active ? Theme.accentFg : danger ? Theme.danger : warning ? Theme.warning : Theme.fg
        }

        Text {
            id: labelText

            visible: parent.label.length > 0 || iconImage.source.toString().length === 0 || iconImage.status === Image.Error
            anchors.centerIn: parent
            text: parent.label.length > 0 ? parent.label : parent.fallbackLabel
            color: active ? Theme.accentFg : danger ? Theme.danger : warning ? Theme.warning : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.barLabelFontSize()
            font.bold: true
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
            onWheel: function(event) {
                parent.wheeled(event.angleDelta.y);
            }
        }
    }

    component StatusButton: IconButton {
        anchors.verticalCenter: parent.verticalCenter
        tintIcon: true
    }

    component StatusPill: Rectangle {
        property string icon: ""
        property string label: ""
        property string fallbackLabel: "•"
        property bool active: false
        property bool warning: false
        property bool danger: false
        signal clicked
        signal wheeled(int deltaY)

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(42, statusPillRow.implicitWidth + 14)
        height: 28
        radius: height / 2
        color: active && !warning && !danger ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: danger ? Theme.danger : warning ? Theme.warning : active ? Theme.accent : "transparent"
        border.width: danger || warning || active ? 1 : 0

        Row {
            id: statusPillRow
            anchors.centerIn: parent
            spacing: 5

            Item {
                width: 15
                height: 15
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: statusPillIcon
                    anchors.fill: parent
                    source: bar.themedIcon(icon)
                    opacity: 0
                }

                ColorOverlay {
                    visible: statusPillIcon.source.toString().length > 0
                    anchors.fill: statusPillIcon
                    source: statusPillIcon
                    color: active && !warning && !danger ? Theme.accentFg : danger ? Theme.danger : warning ? Theme.warning : Theme.fg
                }

                Text {
                    visible: statusPillIcon.source.toString().length === 0 || statusPillIcon.status === Image.Error
                    anchors.centerIn: parent
                    text: fallbackLabel
                    color: active && !warning && !danger ? Theme.accentFg : danger ? Theme.danger : warning ? Theme.warning : Theme.fg
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.barLabelFontSize()
                    font.bold: true
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: active && !warning && !danger ? Theme.accentFg : danger ? Theme.danger : warning ? Theme.warning : Theme.fg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.barLabelFontSize()
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
            onWheel: function(event) {
                parent.wheeled(event.angleDelta.y);
            }
        }
    }

    component ThemeButton: Rectangle {
        property bool active: false
        signal clicked

        width: 34
        height: 34
        radius: height / 2
        color: active ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: active ? Theme.accent : "transparent"
        border.width: active ? 1 : 0

        Row {
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: [Theme.accent, Theme.accent2, Theme.success]

                Rectangle {
                    required property color modelData

                    width: 6
                    height: 14
                    radius: 3
                    color: parent.parent.active ? Theme.accentFg : modelData
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component BatteryPill: Rectangle {
        property int percentage: UPower.displayDevice !== null ? Math.round(UPower.displayDevice.percentage) : 0
        signal clicked

        width: 92
        height: 34
        radius: bar.appearanceRounding(height / 2)
        color: batteryMouse.containsMouse ? Theme.surfaceHover : Theme.bgAlt
        border.color: Theme.border
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 8
            radius: 4
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(2, parent.width * percentage / 100)
                radius: 4
                color: bar.batteryAccent(percentage)
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: `${bar.batteryPrefix()}${percentage}%`
            color: Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.barLabelFontSize()
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: batteryMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component PowerProfilePill: Rectangle {
        signal clicked

        property string label: bar.powerProfileLabel()
        property int horizontalPadding: 10
        property int maxPillWidth: 148

        width: Math.min(maxPillWidth, Math.max(66, profileIconSlot.width + profileContent.spacing + profileLabel.implicitWidth + horizontalPadding * 2))
        height: 34
        radius: bar.appearanceRounding(height / 2)
        color: profileMouse.containsMouse ? Theme.surfaceHover : Theme.bgAlt
        border.color: Theme.border
        border.width: 1

        Row {
            id: profileContent
            anchors.centerIn: parent
            spacing: 6

            Item {
                id: profileIconSlot
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: profileIcon
                    anchors.fill: parent
                    source: bar.themedIcon(bar.powerProfileIcon())
                    opacity: 0
                }

                ColorOverlay {
                    visible: profileIcon.source.toString().length > 0
                    anchors.fill: profileIcon
                    source: profileIcon
                    color: PowerProfiles.profile === PowerProfile.PowerSaver ? Theme.success : PowerProfiles.profile === PowerProfile.Performance ? Theme.warning : Theme.accent2
                }
            }

            Text {
                id: profileLabel
                width: Math.max(0, parent.parent.width - parent.parent.horizontalPadding * 2 - profileIconSlot.width - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                color: Theme.fg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.barLabelFontSize()
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: profileMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component DropPanel: Rectangle {
        property int motionMs: bar.appearanceDuration(220)

        radius: bar.appearanceRounding(14)
        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        z: 30
        opacity: visible ? bar.panelOpacity() : 0
        scale: visible ? 1 : 0.965
        transformOrigin: Item.Top

        Behavior on opacity { NumberAnimation { duration: motionMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: bar.appearanceDuration(260); easing.type: Easing.OutCubic } }
    }

    component PanelTitle: Text {
        color: Theme.fg
        font.family: bar.appearanceFontFamily("title", bar.appearanceFontFamily("label", ""))
        font.pixelSize: bar.panelTitleFontSize()
        font.bold: true
    }

    component StatRow: Row {
        property string name: ""
        property string value: ""

        width: parent.width
        Text { width: parent.width / 2; text: name; color: Theme.fgMuted; font.family: bar.appearanceFontFamily("body", ""); font.pixelSize: bar.panelBodyFontSize() }
        Text { width: parent.width / 2; text: value; color: Theme.fg; font.family: bar.appearanceFontFamily("body", ""); font.pixelSize: bar.panelBodyFontSize(); horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
    }

    component DashboardMetric: Rectangle {
        property string title: ""
        property string value: ""
        property color accent: Theme.accent
        property int columns: 3

        width: (parent.width - (Math.max(1, columns) - 1) * parent.spacing) / Math.max(1, columns)
        height: 54
        radius: 12
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        Column {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 3

            Text {
                width: parent.width
                text: title
                color: accent
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: value
                color: Theme.fg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelTitleFontSize()
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    component ResourceMeter: Rectangle {
        property string title: ""
        property string detail: ""
        property int percent: 0
        property color accent: Theme.accent

        width: parent.width
        height: 42
        radius: 12
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Row {
                width: parent.width

                Text {
                    width: parent.width / 2
                    text: title
                    color: Theme.fg
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width / 2
                    text: detail
                    color: Theme.fgMuted
                    font.family: bar.appearanceFontFamily("body", "")
                    font.pixelSize: bar.panelMetaFontSize()
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(6, parent.width * Math.max(0, Math.min(100, percent)) / 100)
                    radius: 3
                    color: accent
                }
            }
        }
    }

    component PowerAction: Rectangle {
        property string label: ""
        property string icon: ""
        property string iconSource: ""
        property string command: ""
        property bool danger: false
        signal clicked

        width: parent.width
        height: 32
        radius: 8
        color: mouse.containsMouse ? Theme.surfaceHover : "transparent"

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: powerIcon
                    anchors.fill: parent
                    visible: source.toString().length > 0
                    implicitSize: 16
                    source: iconSource.length > 0 ? iconSource : bar.themedIcon(icon)
                    opacity: 0
                }

                ColorOverlay {
                    visible: powerIcon.source.toString().length > 0
                    anchors.fill: powerIcon
                    source: powerIcon
                    color: danger ? Theme.danger : Theme.fg
                }
            }

            Text {
                width: parent.width - 26
                text: label
                color: danger ? Theme.danger : Theme.fg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (command.length > 0) {
                    bar.closeDropdown();
                    bar.run(command);
                } else {
                    parent.clicked();
                }
            }
        }
    }

    component UtilityAction: Rectangle {
        property string title: ""
        property string detail: ""
        property string icon: ""
        property string command: ""
        property bool active: false
        signal clicked

        width: parent.width
        height: 48
        radius: 12
        color: active ? Theme.surfaceHover : mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: active ? Theme.accent : Theme.border
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Item {
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: utilityIcon
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: bar.themedIcon(icon)
                    opacity: 0
                }

                ColorOverlay {
                    visible: utilityIcon.source.toString().length > 0
                    anchors.fill: utilityIcon
                    source: utilityIcon
                    color: active ? Theme.accent : Theme.fg
                }

                Text {
                    visible: utilityIcon.source.toString().length === 0 || utilityIcon.status === Image.Error
                    anchors.centerIn: parent
                    text: "•"
                    color: active ? Theme.accent : Theme.fg
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelTitleFontSize()
                    font.bold: true
                }
            }

            Column {
                width: parent.width - 34
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: title
                    color: Theme.fg
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: detail
                    color: Theme.fgMuted
                    font.family: bar.appearanceFontFamily("body", "")
                    font.pixelSize: bar.panelMetaFontSize()
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (parent.command.length > 0)
                    bar.run(parent.command);
                parent.clicked();
            }
        }
    }

    component IdleSettingRow: Rectangle {
        property string title: ""
        property string detail: ""
        property string enabledKey: ""
        property string timeoutKey: ""
        property bool fallbackEnabled: true
        property int fallbackTimeout: 300
        property int minTimeout: 60
        property int maxTimeout: 7200
        property int stepMinutes: 1
        property bool settingEnabled: bar.idleBool(enabledKey, fallbackEnabled)

        width: parent.width
        height: 70
        radius: 10
        color: Theme.surface
        border.color: settingEnabled ? Theme.border : Theme.bgAlt
        border.width: 1
        opacity: idleSettings.value.length > 0 ? 1 : 0.5

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Column {
                width: parent.width - 166
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: title
                    color: Theme.fg
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: detail
                    color: Theme.fgMuted
                    font.family: bar.appearanceFontFamily("body", "")
                    font.pixelSize: bar.panelMetaFontSize()
                    elide: Text.ElideRight
                }
            }

            Row {
                width: 156
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IdleSmallButton {
                    label: settingEnabled ? "On" : "Off"
                    active: settingEnabled
                    onClicked: bar.toggleIdleSetting(enabledKey, fallbackEnabled)
                }

                IdleSmallButton {
                    label: "-"
                    enabled: settingEnabled
                    onClicked: bar.adjustIdleTimeout(timeoutKey, fallbackTimeout, -stepMinutes, minTimeout, maxTimeout)
                }

                Text {
                    width: 52
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.idleMinutesLabel(timeoutKey, fallbackTimeout)
                    color: settingEnabled ? Theme.fg : Theme.fgMuted
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                IdleSmallButton {
                    label: "+"
                    enabled: settingEnabled
                    onClicked: bar.adjustIdleTimeout(timeoutKey, fallbackTimeout, stepMinutes, minTimeout, maxTimeout)
                }
            }
        }
    }

    component IdleSmallButton: Rectangle {
        property string label: ""
        property bool active: false
        signal clicked

        width: 30
        height: 28
        radius: 8
        color: active ? Theme.accent : buttonMouse.containsMouse && enabled ? Theme.surfaceHover : Theme.bgAlt
        border.color: active ? Theme.accent : Theme.border
        border.width: 1
        opacity: enabled ? 1 : 0.45

        Text {
            anchors.centerIn: parent
            width: parent.width - 6
            text: parent.label
            color: parent.active ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.panelLabelFontSize()
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled
            onClicked: parent.clicked()
        }
    }

    component ClipboardHistoryItem: Rectangle {
        property string value: ""
        signal clicked

        width: parent.width
        height: 42
        radius: 10
        color: clipboardItemMouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: Theme.border
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: clipboardItemIcon
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: bar.themedIcon("edit-paste-symbolic")
                    opacity: 0
                }

                ColorOverlay {
                    visible: clipboardItemIcon.source.toString().length > 0
                    anchors.fill: clipboardItemIcon
                    source: clipboardItemIcon
                    color: Theme.fg
                }
            }

            Text {
                width: parent.width - 28
                anchors.verticalCenter: parent.verticalCenter
                text: bar.clipboardPreview(value)
                color: Theme.fg
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.panelBodyFontSize()
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: clipboardItemMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component ProfileImageItem: Rectangle {
        property string path: ""
        signal clicked

        width: parent.width
        height: 50
        radius: 10
        color: profileImageItemMouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: Theme.border
        border.width: 1
        clip: true

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Theme.bgAlt
                border.color: Theme.border
                border.width: 1
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: path.length > 0 ? "file://" + path : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Text {
                width: parent.width - 46
                anchors.verticalCenter: parent.verticalCenter
                text: bar.profileImageName(path)
                color: Theme.fg
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.panelBodyFontSize()
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: profileImageItemMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component WindowAction: Rectangle {
        property string title: ""
        property string icon: ""
        property string command: ""

        width: (parent.width - 6) / 2
        height: 36
        radius: 10
        color: mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: Theme.border
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: 8

            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: windowActionIcon
                    anchors.fill: parent
                    source: bar.themedIcon(icon)
                    opacity: 0
                }

                ColorOverlay {
                    visible: windowActionIcon.source.toString().length > 0
                    anchors.fill: windowActionIcon
                    source: windowActionIcon
                    color: Theme.fg
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: title
                color: Theme.fg
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                bar.closeDropdown();
                bar.run(parent.command);
            }
        }
    }

    component CompactAction: Rectangle {
        property string label: ""
        property string command: ""
        property bool danger: false
        signal clicked

        width: (parent.width - 12) / 3
        height: 30
        radius: 9
        color: mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: danger ? Theme.danger : Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            width: parent.width - 10
            text: parent.label
            color: parent.danger ? Theme.danger : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.panelLabelFontSize()
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                bar.run(parent.command);
                parent.clicked();
            }
        }
    }

    component ListAction: Rectangle {
        property string title: ""
        property string detail: ""
        property string command: ""
        signal clicked

        height: 38
        radius: 10
        color: mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: Theme.border
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Column {
                width: parent.width - 78
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: title
                    color: Theme.fg
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: detail
                    color: Theme.fgMuted
                    font.family: bar.appearanceFontFamily("body", "")
                    font.pixelSize: bar.panelMetaFontSize()
                    elide: Text.ElideRight
                }
            }

            Text {
                width: 50
                anchors.verticalCenter: parent.verticalCenter
                text: "connect"
                color: Theme.accent
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelMetaFontSize()
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                bar.run(parent.command);
                parent.clicked();
            }
        }
    }

    component ProfileButton: Rectangle {
        property string label: ""
        property bool active: false
        signal clicked

        width: visible ? (PowerProfiles.hasPerformanceProfile ? (parent.width - 12) / 3 : (parent.width - 6) / 2) : 0
        height: 30
        radius: 9
        color: active ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: active ? Theme.accent : Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            width: parent.width - 10
            text: parent.label
            color: parent.active ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.panelLabelFontSize()
            font.weight: parent.active ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component ThemeSectionTitle: Text {
        width: parent.width
        height: 20
        color: Theme.fgMuted
        font.family: bar.appearanceFontFamily("label", "")
        font.pixelSize: bar.panelLabelFontSize()
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
    }

    component ThemeModeButton: Rectangle {
        property string label: ""
        property bool active: false
        signal clicked

        width: (parent.width - 8) / 2
        height: 34
        radius: 10
        color: active ? Theme.accent : mouse.containsMouse && enabled ? Theme.surfaceHover : Theme.surface
        border.color: active ? Theme.accent : Theme.border
        border.width: 1
        opacity: enabled ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            text: parent.label
            color: parent.active ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.panelLabelFontSize()
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled && !parent.active
            onClicked: parent.clicked()
        }
    }

    component TrayMenuHeader: Rectangle {
        property string title: "Tray"
        signal clicked

        width: parent.width
        height: 32
        radius: 8
        color: mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: Theme.border
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: "<"
                color: Theme.accent
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: parent.width - 28
                text: title
                color: Theme.fg
                elide: Text.ElideRight
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component TrayMenuItem: Rectangle {
        property var entry
        property bool checked: entry && entry.checkState === Qt.Checked
        signal clicked

        width: parent.width
        height: entry && entry.isSeparator ? 7 : 32
        radius: 8
        color: !entry || entry.isSeparator ? "transparent" : checked ? Theme.surfaceHover : mouse.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: checked ? Theme.accent : "transparent"
        border.width: checked ? 1 : 0
        opacity: !entry || entry.enabled ? 1 : 0.45

        Rectangle {
            visible: entry && entry.isSeparator
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Theme.border
        }

        Row {
            visible: entry && !entry.isSeparator
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: menuIcon
                    visible: source.toString().length > 0
                    anchors.centerIn: parent
                    implicitSize: 15
                    source: entry && entry.icon ? bar.trayIconSource(entry.icon) : ""
                }

                Text {
                    visible: !menuIcon.visible && checked
                    anchors.centerIn: parent
                    text: "✓"
                    color: Theme.accent
                    font.family: bar.appearanceFontFamily("label", "")
                    font.pixelSize: bar.panelLabelFontSize()
                    font.bold: true
                }
            }

            Text {
                width: parent.width - 60
                anchors.verticalCenter: parent.verticalCenter
                text: entry ? entry.text : ""
                color: Theme.fg
                font.family: bar.appearanceFontFamily("body", "")
                font.pixelSize: bar.panelBodyFontSize()
                elide: Text.ElideRight
            }

            Text {
                visible: entry && entry.hasChildren
                anchors.verticalCenter: parent.verticalCenter
                text: ">"
                color: Theme.accent
                font.family: bar.appearanceFontFamily("label", "")
                font.pixelSize: bar.panelLabelFontSize()
                font.bold: true
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: entry && !entry.isSeparator && entry.enabled
            onClicked: parent.clicked()
        }
    }

    component MediaControl: Rectangle {
        property string text: ""
        property bool active: false
        property bool primary: false
        signal clicked

        width: primary ? 40 : 32
        height: primary ? 34 : 30
        radius: 10
        color: active || primary ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: active || primary ? Theme.accent : Theme.border
        border.width: 1
        opacity: enabled ? 1 : 0.42

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.active || parent.primary ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: parent.primary ? bar.panelTitleFontSize() : bar.panelLabelFontSize()
            font.bold: parent.active || parent.primary
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled
            onClicked: parent.clicked()
        }
    }

    component MediaIconControl: Rectangle {
        property string icon: ""
        property string fallbackLabel: "•"
        property bool active: false
        property bool primary: false
        signal clicked

        width: primary ? 42 : 34
        height: primary ? 34 : 30
        radius: 10
        color: active || primary ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: active || primary ? Theme.accent : Theme.border
        border.width: 1
        opacity: enabled ? 1 : 0.42

        IconImage {
            id: controlIcon
            visible: source.toString().length > 0
            anchors.centerIn: parent
            implicitSize: primary ? 18 : 15
            source: bar.themedIcon(parent.icon)
            opacity: 0
        }

        ColorOverlay {
            visible: controlIcon.source.toString().length > 0
            anchors.fill: controlIcon
            source: controlIcon
            color: parent.active || parent.primary ? Theme.accentFg : Theme.fg
        }

        Text {
            visible: controlIcon.source.toString().length === 0 || controlIcon.status === Image.Error
            anchors.centerIn: parent
            text: parent.fallbackLabel
            color: parent.active || parent.primary ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: parent.primary ? bar.panelLabelFontSize() : bar.panelMetaFontSize()
            font.bold: parent.active || parent.primary
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabled
            onClicked: parent.clicked()
        }
    }

    component PlayerChip: Rectangle {
        property var mediaPlayer
        property bool active: false
        signal clicked

        width: Math.min(150, playerName.implicitWidth + 28)
        height: 28
        radius: 10
        color: active ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: active ? Theme.accent : Theme.border
        border.width: 1

        Text {
            id: playerName
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: bar.displayPlayer(parent.mediaPlayer)
            color: parent.active ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.panelLabelFontSize()
            font.weight: parent.active ? Font.DemiBold : Font.Medium
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component VolumeSlider: Item {
        property real value: 0
        property real maximum: 1.5
        signal moved(real nextValue)

        height: 30

        function valueFromX(mouseX) {
            return Math.max(0, Math.min(maximum, mouseX / width * maximum));
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(6, parent.width * Math.min(1, value / maximum))
                radius: 3
                color: Theme.accent
            }
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(1, value / maximum) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: volumeMouse.containsMouse || volumeMouse.pressed ? 14 : 12
            height: width
            radius: width / 2
            color: Theme.fg
            border.color: Theme.accent
            border.width: 2
        }

        MouseArea {
            id: volumeMouse
            anchors.fill: parent
            hoverEnabled: true
            onPressed: parent.moved(parent.valueFromX(mouse.x))
            onPositionChanged: if (pressed) parent.moved(parent.valueFromX(mouse.x))
        }
    }

    component CalendarNav: Rectangle {
        property string text: ""
        property bool active: false
        signal clicked

        width: 38
        height: 28
        radius: 8
        color: active ? Theme.accent : mouse.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: active ? Theme.accent : Theme.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.active ? Theme.accentFg : Theme.fg
            font.family: bar.appearanceFontFamily("label", "")
            font.pixelSize: bar.calendarLabelFontSize()
            font.bold: parent.active
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }
}
