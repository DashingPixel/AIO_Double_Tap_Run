local aio = aio_double_tap_run

local settings = {
    hunger_threshold = tonumber(core.settings:get("aio_double_tap_run.hunger_threshold")) or 6,
    enable_starve = core.settings:get_bool("aio_double_tap_run.starve_check", true),
    enable_drain = core.settings:get_bool("aio_double_tap_run.enable_hunger_drain", true),
    drain_rate = tonumber(core.settings:get("aio_double_tap_run.hunger_drain_rate")) or 0.5,
}

-- Register callback for double-tap detection
aio.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)
    if settings.enable_starve then
        local info = hunger_ng.get_hunger_information(p_name)
        if info.hunger.exact <= settings.hunger_threshold then
            p_data.cancel_sprint = true
        end
    end
    if settings.enable_drain then
        if p_data.states.drain and not p_data.cancel_sprint then
            hunger_ng.alter_hunger(p_name, -(settings.drain_rate * dtime), 'Sprinting')
        end
    end
    return p_data
end)