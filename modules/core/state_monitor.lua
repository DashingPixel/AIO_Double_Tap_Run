local aio = aio_double_tap_run

local settings = {
    cancel_in_liquid = core.settings:get_bool("aio_double_tap_run.liquid", true),
    cancel_in_air = core.settings:get_bool("aio_double_tap_run.air", false),
    cancel_wall = core.settings:get_bool("aio_double_tap_run.wall", true),
    cancel_climbable = core.settings:get_bool("aio_double_tap_run.climbable", true),
    cancel_backwards = core.settings:get_bool("aio_double_tap_run.backwards", true),
    cancel_sneak = core.settings:get_bool("aio_double_tap_run.sneak", false),
    cancel_snow = core.settings:get_bool("aio_double_tap_run.snow", true),
    cancel_low_health = core.settings:get_bool("aio_double_tap_run.low_health", true),
    health_threshold = tonumber(core.settings:get("aio_double_tap_run.health_threshold")) or 6,
}


aio.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)
    if aio.wall_bump(player, p_data.states.climbable) then
        if settings.cancel_wall then
            p_data.cancel_sprint = true
        end
        p_data.states.wall = true
    else
        p_data.states.wall = false
    end
    local check_time = 1.3
    if settings.cancel_in_air then
        check_time = 0
    end
    if aio.in_air(p_name, p_pos, check_time) then
        if settings.cancel_in_air and not p_data.states.climbable then
            p_data.cancel_sprint = true
        end
        p_data.states.air = true
    else
        p_data.states.air = false
    end

    if aio.in_liquid(p_pos) then
        if settings.cancel_in_liquid and not aio.submerged(player) then
            p_data.cancel_sprint = true
        end
        p_data.states.liquid = true
    else
        p_data.states.liquid = false
    end

    if aio.low_health(player, settings.health_threshold) then
        if settings.cancel_low_health then
            p_data.cancel_sprint = true
        end
        p_data.states.low_health = true
    else
        p_data.states.low_health = false
    end

    if aio.on_climbable(p_pos) then
        if settings.cancel_climbable then
            p_data.cancel_sprint = true
        end
        p_data.states.climbable = true
    else
        p_data.states.climbable = false
    end

    if aio.on_snow(p_pos) then
        if settings.cancel_snow then
            p_data.cancel_sprint = true
        end
        p_data.states.snow = true
    else
        p_data.states.snow = false
    end

    if p_control.sneak then
        if settings.cancel_sneak then
            p_data.cancel_sprint = true
        end
        p_data.states.sneaking = true
    else
        p_data.states.sneaking = false
    end

    if p_control.down then
        if settings.cancel_backwards then
            p_data.cancel_sprint = true
        end
        p_data.states.backwards = true
    else
        p_data.states.backwards = false
    end
    if p_data.states.sprinting and p_data.states.climbable and p_data.states.air and p_control.jump and not p_data.cancel_sprint then
        p_data.states.drain = true
    elseif p_data.states.sprinting and p_data.states.liquid and not p_data.cancel_sprint then
        p_data.states.drain = true
    elseif p_data.states.sprinting and not p_data.states.air and not p_data.states.wall and not p_data.cancel_sprint then
        p_data.states.drain = true
    else
        p_data.states.drain = false
    end

    return p_data
end)