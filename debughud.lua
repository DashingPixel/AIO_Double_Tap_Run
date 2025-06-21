
local hud_ids = {}
local aio = {}
aio.debug = true 
local function table_to_string(tbl, indent)
    indent = indent or ""
    local str = ""
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            str = str .. indent .. tostring(k) .. ":\n" .. table_to_string(v, indent .. "  ")
        else
            str = str .. indent .. tostring(k) .. ": " .. tostring(v) .. "\n"
        end
    end
    return str
end

core.register_globalstep(function()
    if not aio or not aio.debug then
        -- Remove HUDs if debug is off
        for _, player in ipairs(core.get_connected_players()) do
            local name = player:get_player_name()
            if hud_ids[name] then
                player:hud_remove(hud_ids[name])
                hud_ids[name] = nil
            end
        end
        return
    end
    for _, player in ipairs(core.get_connected_players()) do
        local name = player:get_player_name()
        local p_data = aio_double_tap_run.player_data and aio_double_tap_run.player_data
        if p_data then
            local text = table_to_string(p_data)
            if not hud_ids[name] then
                hud_ids[name] = player:hud_add({
                    hud_elem_type = "text",
                    position = {x=0.8, y=0.4},
                    offset = {x=0, y=0},
                    text = text,
                    alignment = {x=0, y=0},
                    scale = {x=100, y=100},
                    number = 0xFFFFFF,
                })
            else
                player:hud_change(hud_ids[name], "text", text)
            end
        elseif hud_ids[name] then
            player:hud_remove(hud_ids[name])
            hud_ids[name] = nil
        end
    end
end)

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if hud_ids[name] then
        hud_ids[name] = nil
    end
end)