
local settings = {
    enable_animations = core.settings:get_bool("aio_double_tap_run.enable_animations", true),
    walk_framespeed = tonumber(core.settings:get("aio_double_tap_run.walk_framespeed")) or 15,
    sprint_framespeed = tonumber(core.settings:get("aio_double_tap_run.sprint_framespeed")) or 30,
    idle_framespeed = 15,   -- Default fallback, not configurable in settingtypes.txt
    punch_framespeed = 30,  -- Default fallback, not configurable in settingtypes.txt
}

aio_double_tap_run.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)
    if not settings.enable_animations then return end

    local current_animation = player:get_animation()
    local animation_range = current_animation and { x = current_animation.x, y = current_animation.y } or { x = 0, y = 79 }
    local velocity = player:get_velocity()
    local speed = (velocity.x^2 + velocity.z^2)^0.5

    if p_data.states.sprinting then
        local sprint_speed = settings.sprint_framespeed + speed * 2
        player:set_animation(animation_range, sprint_speed, 0)
    else
        -- Detect animation type
        if current_animation and current_animation.x == 0 and current_animation.y == 79 then
            -- Idle animation (example range, adjust as needed)
            player:set_animation(animation_range, settings.idle_framespeed, 0)
        elseif current_animation and current_animation.x == 189 and current_animation.y == 198 then
            -- Punch/mine animation (example range, adjust as needed)
            player:set_animation(animation_range, settings.punch_framespeed, 0)
        else
            -- Walking or other animation
            local walk_speed = settings.walk_framespeed + speed * 2
            player:set_animation(animation_range, walk_speed, 0)
        end
    end
end)