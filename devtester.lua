local calls = {{
    path = "app.PlayerManager",
    type = 1,
    instructions = {{
        type = "Method",
        operation = "Get",
        method_get = "getMasterPlayerInfo"
    }, {
        type = "Field",
        operation = "Get",
        field_get = "<Character>k__BackingField"
    }, {
        type = "Method",
        operation = "Get",
        method_get = "get_WeaponHandling"
    }}
}, {
    path = "app.PlayerManager",
    type = 1,
    instructions = {{
        type = "Method",
        operation = "Get",
        method_get = "getMasterPlayerInfo"
    }, {
        type = "Field",
        operation = "Get",
        field_get = "<Character>k__BackingField"
    }, {
        type = "Method",
        operation = "Get",
        method_get = "get_WeaponHandling"
    }, {
        type = "Field",
        operation = "Get",
        field_get = "_Ammos"
    }, {
        type = "ArrayIndex",
        operation = "Get",
        array_get = "0"
    }}
}, {
    path = "app.cHunterStatus",
    type = 2,
    method = "update",
    time = 1,
    prehook = 2,
    instructions = {{
        type = "",
        operation = "",
        getValue = "",
        setValue = ""
    }}
}}
-- Draw the tooltip
local function tooltip(text)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then
        imgui.set_tooltip("  " .. text .. "  ")
    end
end
-- Stringify or dump the object to string
local function stringify(obj)
    if type(obj) == "table" then
        obj = json.dump_string(obj)
    else
        obj = tostring(obj)
    end
    return obj
end


-- Get the type definition of the instruction at index
local function getInitTypeDefinition(call, index)
    return getInitTypeDefinition(call.instructions[index])
end

-- Get the return type definition of the instruction
local function getInitTypeDefinition(instruction)
    local test, typeDefinition = pcall(function()
        return instruction.initValue:get_type_definition()
    end)
    if not test then
        return nil
    end
    return typeDefinition
end

-- Get the return type definition of the instruction
local function getReturnTypeDefinition(instruction)
    local test, typeDefinition = pcall(function()
        return instruction.returnValue:get_type_definition()
    end)
    if not test then
        return nil
    end
    return typeDefinition
end

-- Perform the instructions
local function performInstruction(instruction)
    local lastReturnValue = instruction.initValue

    -- Handle Method type instructions
    if instruction.type == "Method" then

        -- Get
        if instruction.operation == "Get" then

            if instruction.method_get == nil or instruction.method_get == "" then -- Make sure there is a value to get
                instruction.status = "Failed - No get method selected"

            elseif instruction.method_args and #instruction.method_args > 0 then -- With args
                instruction.returnValue = lastReturnValue:call(instruction.method_get, instruction.method_args)
                instruction.status = "Success - get with args"

            else -- Without args
                instruction.returnValue = lastReturnValue:call(instruction.method_get)
                instruction.status = "Success - Get"
            end

        elseif instruction.operation == "Set" then -- Set

            if instruction.method_set == nil or instruction.method_set == "" then -- Check if set method selected
                instruction.status = "Failed - No set method selected"

            elseif instruction.method_args ~= nil and #instruction.method_args == 0 then -- Make sure there is a value to set
                instruction.status = "Failed - Missing args"

            elseif instruction.method_start ~= true then -- Check if started setting
                instruction.status = "Waiting - Not activated"

            elseif instruction.method_args and #instruction.method_args > 0 then -- With args
                lastReturnValue:call(instruction.method_set, instruction.method_args)
                instruction.status = "Success - Set with args"
            else -- Without args
                lastReturnValue:call(instruction.method_set)
                instruction.status = "Success - Set"
            end
        end

        -- Handle Field type instructions
    elseif instruction.type == "Field" then
        if instruction.operation == "Get" then

            if instruction.field_get == nil or instruction.field_get == "" then -- Check if field selected
                instruction.status = "Failed - No get field selected"
            else
                instruction.returnValue = lastReturnValue:get_field(instruction.field_get)
                instruction.status = "Success - Get"
            end
        elseif instruction.operation == "Set" then

            if instruction.field_set == nil or instruction.field_set == "" then -- Make sure there is a value to set
                instruction.status = "Failed - No value to set"

            elseif instruction.field_start ~= true then -- Check if started setting
                instruction.status = "Waiting - Not activated"

            else
                lastReturnValue:set_field(instruction.field_set, instruction.field_value) -- Set the field 
                instruction.status = "Success - Set"
            end
        end

        -- Handle ArrayIndex type instructions
    elseif instruction.type == "ArrayIndex" then
        if instruction.operation == "Get" then
            instruction.returnValue = lastReturnValue[tonumber(instruction.array_get)]
            instruction.status = "Success - Get"
        elseif instruction.operation == "Set" then

            if instruction.array_start ~= true then -- Check if started setting
                instruction.status = "Waiting - Not activated"
            else
                lastReturnValue[tonumber(instruction.array_set)] = instruction.array_value
                instruction.status = "Success - Set"
            end
        end
    end

    return instruction
