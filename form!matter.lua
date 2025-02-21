-- 
-- 
--
-- form without matter
-- v2.0.1 imminent gloom
-- 
--
-- ↓
-- 
-- configure voices
-- in params
--
-- full instructions at:
-- github.com/imminentgloom/
-- form_without_matter

g = grid.connect()

state = {
   main_clock_running = true,
   
   anim_time = 1,
   anim_max = 2,
   anim_val = 0,
   anim_frame = 0,
   
   key_buff = {},
   loop_buff = {},
   loop_key_buff = {},
   shift_buff = {},
   fill_buff = {},
   trig_buff = {0,0,0,0,},
   
   rec = {true, true, true, true},
   mute = {false, false, false, false},
   trigger = {false, false, false, false},
   triggered = {false, false, false, false},
   loop = false,
   loop_step = 0,
   shift = false,
   pattern = {false, false, false, false},
   play = false,
   reset = false,
   select = false,
   clear = false,
   fill = false,

   edit_track = 1,
   edit_step = 1,
   edit_substep = 1,

   note_mode = false,
   note_pos = 1,

   pattern_bank = 1,
   pattern_slot = nil,
   pattern_status = {},
}

musicutil = require("musicutil")
tab       = require("tabutil")
nb        = include("lib/nb/lib/nb")
Track     = include("lib/Track")
prms      = include("lib/parameters")
g_ui      = include("lib/grid_ui")
n_ui      = include("lib/norns_ui")

