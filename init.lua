local aio = {
    mod_name = core.get_current_modname(),
    tap_interval = tonumber(core.settings:get("aio_double_tap_run.tap_interval")) or 0.5,
    extra_speed = tonumber(core.settings:get("aio_double_tap_run.extra_speed")) or 0.8,
    jump_boost = tonumber(core.settings:get("aio_double_tap_run.jump_boost")) or 0.1,
    enable_dt = core.settings:get_bool("aio_double_tap_run.enable_dt", true),
    enable_aux = core.settings:get_bool("aio_double_tap_run.enable_aux", false),
    enable_particles = core.settings:get_bool("aio_double_tap_run.particles", true),
    ground_particles = core.settings:get_bool("aio_double_tap_run.ground_particles", true),
    player_data = {},
    callback_data = {},
    sprint_timers = {},
    particle_timers = {},
    air_timers = {},
    default_fov = 72,
    change_fov = core.settings:get_bool("aio_double_tap_run.enable_fov", true),
    fov_boost = tonumber(core.settings:get("aio_double_tap_run.fov_boost")) or 20,
    fov_ttime = tonumber(core.settings:get("aio_double_tap_run.fov_ttime")) or 0.2,
    reverse_fov = core.settings:get_bool("aio_double_tap_run.reverse_fov", false),
}

aio.get_darkened_texture_from_node = function(pos, darkness)
    local node = core.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
    if not node then return "[fill:2x16:0,0:#8B4513" end
    local def = core.registered_nodes[node.name]
    if not def or not def.tiles or not def.tiles[1] then return "[fill:2x16:0,0:#8B4513" end
    local base_texture = def.tiles[1]
    return base_texture or "[fill:2x16:0,0:#8B4513".. "^[colorize:#000000:" .. tostring(darkness or 80)
end

-- Example usage in your particles function:
aio.ground_particles = function(player)
    local pos = player:get_pos()
    local texture = aio.get_darkened_texture_from_node(pos, 110)
    core.add_particlespawner({
        amount = 5,
        time = 0.01,
        minpos = {x = pos.x - 0.25, y = pos.y + 0.1, z = pos.z - 0.25},
        maxpos = {x = pos.x + 0.25, y = pos.y + 0.1, z = pos.z + 0.25},
        minvel = {x = -0.5, y = 1, z = -0.5},
        maxvel = {x = 0.5, y = 2, z = 0.5},
        minacc = {x = 0, y = -5, z = 0},
        maxacc = {x = 0, y = -12, z = 0},
        minexptime = 0.25,
        maxexptime = 0.5,
        minsize = 0.5,
        maxsize = 1.0,
        vertical = false,
        collisiondetection = false,
        texture = texture
    })
end

local function create_player_data()
    return {
        detected  = false,
        last_tap_time = 0,
        is_holding    = false,
        aux_pressed   = false,
        cancel_sprint = false,
        original_fov = minetest.settings:get("fov") or aio.default_fov,
        current_fov = 0,
        states = {
            sprinting = false,
            wall = false,
            liquid = false,
            low_health = false,
            air = false,
            climbable = false,
            snow = false,
            sneaking = false,
            backwards = false,
        }
    }
end
-------------------------------------------------------------------------------------------------------------------
-- function callback
local function invoke_callbacks(player, p_name, p_pos, p_control, p_data, current_time, dtime)
    if p_data then
        for _, callback in ipairs(aio.callback_data) do
            callback(player, p_name, p_pos, p_control, p_data, current_time, dtime)
        end
    end
end
-------------------------------------------------------------------------------------------------------------------
-- Checks if the player is real
aio.is_player = function(player)
    if player and type(player) == "userdata" and core.is_player(player) then
        return true
    end 
end
-------------------------------------------------------------------------------------------------------------------
--  PHYSIC
if core.get_modpath("player_monoids") ~= nil and core.global_exists("player_monoids") then
    aio.use_physics = "MONOID"
elseif core.get_modpath("pova") ~= nil and core.global_exists("pova") then
    aio.use_physics = "POVA"
