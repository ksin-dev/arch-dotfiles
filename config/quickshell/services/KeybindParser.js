.pragma library

function formatModifier(value) {
    return `${value || ""}`
        .split("$mainMod").join("SUPER")
        .split("SHIFT").join("Shift")
        .split("CTRL").join("Ctrl")
        .split("ALT").join("Alt")
        .split("_R").join(" Right")
        .trim();
}

function formatKey(value) {
    const trimmed = value.trim();
    const aliases = {
        Return: "Enter",
        escape: "Esc",
        slash: "/",
        mouse_down: "Mouse wheel down",
        mouse_up: "Mouse wheel up",
        "mouse:272": "Left drag",
        "mouse:273": "Right drag",
        ALT_R: "Right Alt",
        Alt_R: "Right Alt",
        Hangul: "Right Alt",
        ISO_Level3_Shift: "Right Alt"
    };

    return aliases[trimmed] || trimmed;
}

function formatCombo(modifier, key) {
    const mod = formatModifier(modifier);
    const formattedKey = formatKey(key);
    return mod ? `${mod} + ${formattedKey}` : formattedKey;
}

function bindKind(bindType) {
    if (bindType.indexOf("m") !== -1)
        return "mouse";
    if (bindType.indexOf("e") !== -1 && bindType.indexOf("l") !== -1)
        return "repeat/locked";
    if (bindType.indexOf("e") !== -1)
        return "repeat";
    if (bindType.indexOf("l") !== -1)
        return "locked";

    return "normal";
}

function parseHyprland(text) {
    const items = [];
    let group = "General";
    let submap = "";
    const lines = text.split("\n");

    for (let i = 0; i < lines.length; i++) {
        const rawLine = lines[i];
        const line = rawLine.trim();
        const groupMatch = line.match(/^(?:#|--)\s*@group\s+(.+)$/);
        if (groupMatch) {
            group = groupMatch[1].trim();
            continue;
        }

        const submapMatch = line.match(/^submap\s*=\s*(.+)$/) || line.match(/^hl\.define_submap\("([^"]+)"/);
        if (submapMatch) {
            const name = submapMatch[1].trim();
            submap = name === "reset" ? "" : name;
            continue;
        }

        if (submap && line === "end)") {
            submap = "";
            continue;
        }

        const helpMatch = rawLine.match(/\s(?:#|--)\s*help:\s*(.+)$/);
        if (!helpMatch)
            continue;

        const bindPart = rawLine.split(/\s(?:#|--)\s*help:/)[0].trim();
        let bindMatch = bindPart.match(/^(bind\w*)\s*=\s*([^,]*),\s*([^,]*),/);
        if (!bindMatch) {
            const luaMatch = bindPart.match(/^(?:exec|bind)\(([^,]+),/);
            if (!luaMatch)
                continue;

            const combo = luaMatch[1]
                .split("mainMod").join("SUPER")
                .replace(/\s*\.\.\s*/g, "")
                .replace(/["']/g, "")
                .trim();
            const separator = combo.lastIndexOf(" + ");
            const modifier = separator >= 0 ? combo.slice(0, separator) : "";
            const key = separator >= 0 ? combo.slice(separator + 3) : combo;
            const flags = bindPart.includes("repeating = true") ? "e" : "";
            const locked = bindPart.includes("locked = true") ? "l" : "";
            const mouse = bindPart.includes("mouse = true") ? "m" : "";
            bindMatch = [bindPart, `bind${flags}${locked}${mouse}`, modifier, key];
        }

        items.push({
            source: "Hyprland",
            group: submap ? `Mode: ${submap}` : group,
            key: formatCombo(bindMatch[2], bindMatch[3]),
            action: helpMatch[1].trim(),
            kind: submap ? `mode/${bindKind(bindMatch[1])}` : bindKind(bindMatch[1])
        });
    }

    return items;
}

function parseYazi(text) {
    const items = [];
    let group = "General";
    const lines = text.split("\n");

    for (let i = 0; i < lines.length; i++) {
        const rawLine = lines[i];
        const line = rawLine.trim();
        const groupMatch = line.match(/^#\s*@group\s+(.+)$/);
        if (groupMatch) {
            group = groupMatch[1].trim();
            continue;
        }

        if (!line.startsWith("{") || line.indexOf("desc") === -1)
            continue;

        const onMatch = line.match(/on\s*=\s*\[([^\]]+)\]/);
        const descMatch = line.match(/desc\s*=\s*"([^"]+)"/);
        if (!onMatch || !descMatch)
            continue;

        const keys = onMatch[1]
            .split(",")
            .map(key => key.trim().replace(/^"|"$/g, ""))
            .join(" ");

        items.push({
            source: "Yazi",
            group: group,
            key: keys,
            action: descMatch[1],
            kind: "normal"
        });
    }

    return items;
}

function filtered(items, source, query) {
    const q = query.toLowerCase().trim();
    return items.filter(item => {
        if (item.source !== source)
            return false;
        if (!q)
            return true;
        return `${item.group} ${item.key} ${item.action} ${item.kind}`.toLowerCase().indexOf(q) !== -1;
    });
}

function groups(items, source, query) {
    const values = filtered(items, source, query).map(item => item.group);
    const result = [];
    for (let i = 0; i < values.length; i++) {
        if (result.indexOf(values[i]) === -1)
            result.push(values[i]);
    }
    return result;
}

function groupItems(items, source, group, query) {
    return filtered(items, source, query).filter(item => item.group === group);
}

function groupTitle(group) {
    if (!group.startsWith("Mode: "))
        return group;

    return `${group.replace("Mode: ", "")} mode`;
}
