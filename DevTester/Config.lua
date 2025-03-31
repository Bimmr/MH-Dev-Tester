local Config = {}
local configs = nil

local function split(text, delim)
    -- returns an array of fields based on text and delimiter (one character only)
    local result = {}
    local magic = "().%+-*?[]^$"

    if delim == nil then
        delim = "%s"
    elseif string.find(delim, magic, 1, true) then
        delim = "%" .. delim
    end

    local pattern = "[^" .. delim .. "]+"
    for w in string.gmatch(text, pattern) do table.insert(result, w) end
    return result
end

-- Load all configs from the Configs folder
function Config.loadConfigs()
    configs = {}
    print("Loading configs...")
    local files = fs.glob([[DevTester\\.*json]])
    for i = 1, #files do
        local file = files[i]
        local fileName = split(file, "\\")[#split(file, "\\")]
        local configName = split(fileName, ".")[1]
        configs[configName] = json.load_file(file)
    end
end

-- Load a single config from the loaded Configs table
function Config.getConfig(name)
    if configs == nil then
        Config.loadConfigs()
    end
    if configs[name] == nil then
        return nil
    else
        return configs[name]
    end
end

-- Save a config to the Configs table and to the file system
-- @param name The name of the config to save.
-- @param config The config to save.
function Config.saveConfig(name, config)
    json.dump_file("DevTester/" .. name .. ".json", config)
    if configs == nil then
        Config.loadConfigs()
    end
    configs[name] = config
end

-- Get all configs from the Configs table
-- @return table A table containing all loaded configs.
function Config.getAllConfigs()
    if configs == nil then
        Config.loadConfigs()
    end
    return configs
end

function Config.deleteConfig(name)
    Config.saveConfig(name, nil)
    Config.loadConfigs()
end

return Config