-- clocks
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function main_clock_event()
   while true do
      clock.sync(1/96)

      -- set up counter for looping held steps
      if t[1].substep == 1 and t[1].forward or t[1].substep == 24 and not t[1].forward then
         if #state.loop_key_buff == 1 then 
            state.loop_step = state.loop_step + 1
            if state.loop_step > #state.loop_buff then state.loop_step = 1 end
         end
      end
      
      for track = 4, 1, -1 do
         local t = t[track]

         -- hit drum!
         if t.gate[t.index] == 1 and not state.mute[track] then t:hit() end

         -- main count!
         if t.forward then t:inc() else t:dec() end

         -- loop single step or steps in order held
         if t.substep == 1 and t.forward or t.substep == 24 and not t.forward then
            if #state.loop_key_buff == 1 then
               if #state.loop_buff == 1 then t:reset(state.loop_buff[1].step) end
               if #state.loop_buff > 1 then t:reset(state.loop_buff[util.clamp(state.loop_step, 1, #state.loop_buff)].step) end
            end
         end

         -- add or play fills
         if state.fill and state.trigger[track] then
            local fill_rate = {1, 2, 4, 8, 12, 24}
            local rate = math.floor(24 / fill_rate[util.clamp(#state.fill_buff, 1, #fill_rate)])
            
            -- add hit every n substep based on fill rate
            if ((t.substep - 1) % rate) + 1 == ((t.fill_index - 1) % rate) + 1 then
               if state.rec[track] then t:write(1) end
               if not state.rec[track] and not state.mute[track] then t:hit() end
            end

            -- substep window shows this
            state.edit_track = t.track
            state.edit_step = t.step
            state.edit_substep = t.substep
         end

         -- clear step
         if state.clear and state.trigger[track] then t:write(0) end
      end
      
      -- crow?

      if t[1].substep == 1 then g_ui:draw_step() end
      g_ui:draw_substep()
   end
end

function mode_select_clock_event()
   clock.sleep(0.3)
   state.note_mode = not state.note_mode
end

function anim_clock_event()
   while true do
      local frame_max = state.anim_time * 15
      state.anim_frame = state.anim_frame + 1
      state.anim_frame = ((state.anim_frame - 1) % frame_max) + 1
      state.anim_val = math.floor((state.anim_frame - 1) / frame_max * state.anim_max)
      clock.sleep(1/15)
      g_ui:draw_step()
   end
end

function intro_clock_event()
   state.label = ""
   state.number = "form"
   state.message = "witout matter"
   reset_name(1)
end

function reset_name_clock_event(seconds)
   clock.sleep(seconds)
   if not state.note_mode then
      state.label = "bpm"
      state.number = params:get("clock_tempo")
      state.message = "form!matter"
   elseif state.note_mode then
      state.label = ""
      if #Track.active_steps == 0 then
         state.number = ""
         state.message = "no step"
      else
         local t = t[state.edit_track]
         local index = t:get_index(state.edit_step, state.edit_substep)
         state.number = musicutil.note_num_to_name(t.note[index] + t.root_note, true)
         state.message = "form!matter"
      end
   end
end

-- functions
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function reset_name(seconds)
   if clk_reset ~= nil then clock.cancel(clk_reset) end
   clk_reset = clock.run(reset_name_clock_event, seconds)
end

-- pattern
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function pattern_check()
   for pattern = 1, 4 do
      local p = tab.load(norns.state.data .. "pattern_slot_" .. pattern .. "_bank_" .. state.pattern_bank)
      if p == nil or #p == 0 then
         state.pattern_status[pattern] = "empty"
      else
         state.pattern_status[pattern] = "full"
      end
   end
end

function pattern_save(num)
   local p = {}
   for track = 1, 4 do table.insert(p, t[track]) end
   table.insert(p, Track.active_steps)  -- p[5]
   table.insert(p, Track.ordered_steps) -- p[6]
   table.insert(p, state.rec)           -- p[7]
   table.insert(p, state.mute)          -- p[8]
   local loop_state = {}
   for track = 1, 4 do
      table.insert(loop_state, {t[track].loop_start, t[track].loop_end})
   end
   table.insert(p, loop_state)          -- p[9]
   tab.save(p, norns.state.data .. "pattern_slot_" .. num .. "_bank_" .. state.pattern_bank)
   state.pattern_status[num] = "full"
end

function pattern_load(num)
   local p = tab.load(norns.state.data .. "pattern_slot_" .. num .. "_bank_" .. state.pattern_bank)
   if #p > 0 then
      Track.active_steps = p[5]
      Track.ordered_steps = p[6]
      if params:get("pattern_rec") == 2 and p[7] ~= nil then  -- skip if old pattern (#p[7/8/9] = 0)
         state.rec = p[7]
      end
      if params:get("pattern_mute") == 2 and p[8] ~= nil then
         state.mute = p[8]
      end
      if params:get("pattern_loop") == 2 and p[9] ~= nil then
         for track = 1, 4 do
            t[track].loop_start = p[9][track][1]
            t[track].loop_end = p[9][track][2]
         end
      else
         for track = 1, 4 do
            t[track].loop_start = 1
            t[track].loop_end = 16
         end
      end
      for track = 1, 4 do
         for index = 1, 384 do
            t[track].gate[index] = p[track].gate[index]
            t[track].note[index] = p[track].note[index]
            t[track].velocity[index] = p[track].velocity[index]
            t[track].duration[index] = p[track].duration[index]
         end
         for index = 1, 16 do
            t[track].step_status[index] = p[track].step_status[index]
         end
      end
      state.pattern_status[num] = "full"
      state.pattern_slot = num
      if params:get("pattern_reset") == 2 then
         for track = 1, 4 do
            t[track]:reset()
         end
      end
   end
end

function pattern_clear(num)
   local p = {}
   tab.save(p, norns.state.data .. "pattern_slot_" .. num .. "_bank_" .. state.pattern_bank)
   state.pattern_status[num] = "empty"
end

-- init
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function init()
   nb:init()
   nb.voice_count = 4
   
   t = {}
   for n = 1, 4 do t[n] = Track:new() end
   
   prms:init()

   clk_main = clock.run(main_clock_event)
   clk_anim = clock.run(anim_clock_event)
   clk_intro = clock.run(intro_clock_event)
   
   params:read(norns.state.data .. "state.pset")
   
   if params:get("pattern_load") == 2 then
      state.pattern_bank = params:get("pattern_bank")
      pattern_load(params:get("pattern_slot"))
   end

   pattern_check()
end

-- behavior
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function g.key(x, y, z) g_ui:key(x, y, z) end
   
function key(n, z) n_ui:key(n, z) end

function enc(n, d) n_ui:enc(n, d) end

function refresh() n_ui:draw_screen() end

-- shutdown
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function cleanup()
   nb:stop_all()
   params:write(norns.state.data .. "state.pset")
end
