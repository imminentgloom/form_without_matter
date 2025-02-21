-- init
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local g_ui = {}
local state = _G.state

-- functions
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function g_ui:buffer(buff, val, z)

    -- add each held button to a buffer
   if z == 1 then
      table.insert(buff, val)
   
   -- release in order
   else
      for i, v in pairs(buff) do

         -- if array
         if type(v) ~= "table" then
            if v == val then
               table.remove(buff, i)
               break
            end
         
         -- or if track/step-table
         else      
            if v.track == val.track and v.step == val.step then
               table.remove(buff, i)
               break
            end
         end
      end
   end
end

-- buttons
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function g_ui:key(x, y, z)

   -- track held buttons
   self:buffer(state.key_buff, {track = y, step = x}, z)

   -- steps
   if y <= 4 then

      -- track held buttons to set loop-points
      self:buffer(state.loop_buff, {track = y, step = x}, z)

      if z == 1 then
         if not state.loop then
            state.edit_track = y
            state.edit_step = x
            state.edit_substep = 1
         end

         -- clear steps
         if state.clear then
            t[y]:clear_step(x)
            state.message = "clear step"

         -- add or remeve steps
         elseif not state.loop and not state.select then
            if t[y].step_status[x] == 1 then
               t[y]:clear_step(x)
               state.message = "- step"
            else
               t[y]:write(1, t[y]:get_index(x))
               state.message = "+ step"
            end

         -- loop track
         elseif #state.loop_key_buff == 2 and #state.loop_buff > 1 then
            t[state.loop_buff[1].track]:loop(state.loop_buff[1].step, state.loop_buff[#state.loop_buff].step)

         -- loop all tracks
         elseif #state.loop_key_buff == 3 and #state.loop_buff > 1 then
            for track = 1, 4 do
               t[track]:loop(state.loop_buff[1].step, state.loop_buff[#state.loop_buff].step)
            end
         end
      end
   end
   
   -- substeps
   if x >= 5 and y >= 5 and x <= 12 and y <= 7 then
      if z == 1 then

         -- convert x,y to 1-24
         local substep = (x - 4) + ((y - 5) * 8)
         local index = t[state.edit_track]:get_index(state.edit_step, substep)

         state.edit_substep = substep

         if not state.select then
            if not state.clear and t[state.edit_track].gate[index] == 1 then
               t[state.edit_track]:write(0, index)
               state.message = "- substep"
            elseif not state.clear and t[state.edit_track].gate[index] == 0 then
               t[state.edit_track]:write(1, index)
               state.message = "+ substep"
            else
               t[state.edit_track]:write(0, index)
               state.message = "clear substep"
            end
         end
      end
   end
   
   -- rec
   if x <= 4 and y == 5 then
      if z == 1 then
         if state.rec[x] then
            state.rec[x] = false
            state.message = "rec " .. x .. " off"
         else
            state.rec[x] = true
            state.message = "rec " .. x .. " on"
         end
      end
   end
   
   -- mute
   if x <= 4 and y == 6 then
      if z == 1 then
         if state.mute[x] then
            state.mute[x] = false
            state.message = "mute " .. x .. " off"
         else
            state.mute[x] = true
            state.message = "mute " .. x .. " on"
         end
      end
   end
   
   -- trigger
   if x <= 4 and y >= 7 then
      if z == 1 then

         -- track trigger state across both buttons
         state.trig_buff[x] = state.trig_buff[x] + 1
         if state.trig_buff[x] > 0 then state.trigger[x] = true end

         state.message = "trig " .. x
         state.edit_track = x
         state.edit_step = t[x].step
         state.edit_substep = t[x].substep
         t[x].fill_index = t[x].substep

         -- trigger hit and write
         if not state.clear and state.rec[x] then
            t[x]:write(1, t[x].index)
            t[x]:hit()
            
            -- crow?

         -- trigger hit, but don't  write
         elseif not state.mute[x] and not state.clear and not state.rec[x] then
            t[x]:hit()
            
            -- crow?
            
         -- clear substep
         elseif state.clear then
            t[x]:write(0)
            state.message = "clear " .. x
         end

      else
         state.trig_buff[x] = state.trig_buff[x] - 1
         if state.trig_buff[x] == 0 then state.trigger[x] = false end
         t[x].fill_index = 1
      end
   end
   
   -- loop
   if x >= 6 and x <= 8 and y == 8 then
      self:buffer(state.loop_key_buff, x, z)
      if z == 1 then
         state.loop = true   
      elseif #state.loop_key_buff == 0 then
         state.loop = false
      end
      if #state.loop_key_buff == 1 then state.message = "loop step" end
      if #state.loop_key_buff == 2 then state.message = "loop track" end
      if #state.loop_key_buff == 3 then state.message = "loop all" end
   end
   
   -- shift
   if x >= 9 and x <= 11 and y == 8 then
      self:buffer(state.shift_buff, x, z)
      if z == 1 then
         state.shift = true   
      elseif #state.shift_buff == 0 then
         state.shift = false
      end
      if state.note_mode then
         local t = t[state.edit_track]
         if #state.shift_buff == 1 then
            state.number = t.velocity[t:get_index(state.edit_step, state.edit_substep)] + t.default_velocity
            state.message = "velocity"
         elseif #state.shift_buff == 2 then
            state.number = t.duration[t:get_index(state.edit_step, state.edit_substep)] + t.default_duration
            state.message = "duration"
         end
      else
         state.message = "shift"
      end
   end
   
   -- pattern
   if x >= 13 and y == 5 then
      local n = x - 12
      if z == 1 then
         state.pattern[n] = true
         if state.select then
            state.pattern_bank = n
            pattern_check()
            state.message = "pat. bank " .. state.pattern_bank
         else
            state.pattern_slot = n
            if state.shift then
               pattern_save(n)
               state.message = "pat. " .. state.pattern_bank .. ":" .. n .. " save"
            elseif state.clear then 
               pattern_clear(n)
               state.message = "pat. " .. state.pattern_bank .. ":" .. n .. " clear"
            else
               -- clear track as if loading an empty pattern
               if state.pattern_status[n] == "empty" then
                  if params:get("pattern_blank") == 2 then
                     state.message = "no pattern"
                     for track = 1, 4 do t[track]:clear_track() end
                  else
                     state.message = "no pattern"
                  end
               else
                  pattern_load(n)
                  state.message = "pat. " .. state.pattern_bank .. ":" .. n .. " load"
               end
            end
         end
      else
         state.pattern[n] = false         
      end
   end
   
   -- play
   if x == 13 and y == 6 then
      if z == 1 then
         state.play = true
         if not state.shift then
            if state.main_clock_running then
               clock.cancel(clk_main)
               state.main_clock_running = false
               state.message = "stop"
            else
               clk_main = clock.run(main_clock_event)
               state.main_clock_running = true
               state.message = "play"
            end
         elseif state.shift then
            for track = 1, 4 do
               if t[track].forward then
                  t[track].forward = false
                  state.message = "reverse"
               else
                  t[track].forward = true
                  state.message = "forward"
               end
            end
         end
      else
         state.play = false
      end
   end
   
   -- reset
   if x == 14 and y == 6 then
      if z == 1 then
         state.reset = true
         for track = 1, 4 do
            t[track]:reset()
         end
         state.message = "reset"
      else
         state.reset = false
      end
   end
   
   -- select
   if x == 15 and y == 6 then
      if z == 1 then
         state.select = true
         state.message = "select"
      else
         state.select = false
      end
   end
   
   -- clear
   if x == 16 and y == 6 then
      if z == 1 then
         state.clear = true
         state.message = "clear"
      else
         state.clear = false
      end
   end
   
   -- clear all
   if state.clear then
      for track = 1, 4 do
         if #state.shift_buff == 1 then
            t[track]:clear_track()
            state.message = "clear all"
         elseif #state.shift_buff == 2 then
            t[track]:clear_track()
            state.rec[track] = true
            state.mute[track] = false
            state.message = "clear all!"
         elseif #state.shift_buff == 3 then
            t[track]:clear_track()
            state.rec[track] = true
            state.mute[track] = false
            t[track]:loop()
            t[track]:reset(1)
            state.message = "clear all!!"
         end
      end
   end
      
   -- clear loops
   if state.loop and state.clear then
      for track = 1, 4 do
         t[track]:loop()
         t[track]:reset(1)
      end
      state.message = "clear loops"
   end

   -- fill
   if x >= 13 and y >= 7 then

      -- count number of buttons held in fill area
      local val = ((y - 7) * 4) + x - 13 
      self:buffer(state.fill_buff, val, z)
      if z == 1 then
         state.fill = true
      elseif #state.fill_buff == 0 then
         state.fill = false
      end
      state.message = "fill " .. util.clamp(#state.fill_buff, 1, 6)
   end

   if #state.key_buff == 0 then reset_name(0.15) end
   g_ui:draw_step()
end

-- grid palette
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local sequence        =  2
local sequence_active = 10
local sequence_tracer =  2
local substep		    =  2
local substep_active	 = 10
local selected        =  3
local record			 =  2
local mute				 =  2
local trigger			 =  2
local trigger_active	 = 12
local trigger_held	 = 10
local loop		       =  4
local shift		       =  4
local pattern_empty	 =  0
local pattern_full	 =  8
local pattern_slot    = 12
local pattern_bank    = 11
local play			    = 11
local stop            =  0
local reset			    =  9
local select          =  7
local clear				 =  5
local fill			    =  3
local mod             =  2

-- leds
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function g_ui:draw_step()
   g:all(0)
   
   -- looping steps
   for y = 1, 4 do
      for x = t[y].loop_start, t[y].loop_end do
         g:led(x, y, sequence + y)
      end
   end

   -- active steps
   for y = 1, 4 do
      for x = 1, 16 do
         if t[y].step_status[x] == 1 then
            g:led(x, y, sequence_active)
         end
      end
   end

   -- substeps
   for y = 5, 7 do
      for x = 5, 12 do
         local pos = (x - 4) + ((y - 5) * 8)
         local t = t[state.edit_track]
         local index = t:get_index(state.edit_step, pos)
         if state.edit_substep == pos then
            g:led(x, y, substep + state.anim_val)
         else
            g:led(x, y, substep)
         end
         if state.edit_substep == pos then
            if t.gate[index] == 1 then
               g:led(x, y, substep_active * state.anim_val)
            end
         else
            if t.gate[index] == 1 then
               g:led(x, y, substep_active)
            end
         end
      end
   end

   -- rec
   for x = 1, 4 do
      g:led(x, 5, state.rec[x] and record + x * 2 or 0)
   end
   
   -- mute
   for x = 1, 4 do
      g:led(x, 6, state.mute[x] and mute + x * 2 or 0)
   end
   
   -- triggers
   for x = 1, 4 do
      g:led(x, 7, state.trigger[x] and trigger_held or trigger + x)
      g:led(x, 8, state.trigger[x] and trigger_held or trigger + x)      
   end

   -- loop
   for x = 6, 8 do
      g:led(x, 8, state.loop and loop + #state.loop_key_buff * mod or loop)
   end

   -- shift
   for x = 9, 11 do
      g:led(x, 8, state.shift and shift + #state.shift_buff * mod or shift)
   end

   -- pattern
   for x = 13, 16 do
      local n = x - 12
      if state.pattern_status[n] == "full" then
         if state.pattern_slot == n then
            g:led(x, 5, pattern_slot)
         else
            g:led(x, 5, pattern_full)
         end
      else 
         g:led(x, 5, pattern_empty)
      end
   end

   -- play
   if state.play then
      g:led(13, 6, play + mod)
   else
      if state.main_clock_running then
         g:led(13, 6, play)
      else
         g:led(13, 6, stop)
      end
   end
   
   -- reset
   g:led(14, 6, state.reset and reset + mod or reset)
      
   -- select
   g:led(15, 6, state.select and select + mod or select)
   if state.select then
      for bank = 1, 4 do
         if state.pattern_bank == bank then
            g:led(12 + state.pattern_bank, 5, pattern_bank - bank)
         else
            g:led(12 + bank, 5, 0)
         end
      end
      
   end
      
   -- clear
   g:led(16, 6, state.clear and clear - mod or clear)

   -- fill
   for y = 7, 8 do
      for x = 13, 16 do
         if state.fill then
            g:led(x, y, util.clamp(fill + #state.fill_buff * 2, 0, 15))
         else
            g:led(x, y, fill)
         end
      end
   end

    -- edit step
    if t[state.edit_track].step_status[state.edit_step] == 1 then
      g:led(state.edit_step, state.edit_track, (sequence_active + state.edit_track) * state.anim_val)
   else
      g:led(state.edit_step, state.edit_track, (sequence + state.edit_track) * state.anim_val)
   end

   -- tracer
   for y = 1, 4 do
      if t[y].step_status[t[y].step] == 1 then
         g:led(t[y].step, y, sequence_active + sequence_tracer)
      else
         g:led(t[y].step, y, sequence + 6)
      end
   end

   g:refresh()
end

function g_ui:draw_substep()

   -- blink trigger buttons
   for x = 1, 4 do
      for y = 7, 8 do
         if t[x].gate[t[x].index] == 1 and not state.mute[x] then
            g:led(x, y, trigger_active)
         else
            if state.trigger[x] then
               g:led(x, y, trigger_active)
            else
               g:led(x, y, trigger + x)
            end
         end
      end
   end

   g:refresh()
end

return g_ui
