-- init
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local musicutil = require("musicutil")
local g_ui      = include(norns.state.shortname .. "/lib/grid_ui")

local n_ui = {}
local state = _G.state

-- functions
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- return random, recording-enabled, track
function n_ui:random_track()
   local rec_enabled = {}
   for track = 1, 4 do
      if state.rec[track]then
         table.insert(rec_enabled, track)
      end
   end
   return rec_enabled[math.random(#rec_enabled)]
end

-- keys and encoders
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function n_ui:key(n, z)

   -- hold to toggle note mode
   if n == 1 then 
      if z == 1 then
         clk_mode = clock.run(mode_select_clock_event)
      else
         if clk_mode ~= nil then
            clock.cancel(clk_mode)
         end
      end
   end   

   -- toggle play/stop
   if n == 2 then
      if z == 1 then
         if state.main_clock_running then
            clock.cancel(clk_main)
            state.main_clock_running = false
            state.message = "stop"
         else
            clk_main = clock.run(main_clock_event)
            state.main_clock_running = true
            state.message = "play"
         end
      end
   end

   -- reset
   if n == 3 then
      if z == 1 then
         for track = 1, 4 do
            t[track]:reset()
            state.message = "reset"
         end
      end
   end
   
   reset_name(0.5)
   g_ui:draw_step()
end

function n_ui:enc(n, d)

   -- bpm
   if n == 1 then
      params:delta("clock_tempo", d)
      state.label = "bpm"
      state.number = params:get("clock_tempo")
   end

   -- play mode
   if not state.note_mode then

      -- randomize
      if state.rec[1] or state.rec[2] or state.rec[3] or state.rec[4] then

         -- steps
         if n == 2 then
            for n = 1, d do
               if d > 0 then
                  for brute_force = 1, 64 do            
                     local track = n_ui:random_track()
                     local step = math.random(16)
                     local index = t[track]:get_index(step)
                     if t[track].step_status[step] == 0 then
                        t[track]:write(1, index)
                     end
                     state.edit_track = track
                     state.edit_step = step
                     state.edit_substep = 1
                     break
                  end   
                  state.message = "+ step"    
               end 
            end
         end

         -- substeps
         if n == 3 then
            for n = 1, d do
               if d > 0 then
                  for brute_force = 1, 4 * 384 do
                     local track = n_ui:random_track()
                     local index = math.random(384)
                     if t[track].gate[index] == 0 then
                        t[track]:write(1, index)
                     end
                     state.edit_track = track
                     state.edit_step = t[track]:get_step(index)
                     state.edit_substep = t[track]:get_substep(index)
                     break
                  end       
                  state.message = "+ substep"
               end 
            end
         end

      -- or not
      else
         state.message = "rec disabled"
      end   

      -- clear steps, newest first
      if n == 2 or n == 3 then
         if d < 0 then
            for n = 1, math.abs(d) do
               if #Track.active_steps > 0 then
                  local active = Track.active_steps[#Track.active_steps]
                  state.edit_track = active.track
                  state.edit_step = t[active.track]:get_step(active.index)
                  state.edit_substep = t[active.track]:get_substep(active.index)
                  t[active.track]:write(0, active.index)
               end
            end
            state.message = "- step"
         end
      end

   -- note mode
   else

      -- edit
      if n == 2 then
         local t = t[state.edit_track]
         local index = t:get_index(state.edit_step, state.edit_substep)

         -- revert edit
         if state.clear then
            t.note[index] = 0
            t.velocity[index] = 0
            t.duration[index] = 0
            state.message = "clear note"
         else

            -- note
            if #state.shift_buff == 0 then
               t.note[index] = util.clamp(t.note[index] + d, 0 - t.root_note, 127 - t.root_note)
               state.label = ""
               state.number = musicutil.note_num_to_name(t.note[index] + t.root_note, true)

            -- velocity   
            elseif #state.shift_buff == 1 then
               d = d * 0.01
               t.velocity[index] = util.clamp(t.velocity[index] + d, 0 - t.default_velocity, 4 - t.default_velocity)
               state.label = ""
               state.number = t.velocity[index] + t.default_velocity

            -- duration
            elseif #state.shift_buff == 2 then
               t.duration[index] = util.clamp(t.duration[index] + d, 0 - t.default_duration, 1000 - t.default_duration)
               state.label = ""
               state.number = t.duration[index] + t.default_duration
            end
         end
      end
      
      -- scroll through active steps by track
      if n == 3 then
         if #Track.ordered_steps > 0 then
            d = util.clamp(d, -1, 1)

            -- count/loop
            state.note_pos = state.note_pos + d
            if state.note_pos > #Track.ordered_steps then state.note_pos = 1 end
            if state.note_pos < 1 then state.note_pos = #Track.ordered_steps end

            -- get status
            state.edit_track = Track.ordered_steps[state.note_pos].track
            state.edit_step = t[state.edit_track]:get_step(Track.ordered_steps[state.note_pos].index)
            state.edit_substep = t[state.edit_track]:get_substep(Track.ordered_steps[state.note_pos].index)

            -- set message
            local t = t[state.edit_track]
            local index = t:get_index(state.edit_step, state.edit_substep)
            state.number = musicutil.note_num_to_name(t.note[index] + t.root_note, true)
            state.message = state.edit_track .. "/" .. state.edit_step .. "/" .. state.edit_substep
         else
            state.message = "no step"
         end

      end
   end

   reset_name(1)
   g_ui:draw_step()
end

-- graphics
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function n_ui:draw_screen()
   screen.clear()
   screen.level(15)
   screen.font_face(1)
   screen.rect(0, 46, 128, 19)
   screen.fill()
   screen.move(0, 40)
   screen.font_size(16)
   screen.text(state.label)
   screen.move(128, 40)
   screen.font_size(48)
   screen.text_right(state.number)   
   if state.message == "form!matter" then 
      screen.level(13)
   else
      screen.level(0)
   end
   screen.font_size(16)
   screen.move(123, 59)
   screen.text_right(state.message)
   if state.note_mode then
      screen.move(3, 59)
      screen.level(0)
      screen.text("♫")
   end
   
   -- debug text
   -- screen.level(15)
   -- screen.font_size(8)
   -- screen.move(0, 8)
   -- screen.text(state.loop_step)
   -- screen.move(8, 8)
   -- screen.text(t[state.edit_track].step)
   -- screen.move(8, 8)
   -- screen.text("/" .. t[state.edit_track].substep)
   -- screen.move(24, 8)
   -- screen.text("/" .. t[state.edit_track].index)

   screen.update()
end

return n_ui