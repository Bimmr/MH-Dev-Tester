local Starter = require("DevTester.Starter")

local NODE_ID = 1
local NODES = {}

local Node = {}
Node.__index = Node
Node._OPERATION = {
    METHOD = 1,
    FIELD = 2,
    ARRAY_INDEX = 3
}

Node._TYPE = {
    GET = 1,
    SET = 2,
    CALL = 3
}

function Node.findNodeById(id)
    for _, node in ipairs(NODES) do
        if node.id == id then
            return node
        end
    end
    return nil
end

-- Constructor for the Node class
function Node:new()
    local instance = setmetatable({}, Node)

    instance.id = NODE_ID
    NODE_ID = NODE_ID + 1

    instance.children = {}
    instance.parent = nil

    instance.starting_value = nil
    instance.ending_value = nil
    instance.status = nil

    instance.operation = nil -- [Method/Field/ArrayIndex]
    instance.type = nil -- [Get/Set/Call]

    instance.method_combo = nil -- Selected method combo box
    instance.method_group_index = nil -- Selected method index
    instance.method_index = nil -- Selected method index
    instance.method_args = nil -- Arguments for the method

    instance.field_combo = nil -- Selected field combo box
    instance.field_group_index = nil -- Selected field index
    instance.field_index = nil -- Selected field index
    instance.field_setValue = nil -- Value to set for the field

    instance.array_index = nil -- Selected array index
    instance.array_setValue = nil -- Value to set for the array index

    instance.call_active = false
    instance.call_was_active = false
    instance.set_active = false

    instance.node_id = nil
    instance.node_pos = nil
    instance.input_attr = nil
    instance.output_attr = nil
    instance.ignore_reset_on_value_change = false

    NODES[instance.id] = instance

    return instance
end

-- Set the parent node id
function Node:setParentId(parent)
    self.parent = parent
end

-- Get the parent node id
function Node:getParentId()
    return self.parent
end

-- Set the parent node
-- @param parent: Node - the parent node to set
function Node:setParent(parent)
    self:setParentId(parent.id)
end

-- Get the parent node
-- @return: Node - the parent node
function Node:getParent()
    if self.parent_is_starter then
        return Starter.findStarterById(self.parent)
    end
    return Node.findNodeById(self.parent)
end

-- Set that the parent is a starter node
function Node:setParentIsStarter(isStarter)
    self.parent_is_starter = isStarter
end

-- Add a child node
-- @param child: Node - the child node to add
-- @return: Node - the added child node
function Node:addChild(child)
    if self.children == nil then
        self.children = {}
    end
    table.insert(self.children, child)
    child:setParent(self)
    return child
end

-- Remove the node from its parent
-- @return: boolean - true if removed, false otherwise
function Node:remove()
    return self:getParent():removeChild(self)
end

-- Remove a child node
-- @return: boolean - true if removed, false otherwise
function Node:removeChild(child)
    if self.children == nil then
        return true
    end
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            return true
        end
    end
end

-- Set the starting value. Will reset the method and field indexes if the value is different
-- @param value: any - the starting value to set
function Node:setStartingValue(value)
    if self.starting_value ~= value and self.starting_value ~= nil and not self.ignore_reset_on_value_change then
        self:reset()
    end
    self.starting_value = value
    self.ignore_reset_on_value_change = nil
end

-- Reset the node to its initial state
-- @return: Node - the reset node
function Node:reset()
    self.operation = nil
    self.type = nil
    self.method_index = nil
    self.method_index_group = nil
    self.method_combo = nil
    self.method_args = nil
    self.field_index = nil
    self.field_setValue = nil
    self.field_index_group = nil
    self.field_combo = nil
    self.status = nil
    self.array_index = nil
    self.array_setValue = nil
    self.call_active = false
    self.call_was_active = false
    self.set_active = false
    self.ending_value = nil
end

-- Get the value type definition
-- @return: Type - the type definition of the value
function Node:getStartingValueType()
    if not self.starting_value then
        return nil
    end
    return self.starting_value:get_type_definition()
