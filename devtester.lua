local calls = { 
{
    path = "app.PlayerManager",
    type = 1,
    instructions = {{
        type = "Method",
        operation = "Get",
        getValue = "getMasterPlayerInfo"
    }, {
        type = "Field",
        operation = "Get",
        getValue = "<Character>k__BackingField"
    }, {
        type = "Method",
        operation = "Get",
        getValue = "get_WeaponHandling"
    }}
},
{
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
}
}

local function stringify(obj)
    if type(obj) == "table" then
        obj = json.dump_string(obj)
    else
        obj = tostring(obj)
    end
    return obj
end



local function tooltip(text)
    imgui.same_line()
    imgui.text("(?)")
    if imgui.is_item_hovered() then imgui.set_tooltip("  "..text.."  ") end
end

local function getInitTypeDefinition(call, index)
    return getInitTypeDefinition(call.instructions[index])
end

local function getInitTypeDefinition(instruction)
    local test, lastTypeDefinition = pcall(function() return instruction.initValue:get_type_definition() end)
    if not test then
        return nil
    end
    return lastTypeDefinition
end

local function getReturnTypeDefinition(instruction)
    local test, lastTypeDefinition = pcall(function() return instruction.returnValue:get_type_definition() end)
    if not test then
        return nil
    end
    return lastTypeDefinition
end


