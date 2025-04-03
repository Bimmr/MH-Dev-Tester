local Node = require("DevTester.Node")
local Starter = require("DevTester.Starter")
local Config = require("DevTester.Config")
local HybridCombo = require("DevTester.HybridCombo")

local re = re
local imgui = imgui
local imnodes = imnodes
local json = json
local sdk = sdk
local table = table

local NODE_WIDTH = 300

local starters = {}

local node_count = 0
local link_count = 0
local connecter_count = 0

local nodes_moved = {}

-- Increase the node count and return the new count
local function nextNodeCount()
    node_count = node_count + 1
    return node_count
end
-- Increase the link count and return the new count
local function nextLinkCount()
    link_count = link_count + 1
    return link_count
end
-- Increase the connecter count and return the new count
local function nextConnecterCount()
    connecter_count = connecter_count + 1
    return connecter_count
end

-- Draw the tooltip
local function tooltip(text)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        imgui.set_tooltip("  " .. text .. "  ")
    end
end

-- Save the data to the config file
local function save(name)
    if name == nil then
        name = "DevTester"
    end
    if starters == nil or starters == {} then
        return
    end
    local data = {
        node_count = node_count,
        link_count = link_count,
        connecter_count = connecter_count,
        starters = starters
    }
    Config.saveConfig(name, data)
end

-- Load the data from the config file
local function load(name)
    if name == nil then
        name = "DevTester"
    end
    local file = Config.getConfig(name)
    if file == nil or file == {} then
        return
    end

    local function addChild(parent, data)
        local child = Node:new()
        child.operation = data.operation
        child.type = data.type
        child.status = data.status
        child.array_index = data.array_index
        child.array_setValue = data.array_setValue
        child.call_active = data.call_active or false
        child.set_active = data.set_active or false
        child.parent_is_starter = data.parent_is_starter or false
        child.node_id = data.node_id
        child.node_pos = data.node_pos
        child.input_attr = data.input_attr
        child.output_attr = data.output_attr
        if data.method_data then
            child.method_data = data.method_data
            child.field_data = data.field_data
        end

        parent:addChild(child)
        
        if not data.method_data then
           
            local type_key = child:getStartingTypeName()
            if type_key then
                child.method_data[type_key] = {
                    combo = data.method_combo,
                    group_index = data.method_index_group,
                    index = data.method_index,
                    args = data.method_args
                }
                child.field_data[type_key] = {
                    combo = data.field_combo,
                    group_index = data.field_index_group,
                    index = data.field_index,
                    set_value = data.field_setValue
                }
            end
        end

        if data.children ~= nil then
            for _, child_data in ipairs(data.children) do
                addChild(child, child_data)
            end
        end
    end

    for i, starter in ipairs(file.starters) do
        local new_starter = Starter:new()
        new_starter.path = starter.path
        new_starter.type = starter.type
        new_starter.hook_methodName = starter.hook_methodName
        new_starter.hook_timing = starter.hook_timing
        new_starter.hook_active = starter.hook_active
        new_starter.node_id = starter.node_id
        new_starter.node_pos = starter.node_pos
        new_starter.output_attr = starter.output_attr
        if starter.children then
            for _, child_data in ipairs(starter.children) do
                addChild(new_starter, child_data)
            end
        end

        table.insert(starters, new_starter)
    end
    node_count = file.node_count
    link_count = file.link_count
    connecter_count = file.connecter_count

end

-- Reset the node and link counts
local function reset()
    starters = {}
    node_count = 0
    link_count = 0
    connecter_count = 0
    nodes_moved = {}
end

