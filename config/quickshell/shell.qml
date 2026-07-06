//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "components"
import "Theme.js" as Theme

ShellRoot {
    id: root

    property bool launcherOpen: false
    property string launcherQuery: ""
    property int launcherIndex: 0
    property var launcherApps: []
    property var launcherAppIndex: []
    property string shellConfigRaw: ""
    property var shellConfigCache: ({})
    property string calcExpression: ""
    property string calcResult: ""
    property bool keybindsOpen: false
    property bool notificationsEnabled: notificationsFlag.value === "true"
    property string drawerRequest: ""
    property int drawerNonce: 0
    readonly property string fallbackAppIcon: "file:///usr/share/icons/Adwaita/symbolic/categories/applications-utilities-symbolic.svg"

    function shellConfigObject() {
        if (shellConfig.value === shellConfigRaw)
            return shellConfigCache;

        shellConfigRaw = shellConfig.value;
        if (shellConfigRaw.length === 0) {
            shellConfigCache = ({});
            return ({});
        }

        try {
            shellConfigCache = JSON.parse(shellConfigRaw);
        } catch (error) {
            shellConfigCache = ({});
        }

        return shellConfigCache;
    }

    function configValue(path, fallbackValue) {
        const parts = path.split(".");
        let cursor = shellConfigObject();

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
        return configNumber("appearance.font.scale", 1, 0.5, 2.5);
    }

    function fontTokenSize(path, fallbackValue, minValue, maxValue, localScale) {
        const base = configNumber(path, fallbackValue, minValue, maxValue);
        const scale = Number.isFinite(Number(localScale)) ? Number(localScale) : 1;
        return Math.max(minValue || 7, Math.round(base * scale * appearanceFontScale()));
    }

    function launcherFontScale() {
        return configNumber("launcher.font.scale", 1, 0.5, 2.5);
    }

    function launcherTitleFontSize() {
        return fontTokenSize("launcher.font.titleSize", 9, 7, 36, launcherFontScale());
    }

    function launcherBodyFontSize() {
        return fontTokenSize("launcher.font.bodySize", 8, 6, 32, launcherFontScale());
    }

    function launcherInputFontSize() {
        return fontTokenSize("launcher.font.inputSize", 10, 7, 36, launcherFontScale());
    }

    function launcherHintFontSize() {
        return fontTokenSize("launcher.font.hintSize", 9, 7, 32, launcherFontScale());
    }

    function launcherMetaFontSize() {
        return fontTokenSize("launcher.font.metaSize", 7, 6, 28, launcherFontScale());
    }

    function configString(path, fallbackValue) {
        const value = configValue(path, fallbackValue);
        if (typeof value !== "string" || value.length === 0)
            return fallbackValue;
        return value;
    }

    function pickerCommand(freeze) {
        const key = freeze ? "picker.commands.openFreeze" : "picker.commands.open";
        const configured = configValue(key, "");
        if (Array.isArray(configured))
            return launcherCommandFromValue(configured);
        if (typeof configured === "string" && configured.length > 0)
            return configured;
        if (freeze)
            return "if command -v hyprpicker >/dev/null 2>&1; then hyprpicker -a -r; else notify-send 'Color picker unavailable' 'Install hyprpicker or configure picker.commands.openFreeze'; fi";
        return "if command -v hyprpicker >/dev/null 2>&1; then hyprpicker -a; else notify-send 'Color picker unavailable' 'Install hyprpicker or configure picker.commands.open'; fi";
    }

    function openPicker(freeze) {
        launcherRunner.exec(["sh", "-c", pickerCommand(freeze)]);
    }

    function drawerNames() {
        return ["dashboard", "media", "calendar", "system", "audio", "network", "nexus", "bluetooth", "keyboard", "brightness", "activewindow", "power", "idlesettings", "theme", "quick", "updates"];
    }

    function requestDrawer(drawer) {
        drawerRequest = `${drawer || ""}`.toLowerCase();
        drawerNonce += 1;
    }

    function activeMprisPlayer() {
        const players = Mpris.players.values;
        const preferred = configString("services.defaultPlayer", "").toLowerCase();

        if (preferred.length > 0) {
            for (let i = 0; i < players.length; i++) {
                const text = `${players[i].identity || ""} ${players[i].desktopEntry || ""} ${players[i].dbusName || ""}`.toLowerCase();
                if (text.indexOf(preferred) !== -1)
                    return players[i];
            }
        }

        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying)
                return players[i];
        }

        return players.length > 0 ? players[0] : null;
    }

    function mprisList() {
        const players = Mpris.players.values;
        const rows = [];
        for (let i = 0; i < players.length; i++)
            rows.push(`${players[i].identity || players[i].desktopEntry || players[i].dbusName || "player"}\t${players[i].trackTitle || ""}`);
        return rows.join("\n");
    }

    function mprisProperty(prop) {
        const player = activeMprisPlayer();
        if (!player)
            return "";

        if (prop === "trackTitle")
            return player.trackTitle || "";
        if (prop === "trackArtist")
            return player.trackArtist || "";
        if (prop === "trackAlbum")
            return player.trackAlbum || "";
        if (prop === "identity")
            return player.identity || "";
        if (prop === "desktopEntry")
            return player.desktopEntry || "";
        if (prop === "dbusName")
            return player.dbusName || "";
        if (prop === "isPlaying")
            return player.isPlaying ? "true" : "false";
        if (prop === "trackArtUrl")
            return player.trackArtUrl || "";

        const value = player[prop];
        if (value === undefined || value === null)
            return "";
        return `${value}`;
    }

    function mprisCall(action) {
        const player = activeMprisPlayer();
        if (!player)
            return;

        if (action === "playPause" && player.canTogglePlaying)
            player.togglePlaying();
        else if (action === "next" && player.canGoNext)
            player.next();
        else if (action === "previous" && player.canGoPrevious)
            player.previous();
        else if (action === "play" && player.play)
            player.play();
        else if (action === "pause" && player.pause)
            player.pause();
        else if (action === "stop" && player.stop)
            player.stop();
    }

    function launcherActionPrefix() {
        return configString("launcher.actionPrefix", ">");
    }

    function launcherSpecialPrefix() {
        return configString("launcher.specialPrefix", "@");
    }

    function launcherMaxShown() {
        return Math.round(configNumber("launcher.maxShown", 40, 1, 80));
    }

    function launcherMaxWallpapers() {
        return Math.round(configNumber("launcher.maxWallpapers", 9, 1, 40));
    }

    function launcherVimKeybinds() {
        return configBool("launcher.vimKeybinds", true);
    }

    function launcherDangerousActionsEnabled() {
        return configBool("launcher.enableDangerousActions", true);
    }

    function launcherShowOnHover() {
        return configBool("launcher.showOnHover", false);
    }

    function launcherHoverWidth() {
        return Math.round(configNumber("launcher.minHoverThreshold", configNumber("launcher.dragThreshold", 12, 4, 240), 4, 240));
    }

    function stringListValue(path) {
        const value = configValue(path, []);
        if (Array.isArray(value))
            return value.map(item => `${item}`);
        if (typeof value === "string" && value.length > 0)
            return [value];
        return [];
    }

    function matchConfiguredText(text, patterns) {
        const value = `${text || ""}`.toLowerCase();
        if (value.length === 0)
            return false;

        for (let i = 0; i < patterns.length; i++) {
            const pattern = `${patterns[i]}`.toLowerCase();
            if (pattern.length > 0 && (value === pattern || value.indexOf(pattern) !== -1))
                return true;
        }

        return false;
    }

    function itemMatchesAny(item, patterns) {
        return matchConfiguredText(item.name, patterns) || matchConfiguredText(item.id, patterns) || matchConfiguredText(item.comment, patterns);
    }

    function launcherItemHidden(item) {
        return item.kind === "app" && itemMatchesAny(item, stringListValue("launcher.hiddenApps"));
    }

    function launcherFavouriteRank(item) {
        if (item.kind !== "app")
            return 9999;

        const favourites = stringListValue("launcher.favouriteApps");
        for (let i = 0; i < favourites.length; i++) {
            if (itemMatchesAny(item, [favourites[i]]))
                return i;
        }

        return 9999;
    }

    function launcherUseFuzzy(kind) {
        if (kind === "app")
            return configBool("launcher.useFuzzy.apps", false);
        if (kind === "action")
            return configBool("launcher.useFuzzy.actions", false);
        if (kind === "scheme")
            return configBool("launcher.useFuzzy.schemes", false) || configBool("launcher.useFuzzy.variants", false);
        if (kind === "wallpaper")
            return configBool("launcher.useFuzzy.wallpapers", false);
        return false;
    }

    function fuzzyIncludes(haystack, query) {
        if (query.length === 0)
            return true;

        let cursor = 0;
        for (let i = 0; i < haystack.length && cursor < query.length; i++) {
            if (haystack[i] === query[cursor])
                cursor++;
        }

        return cursor === query.length;
    }

    function launcherSearchText(item) {
        return [
            item.name || "",
            item.comment || "",
            item.id || ""
        ].join(" ").toLowerCase();
    }

    function rebuildLauncherAppIndex() {
        const apps = DesktopEntries.applications.values;
        const hidden = stringListValue("launcher.hiddenApps");
        const favourites = stringListValue("launcher.favouriteApps");
        const items = [];

        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            const item = {
                kind: "app",
                name: app.name || "",
                comment: app.comment || "",
                id: app.id || "",
                icon: app.icon || "",
                app: app
            };

            item.searchText = launcherSearchText(item);
            if (itemMatchesAny(item, hidden))
                continue;

            item.favouriteRank = 9999;
            for (let j = 0; j < favourites.length; j++) {
                if (itemMatchesAny(item, [favourites[j]])) {
                    item.favouriteRank = j;
                    break;
                }
            }

            items.push(item);
        }

        items.sort((a, b) => {
            if (a.favouriteRank !== b.favouriteRank)
                return a.favouriteRank - b.favouriteRank;
            return `${a.name || a.id}`.localeCompare(`${b.name || b.id}`);
        });

        launcherAppIndex = items;
    }

    function launcherSchemes() {
        return [
            { name: "Default", id: "@ default", comment: "Dark color scheme", scheme: "default", mode: "dark", accent: "#3b82f6", accent2: "#88c0d0", bg: "#101216" },
            { name: "Default Light", id: "@ default-light", comment: "Light color scheme", scheme: "default-light", mode: "light", accent: "#2563eb", accent2: "#0891b2", bg: "#f8fafc" },
            { name: "Graphite", id: "@ graphite", comment: "Dark color scheme", scheme: "graphite", mode: "dark", accent: "#22c55e", accent2: "#38bdf8", bg: "#0d1117" },
            { name: "Catppuccin Mocha", id: "@ catppuccin-mocha", comment: "Dark color scheme", scheme: "catppuccin-mocha", mode: "dark", accent: "#89b4fa", accent2: "#cba6f7", bg: "#1e1e2e" },
            { name: "Catppuccin Latte", id: "@ catppuccin-latte", comment: "Light color scheme", scheme: "catppuccin-latte", mode: "light", accent: "#1e66f5", accent2: "#8839ef", bg: "#eff1f5" },
            { name: "Rose Pine", id: "@ rose-pine", comment: "Dark color scheme", scheme: "rose-pine", mode: "dark", accent: "#c4a7e7", accent2: "#9ccfd8", bg: "#191724" },
            { name: "Rose Pine Dawn", id: "@ rose-pine-dawn", comment: "Light color scheme", scheme: "rose-pine-dawn", mode: "light", accent: "#907aa9", accent2: "#56949f", bg: "#faf4ed" },
            { name: "Nord", id: "@ nord", comment: "Dark color scheme", scheme: "nord", mode: "dark", accent: "#88c0d0", accent2: "#81a1c1", bg: "#2e3440" },
            { name: "Dracula", id: "@ dracula", comment: "Dark color scheme", scheme: "dracula", mode: "dark", accent: "#bd93f9", accent2: "#8be9fd", bg: "#282a36" },
            { name: "Solarized Dark", id: "@ solarized-dark", comment: "Dark color scheme", scheme: "solarized-dark", mode: "dark", accent: "#268bd2", accent2: "#2aa198", bg: "#002b36" },
            { name: "Solarized Light", id: "@ solarized-light", comment: "Light color scheme", scheme: "solarized-light", mode: "light", accent: "#268bd2", accent2: "#2aa198", bg: "#fdf6e3" },
            { name: "Tokyo Night", id: "@ tokyonight", comment: "Dark color scheme", scheme: "tokyonight", mode: "dark", accent: "#7aa2f7", accent2: "#bb9af7", bg: "#1a1b26" }
        ];
    }

    function shellQuote(value) {
        return "'" + `${value}`.replace(/'/g, "'\\''") + "'";
    }

    function launcherCommandFromValue(commandValue) {
        if (typeof commandValue === "string")
            return commandValue;

        if (Array.isArray(commandValue)) {
            if (commandValue.length === 0)
                return "";
            if (`${commandValue[0]}` === "autocomplete")
                return "";
            if (`${commandValue[0]}` === "setMode")
                return "cd \"$HOME/dotfiles\" && ./apply-theme.sh --mode " + shellQuote(`${commandValue[1] || "dark"}`);
            if (`${commandValue[0]}` === "caelestia" && `${commandValue[1]}` === "wallpaper" && `${commandValue[2]}` === "-r")
                return randomWallpaperCommand();
            if (`${commandValue[0]}` === "caelestia" && `${commandValue[1]}` === "shell" && `${commandValue[2]}` === "nexus" && `${commandValue[3]}` === "open")
                return "qs ipc call launcher close; qs ipc call notifications open";
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

        return "";
    }

    function defaultLockCommand() {
        return "if command -v hyprlock >/dev/null 2>&1; then pidof hyprlock >/dev/null 2>&1 || hyprlock; else loginctl lock-session; fi";
    }

    function lockCommand() {
        const configured = configValue("lock.commands.lock", "");
        if (configured !== "")
            return launcherCommandFromValue(configured) || defaultLockCommand();

        const sessionConfigured = configValue("session.commands.lock", "");
        if (sessionConfigured !== "")
            return launcherCommandFromValue(sessionConfigured) || defaultLockCommand();

        return defaultLockCommand();
    }

    function wallpaperDir() {
        return configString("paths.wallpaperDir", "~/Pictures/Wallpapers");
    }

    function wallpaperIndexCommand() {
        const dir = wallpaperDir();
        return "dir=" + shellQuote(dir) + "; case \"$dir\" in ~/*) dir=\"$HOME/${dir#~/}\" ;; esac; [ -d \"$dir\" ] || exit 0; find \"$dir\" -maxdepth 1 -type f | grep -Ei '\\.(jpg|jpeg|png|webp)$' | head -40 | while IFS= read -r file; do [ -n \"$file\" ] || continue; printf '%s|%s\\n' \"$file\" \"$(basename \"$file\")\"; done";
    }

    function wallpaperCommand(path) {
        const quotedPath = shellQuote(path);
        return "file=" + quotedPath + "; if command -v swww >/dev/null 2>&1; then swww img \"$file\"; elif command -v hyprctl >/dev/null 2>&1 && pgrep -x hyprpaper >/dev/null 2>&1; then hyprctl hyprpaper preload \"$file\"; hyprctl hyprpaper wallpaper \",$file\"; fi; " + smartSchemeCommand("$file");
    }

    function randomWallpaperCommand() {
        return "file=$(for dir in " + shellQuote(wallpaperDir()) + " \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\"; do case \"$dir\" in '~') dir=\"$HOME\";; '~/'*) dir=\"$HOME/${dir#~/}\";; esac; [ -d \"$dir\" ] || continue; find \"$dir\" -maxdepth 1 -type f | grep -Ei '\\.(jpg|jpeg|png|webp)$'; done | shuf -n 1); [ -n \"$file\" ] || exit 0; if command -v swww >/dev/null 2>&1; then swww img \"$file\"; elif command -v hyprctl >/dev/null 2>&1 && pgrep -x hyprpaper >/dev/null 2>&1; then hyprctl hyprpaper preload \"$file\"; hyprctl hyprpaper wallpaper \",$file\"; fi; " + smartSchemeCommand("$file");
    }

    function smartSchemeCommand(fileExpression) {
        const value = configValue("services.smartScheme", false);
        if (value === false || value === "false" || value === "off" || value === "none" || value === "")
            return "";

        if (value && typeof value === "object") {
            if (value.enabled === false)
                return "";
            if (value.command !== undefined) {
                const command = launcherCommandFromValue(value.command);
                if (command.length > 0)
                    return "SMART_WALLPAPER=" + fileExpression + " " + command;
            }
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

    function currentWallpaperCommand() {
        return "if command -v swww >/dev/null 2>&1; then swww query 2>/dev/null | sed -n 's/^.*image: //p' | head -n 1; elif command -v hyprctl >/dev/null 2>&1; then hyprctl hyprpaper listactive 2>/dev/null | sed -n 's/^.* = //p' | head -n 1; fi";
    }

    function launcherWallpapers() {
        const rows = wallpaperIndex.value.length > 0 ? wallpaperIndex.value.split("\n") : [];
        const items = [];
        const specialPrefix = launcherSpecialPrefix();
        const maxWallpapers = launcherMaxWallpapers();

        for (let i = 0; i < rows.length && items.length < maxWallpapers; i++) {
            const splitAt = rows[i].indexOf("|");
            if (splitAt <= 0)
                continue;

            const path = rows[i].slice(0, splitAt);
            const name = rows[i].slice(splitAt + 1);
            items.push({
                kind: "wallpaper",
                name: name,
                comment: "Wallpaper from ~/Pictures/Wallpapers",
                id: specialPrefix + " wallpaper " + name,
                icon: "preferences-desktop-wallpaper-symbolic",
                path: path,
                command: wallpaperCommand(path)
            });
        }

        return items;
    }

    function launcherConfiguredActions() {
        const configured = configValue("launcher.actions", []);
        if (!Array.isArray(configured))
            return [];

        const prefix = launcherActionPrefix();
        const items = [];
        for (let i = 0; i < configured.length; i++) {
            const action = configured[i] || {};
            if (action.enabled === false)
                continue;

            const command = launcherCommandFromValue(action.command);
            const autocomplete = Array.isArray(action.command) && `${action.command[0]}` === "autocomplete" ? `${action.command[1] || ""}` : "";
            if (command.length === 0 && autocomplete.length === 0)
                continue;

            const name = `${action.name || action.id || "Action"}`;
            items.push({
                kind: "action",
                name: name,
                comment: `${action.description || action.comment || ""}`,
                id: prefix + " " + `${action.id || name}`.toLowerCase(),
                icon: `${action.icon || "applications-system-symbolic"}`,
                command: command,
                autocomplete: autocomplete,
                dangerous: action.dangerous === true
            });
        }

        return items;
    }

    function launcherActions() {
        const prefix = launcherActionPrefix();
        return launcherConfiguredActions().concat([
            {
                kind: "action",
                name: "Lock",
                comment: "Lock the current session",
                id: prefix + " lock",
                icon: "system-lock-screen-symbolic",
                command: lockCommand()
            },
            {
                kind: "action",
                name: "Screenshot area",
                comment: "Select a region and save it",
                id: prefix + " screenshot area",
                icon: "camera-photo-symbolic",
                command: "mkdir -p \"$HOME/Pictures/Screenshots\"; grim -g \"$(slurp)\" \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""
            },
            {
                kind: "action",
                name: "Screenshot screen",
                comment: "Capture the current screen",
                id: prefix + " screenshot screen",
                icon: "camera-photo-symbolic",
                command: "mkdir -p \"$HOME/Pictures/Screenshots\"; grim \"$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png\""
            },
            {
                kind: "action",
                name: "Settings",
                comment: "Open system settings",
                id: prefix + " settings",
                icon: "preferences-system-symbolic",
                command: "if command -v gnome-control-center >/dev/null 2>&1; then gnome-control-center; elif command -v systemsettings >/dev/null 2>&1; then systemsettings; fi"
            },
            {
                kind: "action",
                name: "Audio settings",
                comment: "Open volume controls",
                id: prefix + " audio",
                icon: "audio-volume-high-symbolic",
                command: "if command -v pavucontrol >/dev/null 2>&1; then pavucontrol; elif command -v pwvucontrol >/dev/null 2>&1; then pwvucontrol; fi"
            },
            {
                kind: "action",
                name: "Network settings",
                comment: "Open network connection editor",
                id: prefix + " network",
                icon: "network-wired-symbolic",
                command: "if command -v nm-connection-editor >/dev/null 2>&1; then nm-connection-editor; elif command -v kitty >/dev/null 2>&1; then kitty -e nmtui; fi"
            },
            {
                kind: "action",
                name: "Random wallpaper",
                comment: "Pick a wallpaper from ~/Pictures/Wallpapers",
                id: prefix + " wallpaper",
                icon: "preferences-desktop-wallpaper-symbolic",
                command: randomWallpaperCommand()
            },
            {
                kind: "action",
                name: "Toggle notifications",
                comment: "Enable or disable Quickshell notification server",
                id: prefix + " notifications",
                icon: "preferences-system-notifications-symbolic",
                command: "qs-notifications status >/dev/null 2>&1 && qs-notifications disable || qs-notifications enable"
            },
            {
                kind: "action",
                name: "Light mode",
                comment: "Apply the default light color scheme",
                id: prefix + " light",
                icon: "weather-clear-symbolic",
                command: "cd \"$HOME/dotfiles\" && ./apply-theme.sh catppuccin-latte"
            },
            {
                kind: "action",
                name: "Dark mode",
                comment: "Apply the default dark color scheme",
                id: prefix + " dark",
                icon: "night-light-disabled-symbolic",
                command: "cd \"$HOME/dotfiles\" && ./apply-theme.sh default"
            },
            {
                kind: "action",
                name: "Suspend",
                comment: "Suspend the computer",
                id: prefix + " suspend",
                icon: "media-playback-pause-symbolic",
                command: "systemctl suspend"
            },
            {
                kind: "action",
                name: "Logout",
                comment: "Exit the current Hyprland session",
                id: prefix + " logout",
                icon: "system-log-out-symbolic",
                command: "hyprctl dispatch exit",
                dangerous: true
            },
            {
                kind: "action",
                name: "Reboot",
                comment: "Reboot the computer",
                id: prefix + " reboot",
                icon: "system-reboot-symbolic",
                command: "systemctl reboot",
                dangerous: true
            },
            {
                kind: "action",
                name: "Shutdown",
                comment: "Power off the computer",
                id: prefix + " shutdown",
                icon: "system-shutdown-symbolic",
                command: "systemctl poweroff",
                dangerous: true
            }
        ]);
    }

    function launcherCalcExpression(rawQuery) {
        const value = rawQuery.trim();
        if (value.indexOf("calc ") === 0)
            return value.slice(5).trim();
        if (value[0] === "=")
            return value.slice(1).trim();
        return "";
    }

    function updateCalcResult() {
        const expression = launcherCalcExpression(launcherQuery);
        calcExpression = expression;
        calcResult = "";

        if (expression.length === 0)
            return;

        calcRunner.exec(["sh", "-c", "if command -v qalc >/dev/null 2>&1; then qalc -t " + shellQuote(expression) + " 2>/dev/null | head -n 1; fi"]);
    }

    function launcherCalcItem() {
        if (calcExpression.length === 0 || calcResult.length === 0)
            return null;

        return {
            kind: "calc",
            name: calcResult,
            comment: calcExpression,
            id: "calc",
            icon: "accessories-calculator-symbolic",
            command: "if command -v wl-copy >/dev/null 2>&1; then printf %s " + shellQuote(calcResult) + " | wl-copy; fi"
        };
    }

    function itemMatches(item, query) {
        if (query.length === 0)
            return true;

        const haystack = item.searchText || launcherSearchText(item);

        if (launcherUseFuzzy(item.kind || ""))
            return fuzzyIncludes(haystack, query);

        return haystack.indexOf(query) !== -1;
    }

    function appIconSource(icon) {
        if (icon !== null && icon !== undefined && icon.length > 0) {
            if (icon[0] === "/")
                return "file://" + icon;

            if (icon === "system-lock-screen-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/status/system-lock-screen-symbolic.svg";
            if (icon === "camera-photo-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/devices/camera-photo-symbolic.svg";
            if (icon === "preferences-system-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/categories/preferences-system-symbolic.svg";
            if (icon === "audio-volume-high-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/status/audio-volume-high-symbolic.svg";
            if (icon === "network-wired-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/devices/network-wired-symbolic.svg";
            if (icon === "preferences-desktop-wallpaper-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/legacy/preferences-desktop-wallpaper-symbolic.svg";
            if (icon === "preferences-system-notifications-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/legacy/preferences-system-notifications-symbolic.svg";
            if (icon === "media-playback-pause-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/actions/media-playback-pause-symbolic.svg";
            if (icon === "accessories-calculator-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/legacy/accessories-calculator-symbolic.svg";
            if (icon === "weather-clear-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/status/weather-clear-symbolic.svg";
            if (icon === "night-light-disabled-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/status/night-light-disabled-symbolic.svg";
            if (icon === "system-log-out-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/actions/system-log-out-symbolic.svg";
            if (icon === "system-reboot-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/actions/system-reboot-symbolic.svg";
            if (icon === "system-shutdown-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/actions/system-shutdown-symbolic.svg";
            if (icon === "applications-system-symbolic")
                return "file:///usr/share/icons/Adwaita/symbolic/categories/applications-system-symbolic.svg";

            if (Quickshell.hasThemeIcon(icon))
                return Quickshell.iconPath(icon);
        }

        return fallbackAppIcon;
    }

    function refreshLauncherApps() {
        const rawQuery = launcherQuery.trim();
        const actionPrefix = launcherActionPrefix();
        const specialPrefix = launcherSpecialPrefix();
        const actionOnly = rawQuery.indexOf(actionPrefix) === 0;
        const schemeOnly = rawQuery.indexOf(specialPrefix) === 0;
        const query = actionOnly ? rawQuery.slice(actionPrefix.length).trim().toLowerCase() : schemeOnly ? rawQuery.slice(specialPrefix.length).trim().toLowerCase() : rawQuery.toLowerCase();
        const nextApps = [];
        const calcItem = launcherCalcItem();
        const maxShown = launcherMaxShown();

        if (!actionOnly && !schemeOnly && calcItem !== null)
            nextApps.push(calcItem);

        if (!actionOnly && !schemeOnly) {
            if (launcherAppIndex.length === 0)
                rebuildLauncherAppIndex();

            for (let i = 0; i < launcherAppIndex.length && nextApps.length < maxShown; i++) {
                const item = launcherAppIndex[i];
                if (itemMatches(item, query))
                    nextApps.push(item);
            }
        }

        if (!actionOnly) {
            const schemes = launcherSchemes();
            for (let j = 0; j < schemes.length; j++) {
                const scheme = schemes[j];
                const item = {
                    kind: "scheme",
                    name: scheme.name,
                    comment: scheme.comment,
                    id: specialPrefix + " " + scheme.scheme,
                    icon: "",
                    scheme: scheme.scheme,
                    mode: scheme.mode,
                    accent: scheme.accent,
                    accent2: scheme.accent2,
                    bg: scheme.bg,
                    command: `cd "$HOME/dotfiles" && ./apply-theme.sh ${scheme.scheme}`
                };

                if (itemMatches(item, query))
                    nextApps.push(item);

                if (nextApps.length >= maxShown)
                    break;
            }

            const wallpapers = launcherWallpapers();
            for (let w = 0; w < wallpapers.length; w++) {
                if (itemMatches(wallpapers[w], query))
                    nextApps.push(wallpapers[w]);

                if (nextApps.length >= maxShown)
                    break;
            }
        }

        if (!schemeOnly) {
            const actions = launcherActions();
            for (let k = 0; k < actions.length; k++) {
                if (actions[k].dangerous && !launcherDangerousActionsEnabled())
                    continue;

                if (itemMatches(actions[k], query))
                    nextApps.push(actions[k]);

                if (nextApps.length >= maxShown)
                    break;
            }
        }

        launcherApps = nextApps.slice(0, maxShown);
        if (launcherIndex >= launcherApps.length)
            launcherIndex = Math.max(0, launcherApps.length - 1);
    }

    function openLauncher() {
        launcherQuery = "";
        launcherIndex = 0;
        if (launcherAppIndex.length === 0)
            rebuildLauncherAppIndex();
        refreshLauncherApps();
        launcherOpen = true;
    }

    function closeLauncher() {
        launcherOpen = false;
        launcherQuery = "";
        launcherIndex = 0;
    }

    function toggleLauncher() {
        if (launcherOpen)
            closeLauncher();
        else
            openLauncher();
    }

    function moveLauncherSelection(delta) {
        if (launcherApps.length === 0)
            return;

        launcherIndex = Math.max(0, Math.min(launcherApps.length - 1, launcherIndex + delta));
    }

    function launchSelected() {
        if (launcherApps.length === 0)
            return;

        const app = launcherApps[launcherIndex];
        if (app !== null && app !== undefined) {
            if (app.kind === "action" && app.autocomplete && app.autocomplete.length > 0) {
                const prefix = app.autocomplete === "scheme" || app.autocomplete === "variant" || app.autocomplete === "wallpaper" ? launcherSpecialPrefix() : launcherActionPrefix();
                launcherQuery = prefix + " " + app.autocomplete + " ";
                launcherIndex = 0;
                refreshLauncherApps();
                return;
            }
            if (app.kind === "action" || app.kind === "scheme" || app.kind === "wallpaper" || app.kind === "calc")
                launcherRunner.exec(["sh", "-c", app.command]);
            else if (app.app)
                app.app.execute();
            closeLauncher();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    PollText {
        id: notificationsFlag
        interval: 2000
        command: ["sh", "-c", "state=\"${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/quickshell-notifications.enabled\"; [ \"$(cat \"$state\" 2>/dev/null)\" = true ] && printf true || printf false"]
    }

    PollText {
        id: shellConfig
        interval: 2000
        command: ["sh", "-c", "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/quickshell.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
    }

    PollText {
        id: wallpaperIndex
        interval: 30000
        command: ["sh", "-c", root.wallpaperIndexCommand()]
    }

    PollText {
        id: currentWallpaper
        interval: 5000
        command: ["sh", "-c", root.currentWallpaperCommand()]
    }

    PollText {
        id: lockActive
        interval: 1000
        command: ["sh", "-c", "pidof hyprlock >/dev/null 2>&1 && printf true || printf false"]
    }

    Process {
        id: launcherRunner
    }

    Timer {
        id: calcTimer
        interval: 180
        repeat: false
        onTriggered: root.updateCalcResult()
    }

    Timer {
        id: launcherRefreshTimer
        interval: 35
        repeat: false
        onTriggered: root.refreshLauncherApps()
    }

    Process {
        id: calcRunner

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.calcResult = text.trim();
                root.refreshLauncherApps();
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            root.openLauncher();
        }

        function close(): void {
            root.closeLauncher();
        }

        function toggle(): void {
            root.toggleLauncher();
        }

        function refresh(): void {
            root.refreshLauncherApps();
        }

    }

    IpcHandler {
        target: "keybinds"

        function open(): void {
            root.keybindsOpen = true;
        }

        function close(): void {
            root.keybindsOpen = false;
        }

        function toggle(): void {
            root.keybindsOpen = !root.keybindsOpen;
        }

    }

    IpcHandler {
        target: "picker"

        function open(): void {
            root.openPicker(false);
        }

        function openFreeze(): void {
            root.openPicker(true);
        }
    }

    IpcHandler {
        target: "drawers"

        function toggle(drawer: string): void {
            root.requestDrawer(drawer);
        }

        function list(): string {
            return root.drawerNames().join("\n");
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            launcherRunner.exec(["sh", "-c", root.lockCommand()]);
        }

        function unlock(): void {
        }

        function isLocked(): bool {
            return lockActive.value === "true";
        }
    }

    IpcHandler {
        target: "mpris"

        function playPause(): void {
            root.mprisCall("playPause");
        }

        function next(): void {
            root.mprisCall("next");
        }

        function previous(): void {
            root.mprisCall("previous");
        }

        function stop(): void {
            root.mprisCall("stop");
        }

        function play(): void {
            root.mprisCall("play");
        }

        function pause(): void {
            root.mprisCall("pause");
        }

        function list(): string {
            return root.mprisList();
        }

        function getActive(prop: string): string {
            return root.mprisProperty(prop);
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            if (path.length > 0)
                launcherRunner.exec(["sh", "-c", root.wallpaperCommand(path)]);
        }

        function get(): string {
            return currentWallpaper.value;
        }

        function list(): string {
            return wallpaperIndex.value;
        }
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            root.rebuildLauncherAppIndex();
            if (root.launcherOpen)
                root.refreshLauncherApps();
        }

    }

    Connections {
        target: wallpaperIndex

        function onValueChanged() {
            if (root.launcherOpen)
                root.refreshLauncherApps();
        }

    }

    Connections {
        target: shellConfig

        function onValueChanged() {
            root.shellConfigObject();
            root.rebuildLauncherAppIndex();
            if (root.launcherOpen)
                root.refreshLauncherApps();
        }

    }

    onLauncherQueryChanged: {
        launcherIndex = 0;
        calcTimer.restart();
        launcherRefreshTimer.restart();
    }

    Variants {
        model: Quickshell.screens

        BackgroundLayer {
            shellConfig: root.shellConfigObject()
        }

    }

    Variants {
        model: Quickshell.screens

        DesktopBar {
            drawerRequest: root.drawerRequest
            drawerNonce: root.drawerNonce
        }

    }

    Variants {
        model: Quickshell.screens

        SubmapIndicator {
            shellConfig: root.shellConfigObject()
        }

    }

    Variants {
        model: Quickshell.screens

        MonitorModeIndicator {
            shellConfig: root.shellConfigObject()
        }

    }

    Variants {
        model: Quickshell.screens

        KeybindHelp {
            shellConfig: root.shellConfigObject()
            open: root.keybindsOpen
            onOpenRequested: root.keybindsOpen = true
            onCloseRequested: root.keybindsOpen = false
        }

    }

    Loader {
        active: root.notificationsEnabled
        sourceComponent: Notifications {
            shellConfig: root.shellConfigObject()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            property var hyprMonitor: Hyprland.monitorFor(modelData)
            property bool onFocusedMonitor: Hyprland.focusedMonitor === null || hyprMonitor === null || Hyprland.focusedMonitor.name === hyprMonitor.name

            screen: modelData
            visible: root.launcherShowOnHover() && !root.launcherOpen && onFocusedMonitor
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: root.launcherHoverWidth()

            anchors {
                top: true
                bottom: true
                left: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.openLauncher()
            }
        }

    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcher

            required property var modelData
            property var hyprMonitor: Hyprland.monitorFor(modelData)
            property bool onFocusedMonitor: Hyprland.focusedMonitor === null || hyprMonitor === null || Hyprland.focusedMonitor.name === hyprMonitor.name

            screen: modelData
            visible: root.launcherOpen && onFocusedMonitor
            color: "transparent"
            focusable: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            onVisibleChanged: {
                if (visible)
                    search.forceActiveFocus();
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeLauncher()
            }

            Rectangle {
                id: launcherPanel

                width: Math.min(760, parent.width - 48)
                height: Math.min(560, parent.height - 96)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 64
                radius: 14
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse.accepted = true
                }

                Rectangle {
                    id: searchBox

                    height: 44
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    radius: 10
                    color: Theme.surface
                    border.color: search.activeFocus ? Theme.accent : Theme.border
                    border.width: 1

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Search apps, ${root.launcherActionPrefix()} actions, ${root.launcherSpecialPrefix()} specials`
                        color: Theme.fgMuted
                        font.pixelSize: root.launcherHintFontSize()
                        visible: search.text.length === 0
                    }

                    TextInput {
                        id: search

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: refreshButton.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        font.pixelSize: root.launcherInputFontSize()
                        text: root.launcherQuery

                        onTextEdited: root.launcherQuery = text

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.closeLauncher();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchSelected();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down || (root.launcherVimKeybinds() && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_J)) {
                                root.moveLauncherSelection(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up || (root.launcherVimKeybinds() && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K)) {
                                root.moveLauncherSelection(-1);
                                event.accepted = true;
                            }
                        }

                    }

                    Rectangle {
                        id: refreshButton

                        width: 34
                        height: 30
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 8
                        color: refreshMouse.containsMouse ? Theme.bgAlt : "transparent"
                        border.color: Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "R"
                            color: Theme.fg
                            font.pixelSize: root.launcherMetaFontSize()
                            font.bold: true
                        }

                        MouseArea {
                            id: refreshMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.rebuildLauncherAppIndex();
                                root.refreshLauncherApps();
                                search.forceActiveFocus();
                            }
                        }

                    }

                }

                ListView {
                    id: launcherList

                    anchors.top: searchBox.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    clip: true
                    spacing: 6
                    model: root.launcherApps
                    currentIndex: root.launcherIndex

                    delegate: Rectangle {
                        id: appRow

                        required property var modelData
                        required property int index
                        property bool selected: index === root.launcherIndex

                        width: launcherList.width
                        height: 56
                        radius: 10
                        color: selected ? Theme.accent : appMouse.containsMouse ? Theme.surface : "transparent"
                        border.color: selected ? Theme.accent : Theme.border
                        border.width: selected || appMouse.containsMouse ? 1 : 0

                        IconImage {
                            id: appIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 32
                            visible: modelData.kind !== "scheme"
                            source: root.appIconSource(modelData.icon || "")
                        }

                        Rectangle {
                            id: schemeIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 10
                            visible: modelData.kind === "scheme"
                            color: modelData.bg || Theme.surface
                            border.color: appRow.selected ? Theme.accentFg : Theme.border
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 3

                                Rectangle { width: 7; height: 18; radius: 4; color: modelData.accent || Theme.accent }
                                Rectangle { width: 7; height: 18; radius: 4; color: modelData.accent2 || Theme.accent2 }
                            }
                        }

                        Column {
                            anchors.left: modelData.kind === "scheme" ? schemeIcon.right : appIcon.right
                            anchors.leftMargin: 12
                            anchors.right: appId.left
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.name || modelData.id || "Application"
                                color: appRow.selected ? Theme.accentFg : Theme.fg
                                elide: Text.ElideRight
                                font.pixelSize: root.launcherTitleFontSize()
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: modelData.comment || modelData.id || ""
                                color: appRow.selected ? Theme.accentFg : Theme.fgMuted
                                elide: Text.ElideRight
                                font.pixelSize: root.launcherBodyFontSize()
                            }

                        }

                        Text {
                            id: appId

                            width: 210
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: modelData.kind === "action" ? "action" : modelData.kind === "scheme" ? modelData.mode : modelData.kind === "wallpaper" ? "wallpaper" : modelData.kind === "calc" ? "copy" : modelData.id || ""
                            color: appRow.selected ? Theme.accentFg : Theme.fgMuted
                            elide: Text.ElideMiddle
                            font.pixelSize: root.launcherMetaFontSize()
                        }

                        MouseArea {
                            id: appMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.launcherIndex = index
                            onClicked: {
                                root.launcherIndex = index;
                                root.launchSelected();
                            }
                        }

                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 60
                        radius: 10
                        color: "transparent"
                        visible: root.launcherApps.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: "No launcher results"
                            color: Theme.fgMuted
                            font.pixelSize: root.launcherHintFontSize()
                        }

                    }

                }

            }

        }

    }

}
