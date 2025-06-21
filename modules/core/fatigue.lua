local storage = core.get_mod_storage()
local S = core.get_translator("aio_double_tap_run") 
local settings = {
    drain_rate = tonumber(core.settings:get("aio_double_tap_run.fatigue_drain_rate")) or 0.5,
    restore_rate = tonumber(core.settings:get("aio_double_tap_run.fatigue_restore_rate")) or 0.5,
    restore_time = tonumber(core.settings:get("aio_double_tap_run.fatigue_restore_time")) or 2,
    restore_threshold = tonumber(core.settings:get("aio_double_tap_run.health_threshold")) or 6,
}

local aio = {
    hudbars_wuzzy = core.get_modpath("hudbars") and core.global_exists("hudbars") ~= nil,
    hud_ids = {},
    get_stored_fatigue = function(player_name)
        return tonumber(storage:get_string(player_name .. ":fatigue")) or 20
    end,
    restore_fatigue_timers = {},
    fatigue_icon = "server_favorite.png",
}

if not aio.hudbars_wuzzy then
    aio.get_hud_id = function(player)
        return aio.hud_ids[player:get_player_name()]
    end
    aio.set_hud_id = function(player, hud_id)
        aio.hud_ids[player:get_player_name()] = hud_id
    end

    aio.init_fatigue = function(player)
        local max_value = 20
        local player_name = player:get_player_name()
        local saved = aio.get_stored_fatigue(player_name)
        local value = saved or max_value
        local id = player:hud_add({
            name = "aio_fatigue",
            type = "statbar",
            position = {x = 0.5, y = 1},
            size = {x = 24, y = 24},
            text = aio.fatigue_icon,  
            number = value,
            text2 = "blank.png",
            item = max_value,
            alignment = {x = -1, y = -1},
            offset = {x = -266, y = -114},   
            max = 0,
        })
        aio.set_hud_id(player, id)

        local meta = player:get_meta()
        meta:set_float("aio_fatigue:value", value)
        meta:set_float("aio_fatigue:max", max_value)
    end

    aio.drain_fatigue = function(player, amount)
        local meta = player:get_meta()
        local value = meta:get_float("aio_fatigue:value") or 0
        local max_value = meta:get_float("aio_fatigue:max") or 20
    
        value = math.max(0, value - amount)
        meta:set_float("aio_fatigue:value", value)
        player:hud_change(aio.get_hud_id(player), "number", value)
    end
    
    -- Helper: Restore the bar for a player
    aio.restore_fatigue = function(player, amount)
        local meta = player:get_meta()
        local value = meta:get_float("aio_fatigue:value") or 0
        local max_value = meta:get_float("aio_fatigue:max") or 20
        value = math.min(max_value, value + amount)
        meta:set_float("aio_fatigue:value", value)
        player:hud_change(aio.get_hud_id(player), "number", value)
    end

    core.register_on_joinplayer(aio.init_fatigue)

    core.register_on_leaveplayer(function(player)
        local meta = player:get_meta()
        local value = meta:get_float("aio_fatigue:value") or 20
        storage:set_string(player:get_player_name() .. ":fatigue", tostring(value))
    end)
    
    aio_double_tap_run.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)
        local meta = player:get_meta()
        local current_value = meta:get_float("aio_fatigue:value") or 0
        local max_value = meta:get_float("aio_fatigue:max") or 20

        -- Get player's health
        local health = player:get_hp() or 20

        if current_value <= 0 then
            p_data.cancel_sprint = true
        end
        if p_data.states.sprinting and not p_data.cancel_sprint then
            aio.restore_fatigue_timers[p_name] = nil 
        else
            aio.restore_fatigue_timers[p_name] = (aio.restore_fatigue_timers[p_name] or 0) + dtime
            if aio.restore_fatigue_timers[p_name] >= settings.restore_time then
                -- Only restore if health is above threshold
                if current_value < max_value and health > settings.restore_threshold then
                    aio.restore_fatigue(player, settings.restore_rate * dtime)
                end
            end
        end
        if p_data.states.drain and not p_data.cancel_sprint then
            if current_value > 0 then
                aio.drain_fatigue(player, settings.drain_rate * dtime)
            end
        end
    end)
else
    aio.bar_id = "fatigue"
    aio.bar_bg = "[fill:2x16:0,0:#056608"
    hb.register_hudbar(
        aio.bar_id,
        0xFFFFFF, 
        S("Fatigue"), -- Label
        { icon = aio.fatigue_icon, bgicon = nil, bar = aio.bar_bg },
        20, -- default_start_value
        20, -- default_start_max
        false -- default_start_hidden
    )
    -- Initialize the HUD bar for each player and restore fatigue from storage
    core.register_on_joinplayer(function(player)
        local player_name = player:get_player_name()
        local stored = aio.get_stored_fatigue(player_name)
        local value = stored or 20
        hb.init_hudbar(player, aio.bar_id, value, 20, false)
    end)
    
    aio.get_fatigue = function(player)
        local player_name = player:get_player_name()
        local value = aio.get_stored_fatigue(player_name)
        local state = hb.get_hudbar_state(player, aio.bar_id)
        local max = state and state.max or 20
        if value == nil then
            value = state and state.value or 20
        end
        return value, max
    end
    aio.set_fatigue_bar_color = function(player, hex_color)
        local bar_texture = "[fill:2x16:0,0:" .. hex_color
        hb.change_hudbar(player, aio.bar_id, nil, nil, nil, nil, bar_texture)
    end
    aio.set_fatigue = function(player, value, max)
        local player_name = player:get_player_name()
        hb.change_hudbar(player, aio.bar_id, value, max)
        storage:set_string(player_name .. ":fatigue", tostring(value))
    end

    aio_double_tap_run.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)

        local current_value, max_value = aio.get_fatigue(player)
        if max_value == 0 then max_value = 20 end

        -- Get player's health
        local health = player:get_hp() or 20

        if current_value <= 0 then
            p_data.cancel_sprint = true
            aio.set_fatigue(player, 0, max_value)
        end
        if p_data.states.sprinting and not p_data.cancel_sprint then
            
            aio.restore_fatigue_timers[p_name] = nil 
        else
            aio.restore_fatigue_timers[p_name] = (aio.restore_fatigue_timers[p_name] or 0) + dtime
            if aio.restore_fatigue_timers[p_name] >= settings.restore_time then
                -- Only restore if health is above threshold
                if current_value < max_value and health > settings.restore_threshold then
                    aio.set_fatigue_bar_color(player, "#008080")
                    aio.set_fatigue(player, math.min(max_value, current_value + settings.restore_rate * dtime), max_value)                
                end
                if current_value == max_value then
                    aio.set_fatigue_bar_color(player, "#056608")
                end
            end
        end
        if p_data.states.drain and not p_data.cancel_sprint then
            if current_value > 0 then
                aio.set_fatigue_bar_color(player, "#800020")
                aio.set_fatigue(player, math.max(0, current_value - settings.drain_rate * dtime), max_value)
            end
        end
    end)
end
