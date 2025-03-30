local HybridCombo = {}


local hybrid_combo_open = {}
local hybrid_combo_search_text = {}
-- Hybrid combo box
function HybridCombo.create(label, index, options)
    imgui.push_id(label)
    if index == nil then
        index = 1
    end
    local id = imgui.get_id(label)

    local changed = false
    local custom_combo_active

    -- Draw text input for search filter
    if hybrid_combo_search_text[label] == nil then
        hybrid_combo_search_text[label] = options[index]
    end
    
    -- If combo box state is open
    if hybrid_combo_open[id] then
        imgui.open_popup(label .. "-custom-combo", 4096)
    end
    
    -- TODO: Fix loses focus when popup appears
    _, hybrid_combo_search_text[label] = imgui.input_text(label, hybrid_combo_search_text[label], 1048576)
    hybrid_combo_open[id] = imgui.is_item_active()
    

    -- Gather text input location
    local text_box_active = imgui.is_item_active()
    local input_text_width = imgui.calc_item_width() + imgui.calc_text_size(label).x + 10
    local cursor_pos = imgui.get_cursor_pos()

    imgui.same_line()
    cursor_pos.y = cursor_pos.y - 25
    cursor_pos.x = cursor_pos.x + imgui.calc_item_width() - 20
    imgui.set_cursor_pos(cursor_pos)

    -- Draw arrow button
    local box_open = imgui.is_popup_open(label .. "-custom-combo")
    local arrow_button_clicked = imgui.arrow_button(label .. "-arrow", box_open and 0 or 3)
    custom_combo_active = custom_combo_active or imgui.is_item_active()


    -- Get text input location
    local pos = imgui.get_cursor_screen_pos()
    imgui.set_next_window_pos(Vector2f.new(pos.x, pos.y), 1, nil)
    local box_height = math.min(200, #options * 30)
    imgui.set_next_window_size(Vector2f.new(input_text_width, box_height), nil)

    imgui.push_style_var(12, 0.0) -- Rounded elements
    imgui.push_style_var(2, Vector2f.new(0, 0)) -- Extra padding
    imgui.push_style_var(29, Vector2f.new(0,0)) -- Left Align button text

    imgui.push_style_color(21, 0x00714A29) -- AABBGGRR (Button Colour)
    imgui.push_style_color(22, 0xFF5c5c5c) -- AABBGGRR (Button Hover Colour)

    if imgui.begin_popup_context_item(label .. "-custom-combo", 4096) then

        for i, option in ipairs(options) do
            if option == "" or string.match(option, hybrid_combo_search_text[label]) then
                local button_pos = imgui.get_cursor_pos()
                if imgui.button(option, Vector2f.new(input_text_width, imgui.calc_text_size(option).y+2)) then
                    index = i
                    changed = true
                    hybrid_combo_search_text[label] = option
                end
            end
        end
        imgui.end_popup()
    end
    imgui.pop_style_color(2)
    imgui.pop_style_var(3)



    imgui.pop_id()

    return changed, index - 1
end

return HybridCombo