local window_open = false
local file_save_name = "DevTester"
local file_load_combo_index = 0
re.on_draw_ui(function()
    if imgui.button("DevTester") then
        window_open = not window_open
    end

    if window_open then

        imgui.push_style_var(3, 7.5) -- Rounded window
        imgui.push_style_var(12, 5.0) -- Rounded elements
        imgui.push_style_var(11, Vector2f.new(5, 5)) -- Extra padding

        window_open = imgui.begin_window("[Dev Tester]", window_open, 1024)

        imgui.push_style_var(2, Vector2f.new(5, 5)) -- Extra padding on menu bar
        if imgui.begin_menu_bar() then
            if imgui.begin_menu("File") then
                if imgui.begin_menu("Save", nil, false) then
                    imgui.spacing()
                    imgui.text("Enter a save name:")
                    local changed = false
                    changed, file_save_name = imgui.input_text("File Name", file_save_name)
                    if imgui.button("Save") then
                        save(file_save_name)
                        re.msg("Saved config to " .. file_save_name)
                    end
                    imgui.spacing()
                    imgui.end_menu()
                end
                if imgui.begin_menu("Load", nil, false) then
                    imgui.spacing()
                    imgui.text("Select a file to load:")
                    local files = Config.getAllConfigs()
                    local file_names = {}
                    for name, _ in pairs(files) do
                        table.insert(file_names, name)
                    end
                    local changed = false
                    changed, file_load_combo_index = imgui.combo("Files", file_load_combo_index, file_names)
                    if imgui.button("Load") then
                        local file_name = file_names[file_load_combo_index]
                        if file_name ~= nil then
                            reset()
                            load(file_name)
                            file_save_name = file_name
                        end
                    end
                    imgui.same_line()
                    if imgui.button("Delete") then
                        local file_name = file_names[file_load_combo_index]
                        if file_name ~= nil then
                            Config.deleteConfig(file_name)
                            re.msg("Config file " .. file_save_name.. " deleted")
                        end
                    end

                    imgui.spacing()
                    imgui.end_menu()
                end
                imgui.end_menu()
            end
            if imgui.menu_item("Clear Nodes") then
                reset()
            end
            if imgui.menu_item("+ Create Starter") then
                local starter = Starter:new()
                table.insert(starters, starter)
            end

            imgui.end_menu_bar()
        end

        imgui.pop_style_var()
        imnodes.begin_node_editor()
        imgui.push_item_width(NODE_WIDTH)

        imgui.push_style_color(21, 0xFF714A29) -- AABBGGRR (Button Colour)
        imgui.push_style_color(22, 0xFFFA9642) -- AABBGGRR (Button Hover Colour)
        imnodes.push_color_style(1, 0xFF3C3C3C) -- AABBGGRR (Hover Background Colour)
        imnodes.push_color_style(2, 0xFF3C3C3C) -- AABBGGRR (Selected Background Colour)

        -- Draw the starter nodes
        for i, starter in ipairs(starters) do

            -- Draw the starter node
            local changed, type_index

            -- Draw the starter
            if starter.node_id == nil then
                starter.node_id = nextNodeCount()
            end
            imnodes.begin_node(starter.node_id)

            -- Draw starter controls
            imnodes.begin_node_titlebar()
            changed, starter.type = imgui.combo("Type", starter.type, {"Managed", "Hook"})
            imnodes.end_node_titlebar()
            changed, starter.path = imgui.input_text("Path", starter.path)

            if starter.type == Starter._TYPE.HOOK then
                changed, starter.hook_methodName = imgui.input_text("Method Name", starter.hook_methodName)
                changed, starter.hook_timing = imgui.combo("Hook Timing", starter.hook_timing, {"Pre", "Post"})

                if starter:isHookActive() then
                    imgui.begin_disabled()
                    changed, starter.hook_active = imgui.checkbox("Active", starter.hook_active)
                    imgui.end_disabled()
                else
                    if imgui.button("Initalize hook") then
                        starter:startHook()
                    end
                end
            end

            imgui.spacing()
            imgui.spacing()
            imgui.spacing()

            -- Run the starter
            starter:run()

            local can_continue = false
            if starter.ending_value ~= nil then
                can_continue = type(starter.ending_value) == "userdata"
            end

            local output = starter.status
            if can_continue then

                -- Create starter output attribute
                starter.output_attr = starter.output_attr or nextConnecterCount()
                imnodes.begin_output_attribute(starter.output_attr)

                if starter.ending_value ~= nil then
                    output = starter.ending_value:get_type_definition():get_name()
                end
                local output_pos = imgui.get_cursor_pos()
                output_pos.x = output_pos.x + NODE_WIDTH - imgui.calc_text_size(output).x + 30
                imgui.set_cursor_pos(output_pos)
                imgui.text(output)
                imnodes.end_output_attribute()

                imgui.spacing()
                imgui.spacing()
                imgui.spacing()
            end

            local new_node_pos = imgui.get_cursor_pos()
            if imgui.button("- Remove Node") then
                table.remove(starters, i)
            end

            if can_continue then
                imgui.same_line()
                new_node_pos.x = new_node_pos.x + NODE_WIDTH - imgui.calc_text_size("+ Create Node").x + 30
                imgui.set_cursor_pos(new_node_pos)
                if imgui.button("+ Create Node") then
                    starter:addChild(Node:new())
                end

            end
            imnodes.end_node()
            if not nodes_moved[starter.node_id] then
                if starter.node_pos then
                    imnodes.set_node_editor_space_pos(starter.node_id, starter.node_pos.x, starter.node_pos.y)
                end
                nodes_moved[starter.node_id] = true
            end
            if not starter.node_pos then
                starter.node_pos = {}
            end
            local pos = imnodes.get_node_editor_space_pos(starter.node_id)
            starter.node_pos = {
                x = pos.x,
                y = pos.y
            }

            -- Draw the node and setup the link
            local function drawNode(node)

                if node.node_id == nil then
                    node.node_id = nextNodeCount()
                end

                imgui.push_id(node.node_id)
                imnodes.begin_node(node.node_id)

                -- Create the input attribute
                if not node.input_attr then
                    node.input_attr = nextConnecterCount()
                end

                -- Create the node title bar
                imnodes.begin_node_titlebar()
                imnodes.begin_input_attribute(node.input_attr)
                imgui.text(node:getStartingTypeName())
                imnodes.end_input_attribute()
                imnodes.end_node_titlebar()

                imgui.spacing()
                imgui.spacing()
                imgui.spacing()

                -- Display the node controls
                changed, node.operation = imgui.combo("Operation", node.operation, {"Method", "Field", "Array"})
                local types = {"Get", "Set", "Call"}

                -- Remove the "Call" option if not a method
                if node.operation ~= Node._OPERATION.METHOD then
                    table.remove(types, 3)
                end
                changed, node.type = imgui.combo("Type", node.type, types)

                -- Method operation
                if node.operation == Node._OPERATION.METHOD then
                    local method_entry = node:getMethodData()

                    local methods = node:getMethods()
                    local all_methods = {""}

                    for i, method_parent in ipairs(methods) do
                        table.insert(all_methods, "\n" .. method_parent.type)
                        for j, method in ipairs(method_parent.methods) do
                            local args = table.concat(method.args, ", ")
                            table.insert(all_methods, string.format("%d-%d.   %s(%s) | %s", i, j, method.name, args, method.returnType))
                        end
                    end

                    changed, method_entry.combo = imgui.combo("Method", method_entry.combo, all_methods)
                    if changed and method_entry.combo > 1 then
                        local combo_method = all_methods[method_entry.combo]
                        local method_type_group, method_index = combo_method:match("(%d+)-(%d+)")
                        method_entry.group_index = tonumber(method_type_group)
                        method_entry.index = tonumber(method_index)

                        node.call_was_active = false
                        if node.type == Node._TYPE.CALL then
                            node.ending_value = nil
                        end
                    end

                    local method = node:getMethod()
                    if method then
                        if method:get_num_params() > 0 then
                            if method_entry.args == nil then
                                method_entry.args = {}
                            end
                            for i, arg in ipairs(method:get_param_types()) do
                                changed, method_entry.args[i] = imgui.input_text(
                                    "Arg " .. i .. "(" .. arg:get_name() .. ")", method_entry.args[i])
                                if changed then
                                    node.call_was_active = false
                                end
                            end
                        end
                    end

                    if node.type == Node._TYPE.SET then
                        changed, node.set_active = imgui.checkbox("Active", node.set_active)
                    elseif node.type == Node._TYPE.CALL then
                        if imgui.button("Call") then
                            node.call_active = true
                        end
                    end

                elseif node.operation == Node._OPERATION.FIELD then
                    local field_entry = node:getFieldData()

                    local fields = node:getFields()
                    local all_fields = {""}

                    for i, field_parent in ipairs(fields) do
                        table.insert(all_fields, "\n" .. field_parent.type)
                        for j, field in ipairs(field_parent.fields) do
                            table.insert(all_fields, string.format("%d-%d.   %s | %s", i, j, field.name, field.type))
                        end
                    end

                    changed, field_entry.combo = imgui.combo("Field", field_entry.combo, all_fields)
                    if changed then
                        local combo_field = all_fields[field_entry.combo]
                        local field_type_group, field_index = combo_field:match("(%d+)-(%d+)")
                        field_entry.group_index = tonumber(field_type_group)
                        field_entry.index = tonumber(field_index)

                        node.set_active = false
                    end

                    if node.type == Node._TYPE.SET then
                        changed, field_entry.set_value = imgui.input_text("Set Value", field_entry.set_value)
                        changed, node.set_active = imgui.checkbox("Active", node.set_active)
                    end

                elseif node.operation == Node._OPERATION.ARRAY then
                    local array_entry = node:getArrayData()
                    local array_values = node.starting_value
                    local all_array_values = {""}
                    
                    if type(array_values) ~= "table" and type(array_values) ~= "userdata" then
                        array_values = {}
                    end

                    for i, array_value in ipairs(array_values) do
                        if type(array_value) == "userdata" then
                            array_value = array_value:get_type_definition():get_name()
                        else
                            array_value = tostring(array_value)
                        end
                        table.insert(all_array_values, string.format("%d.   %s", i, array_value))
                    end
                    
                    local can_left = array_entry.combo and array_entry.combo > 1
                    local can_right = array_entry.combo and array_entry.combo < #array_values
                    local width_of_array_combo = imgui.calc_item_width()
                    
                    if can_left and can_right then
                        width_of_array_combo = width_of_array_combo - 20
                    end
                    imgui.set_next_item_width(width_of_array_combo)
                    changed, array_entry.combo = imgui.combo("Array", array_entry.combo, all_array_values)
                    if can_left then
                        imgui.same_line()
                        if imgui.arrow_button("Left", 0) then
                            array_entry.combo = array_entry.combo - 1
                            changed = true
                        end
                    end
                    if can_right then
                        imgui.same_line()
                        if imgui.arrow_button("Right", 1) then
                            array_entry.combo = array_entry.combo + 1
                            changed = true
                        end
                    end 
                    if changed then
                        local combo_array = all_array_values[array_entry.combo]
                        local array_index = combo_array:match("(%d+)")
                        array_entry.index = tonumber(array_index)
                        array_entry.set_value = nil
                    end

                    if node.type == Node._TYPE.SET then
                        changed, array_entry.set_value = imgui.input_text("Set Value", array_entry.set_value)
                        changed, node.set_active = imgui.checkbox("Active", node.set_active)
                    end
                end

                imgui.spacing()
                imgui.spacing()
                imgui.spacing()

                -- Run the node
                node:run()

                -- Create the output attribute
                local output = node.ending_value
                local can_continue = type(output) == "userdata"

                if node.output_attr == nil and can_continue then
                    node.output_attr = nextConnecterCount()
                end

                local output_text = tostring(output)
                if node.starting_value == nil then
                    can_continue = false
                    output_text = node.status
                elseif can_continue then
                    output_text = node.ending_value:get_type_definition():get_name().. " | " .. node.ending_value:get_address()
                end
                if tostring(output) == "Void" then
                    can_continue = false
                    output_text = output
                end
                local output_pos = imgui.get_cursor_pos()
                output_pos.x = output_pos.x + NODE_WIDTH - imgui.calc_text_size(output_text).x + 45
                imgui.set_cursor_pos(output_pos)

                imnodes.begin_output_attribute(node.output_attr)

                imgui.text(output_text)
                tooltip(node.status)

                imnodes.end_output_attribute()

                imgui.spacing()
                imgui.spacing()
                imgui.spacing()

                local new_node_pos = imgui.get_cursor_pos()
                if imgui.button("- Remove Node") then
                    node:remove()
                end

                imgui.same_line()

                -- Add a new child node
                new_node_pos.x = new_node_pos.x + NODE_WIDTH - imgui.calc_text_size("+ Create Node").x + 45
                imgui.set_cursor_pos(new_node_pos)
                if can_continue and imgui.button("+ Add Child Node") then
                    local new_node = Node:new()
                    node:addChild(new_node)
                end

                imnodes.end_node()
                imgui.pop_id()

                if not nodes_moved[node.node_id] then
                    if node.node_pos then
                        imnodes.set_node_editor_space_pos(node.node_id, node.node_pos.x, node.node_pos.y)
                    else
                        local parent_node_pos = imnodes.get_node_editor_space_pos(node:getParent().node_id)
                        local y_offset_range = 300
                        local y_offset = math.random(1, y_offset_range) - y_offset_range / 2
                        local new_pos = Vector2f.new(parent_node_pos.x + NODE_WIDTH + 100, parent_node_pos.y + y_offset)
                        imnodes.set_node_editor_space_pos(node.node_id, new_pos.x, new_pos.y)
                    end
                    nodes_moved[node.node_id] = true
                end
                if not node.node_pos then
                    node.node_pos = {}
                end
                local pos = imnodes.get_node_editor_space_pos(node.node_id)
                node.node_pos = {
                    x = pos.x,
                    y = pos.y
                }
            end

            -- Recursively draw the child nodes
            local function drawChildNodes(starter)
                local children = starter:getChildren()
                for i, child in ipairs(children) do
                    drawNode(child)

                    -- Draw the link between the starter and the child node
                    -- Make it red if the starting value of the child is nil
                    local starting_value_nil = starter.ending_value == nil
                    if starting_value_nil then
                        imnodes.push_color_style(7, 0x80142196) -- AABBGGRR
                    end
                    imnodes.link(nextLinkCount(), child:getParent().output_attr, child.input_attr)
                    if starting_value_nil then
                        imnodes.pop_color_style()
                    end

                    -- Recursively draw the child nodes
                    drawChildNodes(child)
                end
            end

            -- Draw the child nodes
            drawChildNodes(starter)

        end

        imnodes.pop_color_style(2)
        imgui.pop_style_color(2)
        imgui.pop_item_width()
        imnodes.minimap(0.2, 0)
        imnodes.end_node_editor()

        imgui.end_window()
        imgui.pop_style_var(3)
    
    end

end)
