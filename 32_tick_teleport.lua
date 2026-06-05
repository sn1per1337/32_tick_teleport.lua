local entity = require 'gamesense/entity'
local vector = require "vector"
local antiaim_funcs = require 'gamesense/antiaim_funcs'
local dt_enable, dt_hotkey = ui.reference("RAGE", "Aimbot", "Double tap")
local fakeduck = ui.reference("RAGE", "Other", "Duck peek assist")
local teleport_enable = ui.new_checkbox("AA", "Other", "Extended teleport")
local teleport_hotkey = ui.new_hotkey("AA", "Other", "Extended teleport", true)
local teleport_min = ui.new_checkbox("AA", "Other", "Dynamic fakelag teleport")
local slam_dunk = ui.new_checkbox("AA", "Other", "Slam dunk")
local slam_dunk_hotkey = ui.new_hotkey("AA", "Other", "Slam dunk", true)
local screen = {client.screen_size()}
local center = {screen[1] / 2, screen[2] / 2}
local data = {
    prev_sim_time = 0,
    defensive_active_until = 0,
    defensive_shift = 0,
    last_registered_shot_time = 0,
    last_shot_time = 0
}
local shot = {
    last_shot_time = 0,
    last_registered_shot_time = 0,
    last_shot_time = 0,
    sent_since_shot = false
}
local state = {
    ttep = 0,
    step = 0,
    triggered_at = 0,
    fd = nil
}

local function reset_data(data)
    if data == true then
        data = {
            prev_sim_time = 0,
            defensive_active_until = 0,
            defensive_shift = 0
        }
    elseif data == false then
        state = {
            ttep = 0,
            step = 0,
            triggered_at = 0
        }
    end
end

local function extrapolate_player_position(player, origin, ticks)
    local vel = {entity.get_prop(player, "m_vecVelocity")}

    if vel[1] == nil then
        return nil
    end

    local pred_tick = globals.tickinterval() * ticks

    return {
        origin[1] + (vel[1] * pred_tick),
        origin[2] + (vel[2] * pred_tick),
        origin[3] + (vel[3] * pred_tick)
    }
end

local function time_to_ticks(t)
    return math.floor(0.5 + (t / globals.tickinterval()))
end

local function detect_local_defensive_activation ()
    local player = entity.get_local_player()
    local sim_time = time_to_ticks(player:get_prop("m_flSimulationTime"))
    local prev_sim_time = data.prev_sim_time
    local tickcount = globals.tickcount()

    if data.prev_sim_time == 0 then
        data.prev_sim_time = sim_time
        return
    end

    local sim_delta = sim_time - prev_sim_time

    if sim_delta < 0 then
        local shift = math.abs(sim_delta)
        data.defensive_active_until = globals.tickcount() + shift
        data.defensive_shift = shift
    end

    data.prev_sim_time = sim_time
end

local function teleport(c)
    local slam_dunk_active = ui.get(slam_dunk) and ui.get(slam_dunk_hotkey) and ui.get(dt_enable)
    local states = state.ttep
    local tickcount = globals.tickcount()
    local lp = entity.get_local_player()
    local fall_g = ui.get(slam_dunk_hotkey)

    local air = bit.band(entity.get_prop(lp, "m_fFlags") or 0, 1) == 0

    if slam_dunk_active and air and state.ttep == 0 and antiaim_funcs.get_double_tap() then
        c.force_defensive = true
        state.ttep = 1

    elseif state.ttep == 1 then
        --print("test")
        if data.defensive_active_until == tickcount then

            c.force_defensive = true
        elseif data.defensive_active_until + data.defensive_shift -1 == tickcount then
            local origin = {entity.get_origin(lp)}
            if origin[1] ~= nil then
                local pred_origin = extrapolate_player_position(lp, origin, 22)
                if pred_origin[1] ~= nil then
                    local trace = {client.trace_line(1, origin[1], origin[2], origin[3], pred_origin[1], pred_origin[2], pred_origin[3])}
                    if (trace[1] ~= 1 and fall_g == true) then
                        ui.set(dt_enable, false)
                        state.triggered_at = tickcount
                        states = 2
                    end
                end
            end
        end
    elseif state.ttep == 2 then
        local delta = (tickcount - state.triggered_at) 
        if delta >= 12 + data.defensive_shift and not ui.get(dt_enable) and c.force_defensive == false then
            ui.set(dt_enable, true)
            state.ttep = 0
            reset_data(true)
            reset_data(false)
        end
    end
    detect_local_defensive_activation()
end