else
    aio.use_physics = "PHYSICS"
end

aio.sprint = function(player, enable_sprint, extra_speed)
    local p_name = player:get_player_name()
    if enable_sprint then
        if aio.use_physics == "MONOID" then
            player_monoids.speed:add_change(player, (1 + extra_speed), aio.mod_name .. ":sprinting")
            player_monoids.jump:add_change(player, (1 + aio.jump_boost), aio.mod_name .. ":jumping")
        elseif aio.use_physics == "POVA" then
            local override_name = aio.mod_name .. ":sprinting"
            local override_table = { speed = extra_speed, jump = aio.jump_boost, gravity = nil }
            pova.add_override(p_name, override_name, override_table)
        elseif aio.use_physics == "PHYSICS" then
            player:set_physics_override({ speed = (1 + extra_speed), jump = (1 + aio.jump_boost)})
        end
        if aio.sprint_timers[p_name] then
            aio.sprint_timers[p_name] = nil
        end
        aio.sprint_timers[p_name] = core.after(0.3, function()
            if player and aio.is_player(player) then
                if aio.use_physics == "MONOID" then
                    player_monoids.speed:del_change(player, aio.mod_name .. ":sprinting")
                    player_monoids.jump:del_change(player, aio.mod_name .. ":jumping")
                elseif aio.use_physics == "POVA" then
                elseif aio.use_physics == "PHYSICS" then
                    player:set_physics_override({ speed = 1 , jump = 1})
                end
            end
            aio.sprint_timers[p_name] = nil
        end)
    else
        if aio.use_physics == "MONOID" then
            player_monoids.speed:del_change(player, aio.mod_name .. ":sprinting")
            player_monoids.jump:del_change(player, aio.mod_name .. ":jumping")
        elseif aio.use_physics == "POVA" then
            local override_name = aio.mod_name .. ":sprinting"
            pova.del_override(p_name, override_name)
        elseif aio.use_physics == "PHYSICS" then
            player:set_physics_override({ speed = 1 , jump = 1})
        end
        aio.sprint_timers[p_name] = nil
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Sprint Particles
aio.get_texture = function()
    if core.get_modpath("xcompat") and core.global_exists("xcompat") then
        if core.get_game_info().id == "minetest" or core.get_game_info().id == "farlands_reloaded" then
            return xcompat.textures.grass.dirt
        end
    else
        if core.get_game_info().id == "minetest" then
            return "default_dirt.png"
        end
    end
    return "smoke_puff.png"
end

aio.particles = function(player)
    local pos = player:get_pos()
    local node = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
    local def = core.registered_nodes[node.name] or {}
    local drawtype = def.drawtype
    if drawtype ~= "airlike" and drawtype ~= "liquid" and drawtype ~= "flowingliquid" then
        core.add_particlespawner({
            amount = 5,
            time = 0.01,
            minpos = {x = pos.x - 0.25, y = pos.y + 0.1, z = pos.z - 0.25},
            maxpos = {x = pos.x + 0.25, y = pos.y + 0.1, z = pos.z + 0.25},
            minvel = {x = -0.5, y = 1, z = -0.5},
            maxvel = {x = 0.5, y = 2, z = 0.5},
            minacc = {x = 0, y = -5, z = 0},
            maxacc = {x = 0, y = -12, z = 0},
            minexptime = 0.25,
            maxexptime = 0.5,
            minsize = 0.5,
            maxsize = 1.0,
            vertical = false,
            collisiondetection = false,
            texture = aio.get_texture()
        })
    end
end
local function is_hanggliding(player)
    local item = player:get_wielded_item()
    return item and item:get_name() == "hangglider:hangglider"