end

-- Init Hooks
local function initHook(hook)

    local path = sdk.find_type_definition(hook.path)
    if not path then
        hook.status = "Path not found"
        hook.isHooked = false
        return
    end
    path = path:get_method(hook.method)
    if not path then
        hook.status = "Method not found"
        hook.isHooked = false
        return
    end

    -- Initialize the hook
    sdk.hook(path, function(args)
        local managed = sdk.to_managed_object(args[2])
        if not managed then
            return
        end
        if not managed:get_type_definition():is_a(hook.path) then
            return
        end

        if hook.time == 1 then
            hook.instructions[1].initValue = managed
        else
            hook.managed = managed
        end

        if hook.prehook == 2 then
            return sdk.PreHookResult.SKIP_ORIGINAL
        end
    end, function(retval)
        if hook.managed then
            hook.managed = nil
            if hook.time == 2 then
                hook.instructions[1].initValue = retval
            end
        end
        return retval
    end)
end

local function drawCallMenu()
    local changed = false
    imgui.begin_window("Dev Menu - Calls", nil)
    -- Loop through calls
    for i, call in ipairs(calls) do
        if imgui.collapsing_header("Call #" .. i) then
            imgui.indent(10)
            imgui.spacing()

            if call.isHooked then
                imgui.text("[Hooked]")
            else
                changed, call.type = imgui.combo("Type " .. i, call.type, {"Singleton", "Hook"})
            end
            changed, call.path = imgui.input_text("Path " .. i, call.path)
            if call.type == 2 then
                if not call.isHooked then
                    imgui.same_line()
                    imgui.text("  ")
                    imgui.same_line()
                    if imgui.button("[Create Hook]") then
                        call.isHooked = true
                        initHook(call)
                    end
                end

                changed, call.method = imgui.input_text("Method " .. i, call.method)
                changed, call.time = imgui.combo("Time " .. i, call.time, {"Pre", "Post"})
                changed, call.prehook = imgui.combo("PreHookResult " .. i, call.prehook, {"CALL_ORIGINAL", "SKIP_ORIGINAL"})
            end
            local path = sdk.find_type_definition(call.path)

            print("\n----------\n")
            if call.type == 1 then
                call.initValue = sdk.get_managed_singleton(call.path)
            end

            imgui.spacing()
            imgui.spacing()

            imgui.indent(2)

            -- Make sure calls are valid
            if call.type == 1 and call.path == "" then
                break
            end
            if call.type == 2 and (call.path == "" or call.method == "") then
                break
            end

            -- Loop through instructions
            for i1, instruction in ipairs(call.instructions) do
                if i1 == 1 then
                    if call.type == 1 then
                        print("Singleton " .. i .. stringify(call))
                        call.instructions[1].initValue = call.initValue
                    elseif call.type == 2 then
                        print("Hook " .. i .. stringify(call))
                    end
                end

                -- If an instruction says to use a different instruction's return value, set it
                -- if instruction.use ~= nil then
                --     instruction.initValue = call.instructions[instruction.use].returnValue
                -- end

                -- Get the type definition of the instruction
                local starting_def = getInitTypeDefinition(instruction)

                print("-- Instruction " .. i .. "-" .. i1 .. ": " .. stringify(instruction) .. " " .. stringify(instruction.returnValue))
                imgui.spacing()
                imgui.begin_rect()

                -- Draw the instruction type combo box
                local typeOptions = {"Method", "Field", "ArrayIndex"}
                local instruction_index = instruction.type == "ArrayIndex" and 3 or instruction.type == "Field" and 2 or 1
                changed, instruction_index = imgui.combo("Type " .. i .. "-" .. i1, instruction_index, typeOptions)
                instruction.type = typeOptions[instruction_index]

                -- Draw the operation combo box
                local operationOptions = {"Get", "Set"}
                local operation_index = instruction.operation == "Set" and 2 or 1
                changed, operation_index = imgui.combo("Operation " .. i .. "-" .. i1, operation_index, operationOptions)
                instruction.operation = operationOptions[operation_index]

                -- Handle Method type instructions
                if instruction.type == "Method" then

                    local method_index = 0
                    local method_index_found = false
                    local method_list = {""}

                    local method_list_names = {""}
                    local definition = getInitTypeDefinition(instruction)
                    local depth_prefix = ""

                    -- Drill down through the type definitions to get the methods
                    while definition ~= nil do
                        local methods = definition:get_methods()
                        table.insert(method_list_names, "\n" .. "[" .. definition:get_name() .. "]")
                        table.insert(method_list, "")

                        -- Loop through the methods and add them to the list
                        for _, method in ipairs(methods) do
                            if not method_index_found then
                                method_index = method_index + 1
                            end
                            local params = ""
                            for i2 = 1, method:get_num_params() do
                                params = params .. method:get_param_types()[i2]:get_name()
                                if i2 < method:get_num_params() then
                                    params = params .. ", "
                                end
                            end
                            table.insert(method_list_names, method:get_name() .. "(" .. params .. ")  |  " .. method:get_return_type():get_full_name())
                            table.insert(method_list, method)

                            -- If the method name matches the one being used in the instruction, select it
                            if (instruction.operation == "Get" and method:get_name() == instruction.method_get) or
                                (instruction.operation == "Set" and method:get_name() == instruction.method_set) then
                                method_index = method_index + 2
                                method_index_found = true
                            end
                        end

                        -- If not found, increase the index
                        if not method_index_found then
                            method_index = method_index + 1
                        end
                        definition = definition:get_parent_type()
                    end
                    -- If still not found, set the index to 0
                    if not method_index_found then
                        method_index = 0
                    end

                    changed, method_index = imgui.combo("Method Name " .. i .. "-" .. i1, method_index, method_list_names)
                    if changed and method_list[method_index] ~= "" then
                        if instruction.operation == "Get" then
                            instruction.method_get = method_list[method_index]:get_name()
                        else
                            instruction.method_set = method_list[method_index]:get_name()
                        end
                    end

                    -- If the operation is set, draw the activate button
                    if instruction.operation == "Set" then
                        imgui.same_line()
                        changed, instruction.method_start = imgui.checkbox("Activate" .. i .. "-" .. i1, instruction.method_start)
                    end

                    -- Add args if needed
                    if starting_def and method_list[method_index] ~= "" then

                        local method = method_list[method_index]
                        if method:get_num_params() == 0 then -- no args, remove args from instruction
                            instruction.method_args = nil
                        elseif method:get_num_params() > 0 then -- has args
                            if instruction.method_args == nil then -- Instruction args hasn't been assigned yet
                                instruction.method_args = {}
                            end

                            -- Add empty args for the array if they don't exist
                            for i2 = 1, method:get_num_params() do
                                if instruction.method_args[i2] == nil then
                                    instruction.method_args[i2] = ""
                                end
                                local type = method:get_param_types()[i2]:get_name()
                                changed, instruction.method_args[i2] = imgui.input_text("(" .. type .. ") Method Args " .. i .. "-" .. i1 .. i2, instruction.method_args[i2]) -- Not being added?
                            end
                        end

                        -- Remove extra args
                        if instruction.method_args and #instruction.method_args > method:get_num_params() then
                            for i2 = method:get_num_params() + 1, #instruction.method_args do
                                instruction.method_args[i2] = nil
                            end
                        end
                    end

                    -- Handle Field type instructions
                elseif instruction.type == "Field" then

                    local field_index = 0
                    local field_index_found = false
                    local field_list = {""}
                    local field_list_names = {""}
                    local definition = getInitTypeDefinition(instruction)

                    -- Drill down through the type definitions to get the fields
                    while definition ~= nil do
                        local fields = definition:get_fields()
                        table.insert(field_list_names, "\n" .. "[" .. definition:get_name() .. "]")
                        table.insert(field_list, "")

                        -- Loop through the fields and add them to the list
                        for _, field in ipairs(fields) do
                            if not field_index_found then
                                field_index = field_index + 1
                            end
                            table.insert(field_list_names, field:get_name() .. "  |  " .. field:get_type():get_full_name())
                            table.insert(field_list, field)

                            -- If the field name matches the one being used in the instruction, select it
                            if (instruction.operation == "Get" and field:get_name() == instruction.field_get) or
                                (instruction.operation == "Set" and field:get_name() == instruction.field_set) then
                                field_index = field_index + 2
                                field_index_found = true
                            end
                        end

                        -- If not found, increase the index
                        if not field_index_found then
                            field_index = field_index + 1
                        end
                        definition = definition:get_parent_type()
                    end
                    -- If still not found, set the index to 0
                    if not field_index_found then
                        field_index = 0
                    end

                    changed, field_index = imgui.combo("Field Name " .. i .. "-" .. i1, field_index, field_list_names)
                    if changed and field_list[field_index] ~= "" then
                        if instruction.operation == "Get" then
                            instruction.field_get = field_list[field_index]:get_name()
                        else
                            instruction.field_set = field_list[field_index]:get_name()
                        end
                    end

                    -- Draw the set value input
                    if instruction.operation == "Set" then
                        changed, instruction.field_value = imgui.input_text("Set Value " .. i .. "-" .. i1, instruction.field_value)
                        imgui.same_line()
                        changed, instruction.field_start = imgui.checkbox("Activate" .. i .. "-" .. i1, instruction.field_start)
                    end

                    -- Handle ArrayIndex type instructions
                elseif instruction.type == "ArrayIndex" then

                    local array = instruction.initValue
                    local is_array = pcall(function()
                        return #array
                    end)
                    if array ~= nil and is_array then

                        local numberArray = {}
                        for i3 = 0, #array - 1 do
                            table.insert(numberArray, tostring(i3))
                        end
                        local array_index = 0
                        if instruction.operation == "Set" then
                            array_index = instruction.array_set
                        elseif instruction.operation == "Get" then
                            array_index = instruction.array_get
                        end
                        if array_index == nil or array_index == "" then
                            array_index = 0
                        else
                            array_index = array_index + 1
                        end
                        changed, array_index = imgui.combo("Array Index " .. i .. "-" .. i1, array_index, numberArray)
                        if instruction.operation == "Set" then
                            instruction.array_set = array_index - 1
                        elseif instruction.operation == "Get" then
                            instruction.array_get = array_index - 1
                        end

                        if instruction.operation == "Set" then
                            changed, instruction.array_value = imgui.input_text("Set Value " .. i .. "-" .. i1, instruction.array_value)
                            imgui.same_line()
                            changed, instruction.array_start = imgui.checkbox("Activate" .. i .. "-" .. i1, instruction.array_start)
                        end
                    else
                        instruction.status = "Failed - Not an array"
                        instruction.returnValue = nil
                    end

                end

                -- Draw the status and value
                if instruction.returnValue ~= nil and instruction.operation ~= "Set" then
                    imgui.begin_disabled()
                    imgui.input_text("Returned Value " .. i .. "-" .. i1, stringify(instruction.returnValue), 16384)
                    imgui.end_disabled()
                    tooltip(instruction.status)
                else
                    imgui.begin_disabled()
                    imgui.input_text("Status " .. i .. "-" .. i1, instruction.status, 16384)
                    imgui.end_disabled()
                end

                imgui.spacing()
                imgui.end_rect(5, 1)
                imgui.spacing()
                imgui.spacing()

                -- Perform the instruction
                if starting_def then
                    performInstruction(instruction)
                    if i1 < #call.instructions then

                        -- If setting, pass the inital value back to the next instruction to chain them
                        if instruction.operation == "Set" then
                            call.instructions[i1 + 1].initValue = instruction.initValue
                        else
                            call.instructions[i1 + 1].initValue = instruction.returnValue
                        end
                    end
                else
                    instruction.status = "Failed - No type definition"
                    instruction.returnValue = nil
                end
            end
            local disable_add_instruction_button, disable_remove_instruction_button = false, false
            if call.instructions and #call.instructions > 0 then
                local last_instruction = call.instructions[#call.instructions]
                local return_def = getReturnTypeDefinition(last_instruction)
                if not return_def and last_instruction.operation == "Get" then
                    disable_add_instruction_button = true
                end
            elseif not call.instructions or #call.instructions == 0 then
                disable_remove_instruction_button = true
            end

            if disable_add_instruction_button then
                imgui.begin_disabled()
            end
            if imgui.button("Add New Instruction") then
                table.insert(call.instructions, {
                    type = "",
                    operation = "",
                    getValue = "",
                    setValue = ""
                })
            end
            if disable_add_instruction_button then
                imgui.end_disabled()
            end

            imgui.same_line()
            if disable_remove_instruction_button then
                imgui.begin_disabled()
            end
            if imgui.button("Remove Last Instruction") then
                table.remove(call.instructions, #call.instructions)
            end
            if disable_remove_instruction_button then
                imgui.end_disabled()
            end
            imgui.spacing()
            imgui.spacing()
            imgui.spacing()
            imgui.spacing()
            imgui.unindent(12)

        end
    end
    imgui.separator()
    imgui.spacing()
    if imgui.button("Add New Call") then
        table.insert(calls, {
            path = "",
            instructions = {{
                type = "",
                operation = "",
                getValue = "",
                setValue = ""
            }}
        })
    end
    imgui.same_line()
    if imgui.button("Remove Last Call") then
        table.remove(calls, #calls)
    end
    imgui.end_window()
end

re.on_draw_ui(function()
    drawCallMenu()
end)