end

-- Get the methods of the value type
-- @deep: boolean - defaults to true, if true, get methods from parent types as well
-- @return: table - a table of {type, {name, args, returnType}}
function Node:getMethods(deep)
    if deep == nil then
        deep = true
    end
    local type = self:getStartingValueType()
    local methodsTable = {}
    while type do
        local methods = type:get_methods()
        local methodTable = {}
        for _, method in ipairs(methods) do
            local arg_types = {}
            for _, arg in ipairs(method:get_param_types()) do
                table.insert(arg_types, arg:get_name())
            end
            table.insert(methodTable, {
                name = method:get_name(),
                args = arg_types,
                returnType = method:get_return_type():get_name(),
                data = method
            })
        end
        table.insert(methodsTable, {
            type = type:get_name(),
            methods = methodTable
        })
        if not deep then
            break
        end
        type = type:get_parent_type()
    end
    return methodsTable
end

-- Get the Method at index
-- @return: Method - the method object
function Node:getMethod()
    if not self.method_index_group or not self.method_index then
        return nil
    end
    if not self:getMethods()[self.method_index_group] then
        return nil
    end
    if not self:getMethods()[self.method_index_group].methods[self.method_index] then
        return nil
    end
    return self:getMethods()[self.method_index_group].methods[self.method_index].data
end

-- Get the Field at index
-- @return: Field - the field object
function Node:getField()
    if not self.field_index_group or not self.field_index then
        return nil
    end
    return self:getFields()[self.field_index_group].fields[self.field_index].data
end

-- Get the fields of the value type
-- @deep: boolean - Defaults to true, if true, get fields from parent types as well
-- @return: table - a table of {type, {name, type}}
function Node:getFields(deep)
    if deep == nil then
        deep = true
    end
    local type = self:getStartingValueType()
    local fieldsTable = {}
    while type do
        local fields = type:get_fields()
        local fieldTable = {}
        for _, field in ipairs(fields) do
            table.insert(fieldTable, {
                name = field:get_name(),
                type = field:get_type():get_name(),
                data = field
            })
        end
        table.insert(fieldsTable, {
            type = type:get_name(),
            fields = fieldTable
        })
        if not deep then
            break
        end
        type = type:get_parent_type()
    end
    return fieldsTable
end

-- Get the array index
-- @return: number - the array index
function Node:getArrayIndex()
    if not self.array_index then
        return nil
    end
    return self.array_index
end