local function performInstruction(instruction)
    local lastReturnValue = instruction.initValue

    -- Handle Method type instructions
    if instruction.type == "Method" then

        -- Get
        if instruction.operation == "Get" then

            -- Make sure there is a value to get
            if instruction.getValue == nil or instruction.getValue == "" then
                instruction.status = "Failed - No value to get"

            -- With args
            elseif instruction.args and instruction.args ~= "" then
                instruction.returnValue = lastReturnValue:call(instruction.getValue, instruction.args)
                instruction.status = "Success with Args"
            -- Without args
            else
                instruction.returnValue = lastReturnValue:call(instruction.getValue)
                instruction.status = "Success"
            end
        -- Set   
        elseif instruction.operation == "Set" then

            -- Make sure there is a value to set
            if instruction.setValue == nil or instruction.setValue == "" then
                instruction.status = "Failed - No value to set"
            -- Check if started setting
            elseif instruction.startSetting ~= true then
                instruction.status = "Waiting - Not Activated"
            -- With args
            elseif instruction.args and instruction.args ~= ""  then
                lastReturnValue:call(instruction.getValue, instruction.setValue)
                instruction.status = "Set Success with Args"
            -- Without args
            else
                lastReturnValue:call(instruction.getValue)
                instruction.status = "Set Success"
            end
        end

    -- Handle Field type instructions
    elseif instruction.type == "Field" then
        if instruction.operation == "Get" then
            if instruction.getValue == nil or instruction.getValue == "" then
                instruction.status = "Failed - No value to get"
            else
                instruction.returnValue = lastReturnValue:get_field(instruction.getValue)
                instruction.status = "Success"
            end
        elseif instruction.operation == "Set" then
            
            -- Make sure there is a value to set
            if instruction.setValue == nil or instruction.setValue == "" then
                instruction.status = "Failed - No value to set"
            -- Check if started setting
            elseif instruction.startSetting ~= true then
                instruction.status = "Waiting - Not Activated"
            -- Set the field    
            else
                lastReturnValue:set_field(instruction.getValue, instruction.setValue)
                instruction.status = "Set Success"
            end
        end

    -- Handle ArrayIndex type instructions
    elseif instruction.type == "ArrayIndex" then
        if instruction.operation == "Get" then
            instruction.returnValue = lastReturnValue[tonumber(instruction.getValue)]
            instruction.status = "Success"
        elseif instruction.operation == "Set" then
            lastReturnValue[tonumber(instruction.getValue)] = instruction.setValue
            instruction.status = "Set Success"
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
    sdk.hook(path, function(args)
        local managed = sdk.to_managed_object(args[2])
        if not managed then return end
        if not managed:get_type_definition():is_a(hook.path) then return end

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
                changed, call.prehook = imgui.combo("PreHookResult " .. i, call.prehook,
                    {"CALL_ORIGINAL", "SKIP_ORIGINAL"})
            end
            local path = sdk.find_type_definition(call.path)

            print("\n----------\n")
            if call.type == 1 then
                call.initValue = sdk.get_managed_singleton(call.path)
            end
            
            imgui.spacing()
            imgui.spacing()
            

            imgui.indent(2)
            -- Loop through instructions

            if call.type == 1 and call.path == "" then break end
            if call.type == 2 and (call.path == "" or call.method == "") then break end 

            for i1, instruction in ipairs(call.instructions) do
                if i1 == 1 then
                    if call.type == 1 then
                        print("Singleton " .. i .. stringify(call))
                        call.instructions[1].initValue = call.initValue
                    elseif call.type == 2 then
                        print("Hook " .. i .. stringify(call))
                    end
                end
                local starting_def = getInitTypeDefinition(instruction)

                print("-- Instruction " .. i .. "-" .. i1 .. ": " .. stringify(instruction) .. " " .. stringify(instruction.returnValue))
                imgui.spacing()
                imgui.begin_rect()
                local typeOptions = {"Method", "Field", "ArrayIndex"}
                local operationOptions = {"Get", "Set"}

                -- Draw the type combo box
                local instruction_index = instruction.type == "ArrayIndex" and 3 or instruction.type == "Field" and 2 or 1
                changed, instruction_index = imgui.combo("Type " .. i .. "-" .. i1, instruction_index, typeOptions)
                instruction.type = typeOptions[instruction_index]

                -- Draw the operation combo box
                local operation_index = instruction.operation == "Set" and 2 or 1
                changed, operation_index = imgui.combo("Operation " .. i .. "-" .. i1, operation_index, operationOptions)
                instruction.operation = operationOptions[operation_index]

                -- Handle Method type instructions
                if instruction.type == "Method" then
                    if not starting_def or instruction.manualMethods then
                        changed, instruction.getValue = imgui.input_text("Method Name " .. i .. "-" .. i1, instruction.getValue)
                    else
                        local methods = starting_def:get_methods()
                        local method_index = 1
                        local method_names = {""}
                        for i2, method in ipairs(methods) do
                            table.insert(method_names, method:get_name() .. "  |  " .. method:get_return_type():get_full_name())
                            if method:get_name() == instruction.getValue then
                                method_index = i2+1
                            end
                        end
                        changed, method_index = imgui.combo("Method Name " .. i .. "-" .. i1, method_index, method_names)
                        if changed then
                            instruction.getValue = methods[method_index-1]:get_name()
                        
                            if methods[method_index-1]:get_num_params() > 0 then
                                changed, instruction.args = imgui.input_text("Args " .. i .. "-" .. i1, instruction.args)
                            end
                        end
                    end
                    imgui.same_line()
                    changed, instruction.manualMethods = imgui.checkbox("Manual Methods " .. i .. "-" .. i1, instruction.manualMethods)
                -- Handle Field type instructions
                elseif instruction.type == "Field" then
                    if not starting_def or instruction.manualFields then
                        changed, instruction.getValue = imgui.input_text("Field Name " .. i .. "-" .. i1, instruction.getValue)
                    else
                        local fields = starting_def:get_fields()
                        local field_index = 1
                        local field_names = {""}
                        for i2, field in ipairs(fields) do
                            table.insert(field_names, field:get_name() .. "  |  " .. field:get_type():get_full_name())
                            if field:get_name() == instruction.getValue then
                                field_index = i2+1
                            end
                        end
                        changed, field_index = imgui.combo("Field Name " .. i .. "-" .. i1, field_index, field_names)
                        if changed then
                            instruction.getValue = fields[field_index-1]:get_name()
                        end
                    end
                    imgui.same_line()
                    changed, instruction.manualFields = imgui.checkbox("Manual Fields " .. i .. "-" .. i1, instruction.manualFields)

                -- Handle ArrayIndex type instructions
                elseif instruction.type == "ArrayIndex" then
                    if not starting_def or instruction.manualArray then
                        changed, instruction.getValue = imgui.input_text("Array Index " .. i .. "-" .. i1, instruction.getValue)
                    else
                        local array = instruction.initValue
                        local arraySize = #array
                        local numberArray = {}
                        for i3 = 1, arraySize do
                            table.insert(numberArray, i3)
                        end
                        -- Array Index not working
                        local array_index = 1
                        changed, array_index = imgui.combo("Array Index " .. i .. "-" .. i1, array_index, numberArray)
                        instruction.getValue = array_index
                    end
                    imgui.same_line()
                    changed, instruction.manualArray = imgui.checkbox("Manual Array " .. i .. "-" .. i1, instruction.manualArray)
                end


                -- Draw the set value input
                if  instruction.operation == "Set" then
                    changed, instruction.setValue = imgui.input_text("Set Value " .. i .. "-" .. i1, instruction.setValue)
                    imgui.same_line()
                    changed, instruction.startSetting = imgui.checkbox("Activate" .. i .. "-" .. i1, instruction.startSetting)
                end

                -- Draw the status and value
                if instruction.returnValue ~= nil and instruction.operation ~= "Set" then
                    imgui.begin_disabled()
                    imgui.input_text("Returned Value " .. i .. "-" .. i1, stringify( instruction.returnValue), 16384)
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
                            call.instructions[i1+1].initValue = instruction.initValue
                        else
                            call.instructions[i1+1].initValue = instruction.returnValue
                        end
                    end
                end
            end
            local disable_add_instruction_button, disable_remove_instruction_button = false, false
            if call.instructions and #call.instructions > 0 then
                local last_instruction = call.instructions[#call.instructions]
                local return_def =  getReturnTypeDefinition(last_instruction) 
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