-- Starter.lua
local STARTER_ID = 1
local STARTERS = {}

local Starter = {}
Starter.__index = Starter

Starter._TYPE = {
    MANAGED = 1,
    HOOK = 2,
}
Starter._HOOK_TIMING = {
    PRE = 1,
    POST = 2,
}

function Starter.findStarterById(id)
    for i, starter in ipairs(STARTERS) do
        if starter.id == id then
            return starter
        end
    end
    return nil
end

-- Constructor for the Starter class
-- @param path string The path to the object.
-- @param type Starter._TYPE The type of the object (managed or hook).
function Starter:new()
    local instance = setmetatable({}, Starter)
    instance.id = STARTER_ID
    STARTER_ID = STARTER_ID + 1
    instance.path = ""
    instance.type = Starter._TYPE.MANAGED

    instance.status = ""

    instance.hook_timing = Starter._HOOK_TIMING.PRE
    instance.hook_methodName = "update"
    instance.hook_active = false
    
    instance.hook_method_data = {} -- Array of objects keyed by starting value type

    instance.ending_value = nil

    instance.node_id = nil
    instance.node_pos = nil
    instance.output_attr = nil

    instance.children = {}

    STARTERS[instance.id] = instance
    return instance
end

-- Gets the current path of the Starter object.
-- @return string The current path.
function Starter:getPath()
    return self.path
end

-- Sets a new path for the Starter object.
-- @param newPath string The new path to set.
function Starter:setPath(newPath)
    self.path = newPath
end

-- Get the current status of the Starter object.
-- @return string The current status.
function Starter:getStatus()
    return self.status
end

-- Get the list of children nodes
-- @return table The list of children nodes.
function Starter:getChildren()
    if self.children == nil then
        self.children = {}
    end
    return self.children
end

-- Add a child node to the Starter object.
-- @param child object The child node to add.
function Starter:addChild(child)
    if self.children == nil then
        self.children = {}
    end
    table.insert(self.children, child)
    child:setParent(self)
    child:setParentIsStarter(true)
end

-- Remove a child node
-- @return: boolean - true if removed, false otherwise
function Starter:removeChild(child)
    if self.children == nil then return true end
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            return true
        end
    end
end


-- Gets the current type of the Starter object.
-- @return Starter._TYPE The current type.
function Starter:getType()
    return self.type
end

-- Sets a new type for the Starter object.
-- @param newType Starter._TYPE The new type to set.
function Starter:setType(newType)
    self.type = newType
end

-- Gets the current hook timing of the Starter object.
-- @return Starter._HOOK_TIMING The current hook timing.
function Starter:getHookTiming()
    return self.hook_timing
end

-- Sets a new hook timing for the Starter object.
-- @param newHookTiming Starter._HOOK_TIMING The new hook timing to set.
function Starter:setHookTiming(newHookTiming)
    self.hook_timing = newHookTiming
end

-- Get the current hooked method name
-- @return string The current hooked method name.
function Starter:getHookMethodName()
    return self.hook_methodName
end

-- Set a new hooked method name
-- @param newHookMethodName string The new hooked method name to set.
function Starter:setHookMethodName(newHookMethodName)
    self.hook_methodName = newHookMethodName
end

-- Gets the hook active state of the Starter object.
function Starter:getHookActive()
    return self.hook_active
end

-- Sets the hook to start
function Starter:startHook()
    self.hook_active = true
    log.debug("Hook started for " .. self.path .. " with method " .. self.hook_methodName)
    sdk.hook(sdk.find_type_definition(self.path):get_method(self.hook_methodName), function(args)
        log.debug("Pre Hook called for " .. self.path .. " with method " .. self.hook_methodName)
        if self.hook_timing == Starter._HOOK_TIMING.PRE then
            local managed = sdk.to_managed_object(args[2])
            if not managed then
                self.status = "Hook: Managed object not found"
                return
            end
            self.ending_value = managed
            self.status = "Hook: Pre-hook called, managed object set"
        end
        
    end, function(retval)
        log.debug("Post Hook called for " .. self.path .. " with method " .. self.hook_methodName)
        if self.hook_timing == Starter._HOOK_TIMING.POST then
            self.ending_value = retval
            self.status = "Hook: Post-hook called, retval set"
        end
        return retval
    end)
end

-- Get if the hook is active
function Starter:isHookActive()
    return self.hook_active
end

-- Run the starter
function Starter:run()
    if self.type == Starter._TYPE.MANAGED then
        self.ending_value = self:getManagedSingleton()
    elseif self.type == Starter._TYPE.HOOK then
        self:checkHook()
        if not self.hook_active then
            self.ending_value = nil
            return
        end
    end

    for i, child in ipairs(self.children) do
        child:setStartingValue(self.ending_value)
    end
end

-- Get the Managed Singleton from the path
-- @return object The managed singleton object.
function Starter:getManagedSingleton()
    if not self.path then
        self.status = "Managed: Path is nil"
        return nil
    elseif self.path == "" then
        self.status = "Managed: Path is empty"
        return nil
    end
    local type = sdk.find_type_definition(self.path)
    if not type then
        self.status = "Managed: Type not found: " .. self.path
        return nil
    end
    self.status = "Managed: Type found: " .. self.path
    return sdk.get_managed_singleton(self.path)
end

-- Check the hook before initalizing
function Starter:checkHook()
    if self.hook_active then
        self.status = "Hook: Active"
        return
    end

    if not self.path or self.path == "" then
        self.status = "Hook: Path is Empty"
        return
    end

    local type = sdk.find_type_definition(self.path)
    if not type then
        self.status = "Hook: Type not found: " .. self.path
        return
    end

    local method = type:get_method(self.hook_methodName)
    if not method then
        self.status = "Hook: Method not found: " .. self.hook_methodName
        return
    end
    self.status = "Hook: Ready to initialize hook"
end


-- Get a JSON dump of the node
function Starter:print()
    return json.dump_string(self, 2)
end


return Starter