-- Perform the action based on the operation and Type
-- @updateChildren: boolean - if true, update children values
function Node:run(updateChildren)
    if updateChildren == nil then
        updateChildren = true
    end

    if not self.starting_value then -- Check if starting value is set
        self.status = "Failed: Starting value - Not set"
        self.ending_value = nil
        return
    elseif self.operation == Node._OPERATION.METHOD then -- Methods (Get/Set/Call)
        local method = self:getMethod()

        if not method then -- Check if selected method is valid
            self.status = "Failed: Method - Not selected"
            self.ending_value = nil
            return
        end

        if self.type == Node._TYPE.GET then -- If type is Get

            if method.args then -- If method has arguments
                if not self.method_args then -- Check if args provided
                    self.status = "Failed: Method/Get - No args provided"
                    self.ending_value = nil
                elseif self.method_args and #self.method_args ~= #method.args then -- Check if args provided match length of method args
                    self.status = "Failed: Method/Get - Invalid arguments"
                    self.ending_value = nil
                else -- Call method with args
                    self.status = "Success: Method/Get w/ args"
                    self.ending_value = method:call(self.starting_value, self.method_args)
                end

            else -- Call method without args
                self.status = "Success: Method/Get"
                self.ending_value = method:call(self.starting_value)
            end

        elseif self.type == Node._TYPE.SET then -- If type is Set

            if not self.set_active then -- Check if set is active
                self.status = "Waiting: Method/Set - Set not active"

            elseif method:get_num_params() > 0 then -- If method has arguments
                if not self.method_args then -- Check if args provided
                    self.status = "Failed: Method/Set - No args provided"
                    self.ending_value = nil
                elseif self.method_args and #self.method_args ~= method:get_num_params() then -- Check if args provided match length of method args
                    self.status = "Failed: Method/Set - Invalid arguments"
                    self.ending_value = nil
                else -- Call method with args
                    self.status = "Success: Method/Set w/ args"
                    self.ending_value = method:call(self.starting_value, self.method_args)
                end

            else -- Call method without args
                self.status = "Success: Method/Set"
                self.ending_value = method:call(self.starting_value)
            end

        elseif self.type == Node._TYPE.CALL then -- If type is Call
            if not self.call_active and not self.call_was_active then -- Check if call is active
                self.status = "Waiting: Method/Call - Call not active"
            end
            if method:get_num_params() > 0 then -- If method has arguments
                if not self.method_args then -- Check if args provided
                    self.status = "Failed: Method/Call - No args provided"
                    self.ending_value = nil
                elseif self.method_args and #self.method_args ~= method:get_num_params() then -- Check if args provided match length of method args
                    self.status = "Failed: Method/Call - Invalid arguments"
                    self.ending_value = nil
                elseif self.call_active then -- Call method with args
                    self.ending_value = method:call(self.starting_value, self.args)
                    self.status = "Success: Method/Call w/ args"
                    self.call_active = false
                    self.call_was_active = true
                end

            elseif self.call_active then -- Call method without args
                self.ending_value = method:call(self.starting_value)
                self.status = "Success: Method/Call"
                self.call_active = false
                self.call_was_active = true
            end
        end

    elseif self.operation == Node._OPERATION.FIELD then -- Fields (Get/Set)
        local field = self:getField()

        if not field then -- Check if selected field is valid
            self.status = "Failed: Field - Not found"
            self.ending_value = nil
            return
        end

        if self.type == Node._TYPE.GET then -- If type is Get
            self.ending_value = self.starting_value:get_field(field:get_name())
            self.status = "Success: Field/Get"

        elseif self.type == Node._TYPE.SET then -- If type is Set
            if not self.set_active then -- Check if set is active
                self.status = "Waiting: Field/Set - Set not active"
            else -- Set field value
                self.starting_value:set_field(field:get_name(), self.field_setValue)
                self.ending_value = self.starting_value:get_field(field:get_name())
                self.status = "Success: Field/Set"
            end
        end

    elseif self.operation == Node._OPERATION.ARRAY_INDEX then -- Array Index (Get/Set)
        local index = self:getArrayIndex()

        if not index then -- Check if selected index is valid
            self.status = "Failed: ArrayIndex - Not selected"
        end

        if self.type == Node._TYPE.GET then -- If type is Get
            self.ending_value = self.starting_value[index]
            self.status = "Success: ArrayIndex/Get"
        elseif self.type == Node._TYPE.SET then -- If type is Set
            if not self.set_active then -- Check if set is active
                self.status = "Waiting: ArrayIndex/Set - Set not active"
            else -- Set array index value
                self.starting_value[index] = self.array_setValue
                self.ending_value = self.starting_value[index]
                self.status = "Success: ArrayIndex/Set"
            end
        end
    end

    -- Update starting value of all children
    if updateChildren then
        for _, child in ipairs(self.children) do
            child:setStartingValue(self.ending_value)
        end
    end
end

-- Get all children
function Node:getChildren()
    if not self.children then
        self.children = {}
    end
    return self.children
end

-- Using imnodes and imgui draw the node
-- @param drawChildren: boolean - if true, draw children nodes as well
function Node:draw(drawChildren)
    if drawChildren == nil then
        drawChildren = true
    end



    for _, child in ipairs(self:getChildren()) do
        child:draw(drawChildren)
    end
end

-- Get a JSON dump of the node
function Node:print()
    return json.dump_string(self, {
        indent = true
    })
end

return Node