end
-------------------------------------------------------------------------------------------------------------------
-- Globalstep - The heart of the program
core.register_globalstep(function(dtime)
    local players = core.get_connected_players()
    local current_time = core.get_us_time() / 1000000  
    for _, player in ipairs(players) do
        if player and aio.is_player(player) then
            local p_name = player:get_player_name()
            local p_pos = player:get_pos()
            local p_control = player:get_player_control()
            local p_control_bit = player:get_player_control_bits()
            
            if not aio.player_data[p_name] then
                aio.player_data[p_name] = create_player_data()
            end

            if aio.enable_particles then
                if not aio.particle_timers[p_name] then
                    aio.particle_timers[p_name] = 0
                end
                aio.particle_timers[p_name] = aio.particle_timers[p_name] + dtime
            end

            local p_data = aio.player_data[p_name]

            invoke_callbacks(player, p_name, p_pos, p_control, p_data, current_time, dtime)

            if p_data.cancel_sprint then
                p_data.detected = false
                p_data.is_holding = false
                p_data.cancel_sprint = false
                p_data.states.sprinting = false
            else
                -- Only allow aux sprint if enabled
                if aio.enable_aux and p_control_bit == 33 then
                    p_data.detected = true
                    p_data.is_holding = false
                    p_data.aux_pressed = true
                    p_data.states.sprinting = true
                elseif p_control_bit == 1 then
                    if aio.enable_dt then
                        if not p_data.is_holding then
                            if current_time - p_data.last_tap_time < aio.tap_interval then
                                p_data.detected = true
                                p_data.states.sprinting = true
                            end
                            p_data.last_tap_time = current_time
                            p_data.is_holding = true
                        end
                        -- If AUX was pressed earlier but now released, adjust the key
                        if p_data.aux_pressed then
                            p_data.aux_pressed = false
                        end
                    else
                        -- If FORWARD functionality is disabled, reset to no dt detection
                        p_data.states.sprinting = false
                        p_data.detected = false
                        p_data.is_holding = false
                    end
                
                elseif p_control_bit == 0 or p_control_bit == 32 then
                    p_data.detected = false
                    p_data.is_holding = false
                    p_data.aux_pressed = false
                    p_data.states.sprinting = false
                end
            end

            -- Cancel particles and FOV if hangglider is wielded and player is in air
            local cancel_effects = false

            local pos_below = vector.round({x = p_pos.x, y = p_pos.y - 0.5, z = p_pos.z})
            local node_below = core.get_node_or_nil(pos_below)
            local is_air_below = node_below and node_below.name == "air"

            if is_hanggliding(player) and is_air_below then
                cancel_effects = true
            end

            if p_data.detected then
                aio.sprint(player, true, aio.extra_speed)
                p_data.states.sprinting = true
                if aio.enable_particles and not cancel_effects then
                    if aio.particle_timers[p_name] >= 0.2 then
                        if aio.ground_particles then
                            aio.ground_particles(player)
                        else
                            aio.particles(player)
                        end
                        aio.particle_timers[p_name] = 0 
                    end
                end
            else
                if aio.use_physics == "POVA" then
                    aio.sprint(player, false)
                end
                p_data.states.sprinting = false
            end
            if aio.change_fov and not cancel_effects then
                local target_fov = 0
                if aio.reverse_fov then
                    target_fov = p_data.states.sprinting and (p_data.original_fov + aio.fov_boost) or 0
                else
                    target_fov = p_data.states.sprinting and (p_data.original_fov - aio.fov_boost) or 0
                end
                    
                if target_fov ~= p_data.current_fov then
                    player:set_fov(target_fov, false, aio.fov_ttime)
                    p_data.current_fov = target_fov
                end
            elseif cancel_effects and p_data.current_fov ~= 0 then
                -- Reset FOV if it was set
                player:set_fov(0, false, aio.fov_ttime)
                p_data.current_fov = 0
            end
        end
    end
end)
-------------------------------------------------------------------------------------------------------------------
-- API
aio_double_tap_run = {
    mod_name = aio.mod_name,
    disable_aux = function()
        aio.enable_aux = false
    end,
    set_speed = function(speed)
        aio.extra_speed = speed
    end,
    set_particles = function(value)
        aio.enable_particles = value
    end,
    set_jump = function(value)
        aio.jump_boost = value
    end,
}

