local aio = aio_double_tap_run

local settings = {
    enable_starve = core.settings:get_bool("aio_double_tap_run.hb_starve_check", true),
    enable_drain = core.settings:get_bool("aio_double_tap_run.hb_enable_drain", true),
    threshold = tonumber(core.settings:get("aio_double_tap_run.hb_threshold")) or 6,
    drain_rate = tonumber(core.settings:get("aio_double_tap_run.hb_drain_rate")) or 15.0,
}

settings.drain_rate = settings.drain_rate * 10

aio.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)
    local current_hunger = hbhunger.hunger[p_name] or hbhunger.SAT_INIT

    if settings.enable_starve then
        if current_hunger < settings.threshold then
            p_data.cancel_sprint = true
        end
    end

    if settings.enable_drain then
        if p_data.states.drain and not p_data.cancel_sprint then
            hbhunger.exhaustion[p_name] = (hbhunger.exhaustion[p_name] or 0) + dtime * settings.drain_rate
            if hbhunger.exhaustion[p_name] >= hbhunger.EXHAUST_LVL then
                hbhunger.exhaustion[p_name] = 0
                if current_hunger > 0 then
                    current_hunger = current_hunger - 1
                    hbhunger.hunger[p_name] = current_hunger
                    hbhunger.set_hunger_raw(player)
                end
            end
        end
    end

    return p_data
end)