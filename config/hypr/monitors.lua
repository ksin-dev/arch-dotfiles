-- Keep compatibility with nwg-displays, which still writes Hyprlang files.
-- Only monitor/workspace rules are accepted; unrelated legacy directives are ignored.

local home = os.getenv("HOME") or ""

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function split_csv(value)
    local fields = {}
    for field in (value .. ","):gmatch("(.-),") do
        table.insert(fields, trim(field))
    end
    return fields
end

local function bool(value)
    if value == "true" or value == "1" then return true end
    if value == "false" or value == "0" then return false end
    return value
end

local function load_rules(path)
    local file = io.open(path, "r")
    if not file then return false end

    for raw_line in file:lines() do
        local line = trim(raw_line:gsub("#.*$", ""))
        local kind, value = line:match("^(monitor)%s*=%s*(.+)$")
        if kind then
            local fields = split_csv(value)
            local spec = {
                output = fields[1] or "",
                mode = fields[2] ~= "" and fields[2] or "preferred",
                position = fields[3] ~= "" and fields[3] or "auto",
                scale = tonumber(fields[4]) or (fields[4] ~= "" and fields[4]) or "auto",
            }
            for index = 5, #fields do
                local key, option = fields[index]:match("^([^:]+):(.+)$")
                if key == "transform" then spec.transform = tonumber(option) or option end
                if key == "mirror" then spec.mirror = option end
                if key == "bitdepth" then spec.bitdepth = tonumber(option) or option end
                if key == "vrr" then spec.vrr = tonumber(option) or option end
            end
            hl.monitor(spec)
        else
            kind, value = line:match("^(workspace)%s*=%s*(.+)$")
            if kind then
                local fields = split_csv(value)
                local spec = { workspace = fields[1] }
                for index = 2, #fields do
                    local key, option = fields[index]:match("^([^:]+):(.+)$")
                    if key == "monitor" then spec.monitor = option end
                    if key == "default" then spec.default = bool(option) end
                    if key == "persistent" then spec.persistent = bool(option) end
                    if key == "layout" then spec.layout = option end
                end
                hl.workspace_rule(spec)
            end
        end
    end

    file:close()
    return true
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
load_rules(home .. "/.config/dotfiles/hypr/monitors.conf")
load_rules(home .. "/.config/dotfiles/hypr/workspaces.conf")