aio_double_tap_run.register_dtr = function(callback)
    table.insert(aio.callback_data, callback)
end

aio_double_tap_run.in_liquid = function(pos)
    local check_positions = {
        { x = pos.x, y = pos.y - 0.2, z = pos.z }, -- Feet position
        { x = pos.x, y = pos.y + 0.85, z = pos.z } -- Head position
    }
    for _, p in ipairs(check_positions) do
        local node = core.get_node_or_nil(p)
        if node then
            local nodedef = core.registered_nodes[node.name]
            if nodedef and nodedef.liquidtype and nodedef.liquidtype ~= "none" then
                return true
            end
        end
    end
    return false
end
aio_double_tap_run.player_data = aio.player_data
aio_double_tap_run.wall_bump = function(player, climbable_state)
    -- Get the player's base position.
    local base_pos = player:get_pos()
    local properties = player:get_properties()
    local eye_height = (properties and properties.eye_height) or 0.5 -- Fallback in case eye_height is not set

    -- Define two positions:
    -- Lower position uses a fixed offset of 0.5.
    local lower_pos = {
        x = base_pos.x,
        y = base_pos.y + 0.5,
        z = base_pos.z
    }
    -- Upper position uses the player's eye height.
    local upper_pos = {
        x = base_pos.x,
        y = base_pos.y + eye_height,
        z = base_pos.z
    }

    -- Calculate horizontal direction (ignoring any vertical tilt).
    local angle = player:get_look_horizontal()
    local direction = vector.rotate_around_axis(
        {x = 0, y = 0, z = 1},
        {x = 0, y = 0, z = 0},
        angle
    )
    direction = vector.normalize(direction)

    -- Calculate target positions (one node ahead) for both lower and upper checks.
    local target_lower = vector.round(vector.add(lower_pos, direction))
    local target_upper = vector.round(vector.add(upper_pos, direction))

    -- Get the nodes at the target positions.
    local node_lower = minetest.get_node(target_lower)
    local node_upper = minetest.get_node(target_upper)

    -- Retrieve registered node definitions (these contain properties such as walkability).
    local reg_node_lower = minetest.registered_nodes[node_lower.name]
    local reg_node_upper = minetest.registered_nodes[node_upper.name]

    -- Check conditions for each node:
    -- The node must be walkable, must not be "default:snow", and the climbable state must be false.
    local lower_is_wall = reg_node_lower and reg_node_lower.walkable and node_lower.name ~= "default:snow"
    local upper_is_wall = reg_node_upper and reg_node_upper.walkable and node_upper.name ~= "default:snow"

    if not climbable_state and (lower_is_wall or upper_is_wall) then
        return true
    else
        return false
    end
end

aio_double_tap_run.low_health = function(player, threshold)
    local current_health = player:get_hp()
    return current_health and current_health < threshold
end

aio_double_tap_run.on_climbable = function(pos)
    pos.y = pos.y - 0.5
    local node = core.get_node_or_nil(pos)
    local nodedef = node and core.registered_nodes[node.name]
    return nodedef and nodedef.climbable or false
end

-- Check if player is in the air for a specific duration
aio_double_tap_run.in_air = function(player_name, pos, duration)
    local check_pos = { x = pos.x, y = pos.y - 0.5, z = pos.z }
    local node = core.get_node_or_nil(check_pos)
    local in_air = not (node and core.registered_nodes[node.name] and core.registered_nodes[node.name].walkable)

    local current_time = core.get_us_time() / 1000000
    if in_air then
        local last_time = aio.air_timers[player_name] and aio.air_timers[player_name].last_time or current_time
        local elapsed = current_time - last_time
        local total = (aio.air_timers[player_name] and aio.air_timers[player_name].total or 0) + elapsed
        aio.air_timers[player_name] = { last_time = current_time, total = total }
    else
        aio.air_timers[player_name] = nil
    end
    return aio.air_timers[player_name] and aio.air_timers[player_name].total >= duration
end