local function on_setup_command(c)
    local active = ui.get(dt_enable) and ui.get(dt_hotkey) and ui.get(teleport_hotkey)
    local step = state.step
    local tickcount = globals.tickcount()
    local player = entity.get_local_player()
    local speed = vector(player:get_prop("m_vecVelocity")):length2d()
    

    
    if active and step == 0 and antiaim_funcs.get_double_tap() and speed > 0.7 then
        c.force_defensive = true
        state.step = 1

    elseif step == 1 then
        if data.defensive_active_until == tickcount then
            c.force_defensive = true
        elseif data.defensive_active_until + data.defensive_shift -1 == tickcount and shot.sent_since_shot == true  then
            ui.set(dt_enable, false)
            state.triggered_at = tickcount
            state.step = 2
        end
    elseif step == 2 then
        local delta = (tickcount - state.triggered_at) 

        if delta >= 12 + data.defensive_shift and not ui.get(dt_enable) and c.force_defensive == false then
            ui.set(dt_enable, true)
            state.step = 0
            reset_data(true)
            reset_data(false)
        end

    end
    detect_local_defensive_activation()
    if c.chokedcommands == 0 then
        shot.sent_since_shot = true
    end
    state.fd = c.force_defensive
    --client.delay_call(totime(1), function()
    --    if (data.defensive_active_until + data.defensive_shift >= tickcount) == false then
    --        print("false")
    --    end
    --    if (data.defensive_active_until + data.defensive_shift >= tickcount) == true then
    --        print(tostring(data.defensive_active_until + data.defensive_shift).."  | defnsive shift 12  "..tostring(data.defensive_active_until + data.defensive_shift >= tickcount).."    |  FD  "..tostring(state.fd).."    |   tick"..tostring(globals.realtime()))
    --    end
    --end)
end


local function map_color()
    local tickcount = globals.tickcount()

    local defensive_active = data.defensive_active_until + data.defensive_shift - 1>= tickcount

    if state.step >= 1 and defensive_active then
        return { 132, 196, 20, 255, defensive_percent }
    end

    return { 255, 255, 255, 255}
end

local function on_paint ()
    local active = ui.get(teleport_enable) and ui.get(teleport_hotkey)
    local active_min = ui.get(teleport_enable) and ui.get(teleport_hotkey) and ui.get(teleport_min)
    local color = map_color()

    local getstate = ui.get(teleport_enable) and ui.get(teleport_hotkey) and not ui.get(fakeduck)

    if getstate then
        local tickcount = globals.tickcount()
        local defensive_active = data.defensive_active_until + data.defensive_shift >= tickcount
        local delta = (tickcount - state.triggered_at) 

        if defensive_active and state.step >= 1 then
            local perc = math.floor(delta % 100 )
            if perc == 0 and antiaim_funcs.get_double_tap() == false then
                perc = 1
            end
            renderer.text(center[1], center[2] - 50, 255, 255, 255, 255, "cd", 0, "IDEAL TICK")
            renderer.text(center[1], center[2] - 40, 255, 255, 255, 255, "cd", 0, "CHARGED APPROX (" .. perc.. "%)")
        end

        --end
        --local perc = math.floor(self.c_cmd / 14 * 100 + 0.5)
        --if state.fd == true then
        --    renderer.text(center[1], center[2] - 50, 255, 255, 255, 255, "cd-", 0, "IDEAL TICK")
        --    renderer.text(center[1], center[2] - 40, 255, 255, 255, 255, "cd-", 0, "CHARGED APPROX (100%)")
        --else
        --    renderer.text(center[1], center[2] - 50, 255, 255, 255, 255, "cd-", 0, "IDEAL TICK")
        --    renderer.text(center[1], center[2] - 40, 255, 255, 255, 255, "cd-", 0, string.format("CHARGED APPROX (%s%)"))
        --end
--
        --local delta = (tickcount - state.triggered_at) 



        --renderer.text(center[1], center[2] - 50, 255, 255, 255, 255, "cd-", 0, "IDEAL TICK")
        --renderer.text(center[1], center[2] - 40, 255, 255, 255, 255, "cd-", 0, "CHARGED APPROX (" .. perc.. "%)")
    end

    if active then
        
        renderer.indicator(color[1], color[2], color[3], color[4], "+/- IDEAL TICK")
    end

    ui.set(ui.reference("AA", "Fake lag", "Limit"), active_min and 1 or 15)
end

local function weapon_fire(e)
    local lp = entity.get_local_player()
    local userid = client.userid_to_entindex(e.userid)

    if userid ~= lp then
        return
    end

    local tickcount = globals.tickcount()

    if shot.last_shot_time < tickcount and shot.sent_since_shot == true then --To avoid "double flipping" while double tapping
        shot.last_registered_shot_time = globals.realtime()
        shot.last_shot_time = tickcount + ticktotime(16)
        shot.sent_since_shot = false
    end

    local player = client.userid_to_entindex(e.userid)

    if player ~= nil and lp ~= nil and player == lp then
        shot.sent_since_shot = false
    end
end

ui.set_callback(teleport_enable, function(e)
    local callback = ui.get(e) and client.set_event_callback or client.unset_event_callback
    --callback("weapon_fire", weapon_fire)
    callback("setup_command", on_setup_command)
    callback("paint", on_paint)
end)
