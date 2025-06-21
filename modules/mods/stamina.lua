local aio = aio_double_tap_run

aio.get_mod_author = function(modname)
    local modpath = core.get_modpath(modname)
    if not modpath then
        return nil, "Mod not found"
    end

    local mod_conf = Settings(modpath .. "/mod.conf")
    if not mod_conf then
        return nil, "mod.conf not found"
    end

    local author = mod_conf:get("author")
    if author then
        return author
    else
        return nil, "Author field not found in mod.conf"
    end
end

local mod_settings = {
    author = aio.get_mod_author("stamina"),
}

if mod_settings.author == "TenPlus1" then
    mod_settings.enable_drain = core.settings:get_bool("aio_double_tap_run.stamina_enable_drain", true)
    mod_settings.sprint_exhaust = tonumber(core.settings:get("aio_double_tap_run.stamina_drain_rate")) or 35
    mod_settings.threshold = tonumber(core.settings:get("aio_double_tap_run.stamina_threshold")) or 6 
    stamina.enable_sprint = false
    stamina.enable_sprint_particles = false
elseif mod_settings.author == "sofar" then
   mod_settings.enable_drain = core.settings:get_bool("stamina.enabled", true)
   mod_settings.sprint_exhaust = tonumber(core.settings:get("stamina.exhaust_sprint")) or 28
   mod_settings.sprint_exhaust = mod_settings.sprint_exhaust * 2
   mod_settings.threshold = tonumber(core.settings:get("stamina.starve_lvl")) or 3
   stamina.settings.sprint = false
   stamina.settings.sprint_particles = false
   stamina.settings.sprint_with_fast = false
end

aio.register_dtr(function(player, p_name, p_pos, p_control, p_data, current_time, dtime)
   local current_saturation = stamina.get_saturation(player) or 0 
   if (current_saturation <= mod_settings.threshold) then
       p_data.cancel_sprint = true
       p_data.states.starving = true
   else
       p_data.states.starving = false
   end

   if p_data.states.drain and mod_settings.enable_drain then
        stamina.exhaust_player(player, (mod_settings.sprint_exhaust) * dtime)
   end
   return p_data
end)