aio_double_tap_run.on_snow = function(pos)
    -- Slightly above the player's position to catch slabs/thin nodes
    local check_pos = { x = pos.x, y = pos.y + 0.5, z = pos.z }
    local node = core.get_node_or_nil(check_pos)
    if node then
        local def = core.registered_nodes[node.name]
        if def and def.groups and def.groups.snowy and def.groups.snowy > 0 then
            return true
        end
    end
    return false
end
-- Check if player is submerged in water
aio_double_tap_run.submerged = function(player)
    local pos = player:get_pos()
    local props = player:get_properties()
    local cb = props.collisionbox
    local minp = vector.floor(vector.add(pos, { x = cb[1], y = cb[2], z = cb[3] }))
    local maxp = vector.ceil(vector.add(pos, { x = cb[4], y = cb[5], z = cb[6] }))

    for x = minp.x, maxp.x do
        for y = minp.y, maxp.y do
            for z = minp.z, maxp.z do
                local npos = { x = x, y = y, z = z }
                local node = core.get_node_or_nil(npos)
                local nodedef = node and core.registered_nodes[node.name]
                if not nodedef or not nodedef.liquidtype or nodedef.liquidtype == "none" then
                    return false
                end
            end
        end
    end
    return true
end



-------------------------------------------------------------------------------------------------------------------
-- Prevent sleepwalking when using beds
if core.get_modpath("beds") and core.global_exists("beds") ~= nil then
    local bed_nodes = {
        "beds:bed",
        "beds:fancy_bed",
    }

    for _, bed_node in ipairs(bed_nodes) do
        local original_on_right_click = core.registered_nodes[bed_node].on_rightclick
        local updated_bed_definition = {
            on_rightclick = function(pos, node, player, itemstack, pointed_thing)
                local control = player:get_player_control()
                if not control.aux1 then
                    if original_on_right_click then
                        original_on_right_click(pos, node, player, itemstack, pointed_thing)
                    end
                else
                    core.chat_send_player(player:get_player_name(), "Stop sprinting to use the bed!")
                end
            end
        }
        core.override_item(bed_node, updated_bed_definition)
    end
end
-------------------------------------------------------------------------------------------------------------------
---Clear data when player leaves
core.register_on_leaveplayer(function(player)
    local p_name = player:get_player_name()
    if aio.player_data[p_name] then
        player:set_fov(0, false)
    end
    aio.player_data[p_name] = nil
    aio.callback_data[p_name] = nil
    aio.sprint_timers[p_name] = nil
    aio.particle_timers[p_name] = nil
    aio.air_timers[p_name] = nil
end)

--------------------------------------------------------------------------------------------------------------------
--Modules

--Core
dofile(core.get_modpath(aio.mod_name) .. "/modules/core/state_monitor.lua")

aio.show_fatigue = core.settings:get_bool("aio_double_tap_run.fatigue", true)
aio.stamina = core.get_modpath("stamina") and core.global_exists("stamina") ~= nil
aio.hunger_ng = core.get_modpath("hunger_ng") and core.global_exists("hunger_ng") ~= nil
aio.hbhunger = core.get_modpath("hbhunger") and core.global_exists("hbhunger") ~= nil
aio.character_anim =  core.get_modpath("character_anim") ~= nil

if aio.character_anim then
    dofile(core.get_modpath(aio.mod_name) .. "/modules/mods/character_anim.lua")
end
if aio.hbhunger then
    dofile(core.get_modpath(aio.mod_name) .. "/modules/mods/hbhunger.lua")
elseif aio.hunger_ng then
    dofile(core.get_modpath(aio.mod_name) .. "/modules/mods/hunger_ng.lua")
elseif aio.stamina then
    dofile(core.get_modpath(aio.mod_name) .. "/modules/mods/stamina.lua")
elseif aio.show_fatigue and not core.settings:get_bool("creative_mode", false) then
    dofile(core.get_modpath(aio.mod_name) .. "/modules/core/fatigue.lua")
end
 --dofile(core.get_modpath(aio.mod_name) .. "/debughud.lua")
