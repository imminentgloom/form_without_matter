-- 
-- 
--
-- form without matter
-- v1.2 imminent gloom
-- 
--
-- 
-- set up n.b. et al. in params
--
-- most buttons show functions
-- on screen when pressed.
--
-- many have combos. let the
-- light guide you (seriously)!
-- 
-- more instructions on github!

-- setup
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local name = "form!matter"

local g = grid.connect()

local tab = require("tabutil")
local musicutil = require("musicutil")
local nb = include("lib/nb/lib/nb")

local save_on_exit = true

t = {} -- hold tracks

local p = { -- holds patterns
   -- 384 long sequence of substeps
   data = {
      {{},{},{},{}},
      {{},{},{},{}},
      {{},{},{},{}},
      {{},{},{},{}},
   },
   -- 384 long sequence of notes
   data_note = {
      {{},{},{},{}},
      {{},{},{},{}},
      {{},{},{},{}},
      {{},{},{},{}},
   },
   -- 16 long sequence of steps
   data_step = {
      {{},{},{},{}},
      {{},{},{},{}},
      {{},{},{},{}},
      {{},{},{},{}},
   },
   active_steps = {{},{},{},{}},
   state = {"empty", "empty", "empty", "empty"},
   current = 1,
}

local edit = {
   track = 1,
   step = 1,
   substep = 1
}

crow_hits = {false, false, false, false}

local active_steps = {}

local trig = {false, false, false, false}
local trig_index = {1, 1, 1, 1}
local mute = {false, false, false, false}
local rec = {true, true, true, true}
local erase = false
local select = false
local shift_1 = false
local shift_2 = false
local retrigger
local speed_limit
local bpm

local seq_play = true
local halt_step
local seq_reset = false

local jump_step = 1

local key_buff = {}
local loop_buff = {}
local fill_buff = {}
local shift_buff_1 = {}
local shift_buff_2 = {}


local fill_rate_presets = {
   fast = {1,2,3,6,12,24},
   slow = {1,2,3,4,5,6},
   prime = {1,3,5,7,9,13},
   user = {1,2,3,6,12,24},
}

local fill_rate = fill_rate_presets.fast

local ppqn = 96

local fps = 32
local frame = 1
local frame_anim = 1
local frames = 8
local frame_rnd_step = 1
local trig_pulled = {false, false, false, false}

local k1_held = false

local crow_trig = true
local crow_trig_length = 0.001 -- 0.0007 seems to work reliably with jf

local big_message
local big_number
local message = name

-- Track class
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

track = {}
track.__index = track
track.substeps = ppqn / 4

local num_tracks = 0

function track.new()
   local sequence = setmetatable({}, track)
   
   num_tracks = num_tracks + 1
   sequence.number = num_tracks
   
   sequence.voice = "nb_voice_" .. num_tracks
   nb:add_param(tostring(sequence.voice), "track " .. num_tracks .. ":" )
   
   sequence.index = 1
   sequence.step = 1
   sequence.substep = 1

   sequence.forward = true

   sequence.loop_start = 1
   sequence.loop_end = 16

   sequence.note = sequence.number2
   sequence.velocity = 1
   sequence.duration = 1

   sequence.last_hit = 0
   sequence.speed_limit = 0

   sequence.data = {}
   sequence.data_note = {}
   for n = 1, 16 * sequence.substeps do
      sequence.data[n] = 0
      sequence.data_note[n] = 0
   end
   
   sequence.data_step = {}
   for n = 1, 16 do
      sequence.data_step[n] = 0
   end

   return sequence
end

-- step through sequence
function track:inc()
   self.index = self.index + 1
   if self.index >= self:step_2_index(self.loop_end) + self.substeps then
      self.index = self:step_2_index(self.loop_start)
   end

   if self.index < self:step_2_index(self.loop_start) then
      self.index = self:step_2_index(self.loop_start)
   end
   
   self.substep = math.floor(((self.index - 1) % self.substeps) + 1)
   
   self.step = self:index_2_step(self.index)

   self:speed_limit_counter()
end

-- step back through sequence
function track:dec()
   self.index = self.index - 1
   if self.index < self:step_2_index(self.loop_start) then
      self.index = self:step_2_index(self.loop_end) + self.substeps - 1
   end
   
   if self.index >= self:step_2_index(self.loop_end) + self.substeps then
      self.index = self:step_2_index(self.loop_end) + self.substeps
   end

   self.substep = math.floor(((self.index - 1) % self.substeps) + 1)

   self.step = self:index_2_step(self.index)

   self:speed_limit_counter()
end

-- speed limit counter
function track:speed_limit_counter()
   self.last_hit = self.last_hit + 1
   if self.last_hit > self.substeps then
      self.last_hit = 0
   end
end

-- writes value to index OR value to current possition OR inverts current index
function track:write(val, index)
   local track = self.number
   index = index or self.index
   val = val or self.data[index] % 2
   
   -- write data
   self.data[index] = val

   -- add 16ths
   if val == 1 then
      self.data_step[self:index_2_step(index)] = 1
   end
   
   -- remove 16ths
   if val == 0 then
      if not self:get_step(self:index_2_step(index)) then 
         self.data_step[self:index_2_step(index)] = 0
      end
   end
   
   -- add active steps
   if val == 1 then
      table.insert(active_steps, {track = track, index = index})
   end
   
   -- remove active steps
   if val == 0 then
      for i , v in ipairs(active_steps) do
         if v.track == track and v.index == index then
            table.remove(active_steps, i)
            break
         end
      end
   end
end

-- resets to step OR start of loop
function track:reset(step)
   if self.forward then 
      step = step or 1
   end

   if not self.forward then
      step = step or 16
   end

   self.step = util.clamp(step, self.loop_start, self.loop_end)
   
   if self.forward then
      self.substep = 1
      self.index = self:step_2_index(self.step)
   end

   if not self.forward then
      self.substep = self.substeps
      self.index = self:step_2_index(self.step) + self.substeps - 1
   end
end

-- sets loop points, args in any order
function track:loop(l1, l2)
   l1 = l1 or 1
   l2 = l2 or 16
   self.loop_start = math.min(l1, l2)
   self.loop_end = math.max(l1, l2)   
end

-- clear entire sequence
function track:clear_sequence()
   for index = 1, 16 * self.substeps do
      self:write(0, index)
      self.data_note[index] = 0
   end
   for n = 1, #active_steps do
      active_steps[n] = nil
   end
end

-- clear step OR clear current step
function track:clear_step(step)
   step = step or self.step

   for step_num = self:step_2_index(step), self:step_2_index(step) + 23 do
      self:write(0, step_num)
   end   
end

-- trigger drum hit
function track:hit()
   -- limit consecutive triggers to preserve stability of other hw
   -- 0 is no limit, 1-24 = once every 1-24 substeps, 16ths @ 24 
   if self.last_hit >= self.speed_limit then

      -- trigger nb-voice
      player = params:lookup_param(self.voice):get_player()
      player:play_note(self.data_note[self.index] + self.note, self.velocity, self.duration)
      
      -- trigger crow
      if crow_trig then
         crow_hits[self.number] = true
      end

      self.last_hit = 0
   end
end

-- converts step# to index
function track:step_2_index(step)
   return math.floor((step - 1) * self.substeps + 1)
end

-- converts index to step#
function track:index_2_step(index)
   return math.floor((index - 1) / 24) + 1
end

-- cheks if step has active substeps OR current step has active
function track:get_step(step)
   step = step or self.step
   local state = nil

   for substep = 1, self.substeps do
      if self.data[(step - 1) * self.substeps + substep] == 1 then
         state = true
         break
      end
   end
   return state or false
end

-- crow: communication (postsolarpunk saves the day!)
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- sends a recieving function to crow so we can send one table to trigger 4 outputs giving us ~4 x speed

-- sends code to crow: iterate through table, trigger pulse if true
local function crow_init()
   for track = 1, 4 do crow.output[track].action = "pulse(" .. crow_trig_length .. ", 10)" end
   crow[[
      function process_trigs(mytable)
         for n = 1, 4 do
            if mytable[n] then
               output[n]()
            end
         end
      end
      ]]
   end
   
   -- triggers process_trigs() on crow and empties crow_hits
   local function crow_send_trigs()
      crow.process_trigs(crow_hits)
      for i = 1, 4 do 
         crow_hits[i] = false
      end
   end
   
-- utility functions
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- empty lines in params menu
local line_count = 1
function newline()
   params:add_trigger(tostring("void_" .. line_count), "")
   params:set_action(tostring("void_" .. line_count), function() print("the void whispers back") end)
   line_count = line_count + 1
end

-- wait and put the script name back on screen
local screen_clk_running = false

local function screen_clk(seconds)
   screen_clk_running = true
   clock.sleep(seconds)
   screen_clk_running = false
   message = name
   big_message = "bpm"
   big_number = bpm
end

local function screen_name(seconds)
   if screen_clk_running then clock.cancel(clk_screen_name) end
   clk_screen_name = clock.run(screen_clk, seconds)
end

-- tracks held keys in order, val can be either single value or table with .track and .step
local function g_buffer(buff, val, z)
   if z == 1 then
      -- add all held fills to a table in order
      table.insert(buff, val)
   else
      -- remove each step as it is released
      for i, v in pairs(buff) do
         if type(v) ~= "table" then
            if v == val then
               table.remove(buff, i)
               break
            end
         else
            if v.track == val.track and v.step == val.step then
               table.remove(buff, i)
               break
            end
         end
      end
   end
end

-- randomize, filter by active rec
local function random_track_if_rec()
   local rec_enabled = {}
   for track = 1, 4 do
      if rec[track]then
         table.insert(rec_enabled, track)
      end
   end
   return rec_enabled[math.random(#rec_enabled)]
end

-- pattern, load
local function pattern_to_sequence(pattern)
   for track = 1, 4 do
      for index = 1, ppqn * 4 do
         t[track].data[index] = p.data[pattern][track][index]
         t[track].data_note[index] = p.data_note[pattern][track][index]
      end

      for step = 1, 16 do
         t[track].data_step[step] = p.data_step[pattern][track][step]
      end
   end

   for n = 1, #active_steps do
      active_steps[n] = nil
   end   

   for n = 1, #p.active_steps[pattern] do
      active_steps[n] = p.active_steps[pattern][n]
   end
   
   p.current = pattern
end

-- pattern, save
local function sequence_to_pattern(pattern)
   for track = 1, 4 do
      for index = 1, ppqn * 4 do
         p.data[pattern][track][index] = t[track].data[index]
         p.data_note[pattern][track][index] = t[track].data_note[index]
      end

      for step = 1, 16 do
         p.data_step[pattern][track][step] = t[track].data_step[step]
      end
   end

   for n = 1, #p.active_steps[pattern] do
      p.active_steps[pattern][n] = nil
   end   

   for n = 1, #active_steps do
      p.active_steps[pattern][n] = active_steps[n]
   end

   p.state[pattern] = "full"
end

-- pattern, clear
local function pattern_clear(pattern)
   for track = 1, 4 do
      for index = 1, ppqn * 4 do
         p.data[pattern][track][index] = 0
         p.data_note[pattern][track][index] = 0
      end

      for step = 1, 16 do
         p.data_step[pattern][track][step] = 0
      end
   end
   
   for n = 1, #p.active_steps[pattern] do
      p.active_steps[pattern][n] = nil
   end   

   p.state[pattern] = "empty"
end

-- init
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function init()
   nb:init()
   nb.voice_count = 4
   
   -- params
   -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

   newline()
   
   params:add_separator("form!matter")

   params:add_number("pattern_bank", "pattern: bank", 1, 16, 1) -- default = 16, but no reason it can't be higher
   params:set_action("pattern_bank", function(x) pattern_bank = x end)
   params:add_trigger("pattern_load", "pattern: load")
   params:set_action(
      "pattern_load",
      function()
         if tab.load(norns.state.data .. "patterns-" .. pattern_bank) ~= nil then
            p = tab.load(norns.state.data .. "patterns-" .. pattern_bank)
            print("load bank ".. pattern_bank)
         else
            print("no patterns to load")
         end
      end
   )
   params:add_trigger("pattern_save", "pattern: save")
   params:set_action("pattern_save", function() tab.save(p, norns.state.data .. "patterns-" .. pattern_bank) end)

   newline()

   params:add_option("crow", "crow triggers", {"off", "on"}, 2)
   params:set_action(
      "crow",
      function(x)
         if x == 2 then
            crow_trig = true
            crow_init()
         else
            crow_trig = false
         end
      end
   )
   
   newline()

   params:add_number("speed_limit", "speed limit", 0, 24, 0)
   params:set_action("speed_limit", function(x) for track = 1, 4 do t[track].speed_limit = x end end)	
   params:add_option("fill_rate", "fill rate", {"fast", "slow", "user"}, 1)
   params:set_action(
      "fill_rate",
      function(x)
         if x == 1 then fill_rate = fill_rate_presets.fast end
         if x == 2 then fill_rate = fill_rate_presets.slow end
         if x == 3 then fill_rate = fill_rate_presets.user end
         if x == 3 then params:show("fill_rate_user") else params:hide("fill_rate_user") end
         _menu.rebuild_params()
      end
   )
   params:add_group("fill_rate_user", "user", 7)
   params:add_separator("", "fill rate pr. button held")
   params:add_number("fill_rate_user_1", "1", 1, 24, 1)
   params:set_action("fill_rate_user_1", function(x) fill_rate_presets.user[1] = x end)
   params:add_number("fill_rate_user_2", "2", 1, 24, 2)
   params:set_action("fill_rate_user_2", function(x) fill_rate_presets.user[2] = x end)
   params:add_number("fill_rate_user_3", "3", 1, 24, 3)
   params:set_action("fill_rate_user_3", function(x) fill_rate_presets.user[3] = x end)
   params:add_number("fill_rate_user_4", "4", 1, 24, 4)
   params:set_action("fill_rate_user_4", function(x) fill_rate_presets.user[4] = x end)
   params:add_number("fill_rate_user_5", "5", 1, 24, 5)
   params:set_action("fill_rate_user_5", function(x) fill_rate_presets.user[5] = x end)
   params:add_number("fill_rate_user_6", "6", 1, 24, 6)
   params:set_action("fill_rate_user_6", function(x) fill_rate_presets.user[6] = x end)
   
   newline()
   
   params:add_separator("n.b. et al.")
   
   params:add_group("notes", "root notes", 4)
   params:add_number("note_1", "track 1, note:", 0, 127, 1)
   params:set_action("note_1", function (x) t[1].note = x end)
   params:add_number("note_2", "track 2, note:", 0, 127, 2)
   params:set_action("note_2", function (x) t[2].note = x end)
   params:add_number("note_3", "track 3, note:", 0, 127, 3)
   params:set_action("note_3", function (x) t[3].note = x end)
   params:add_number("note_4", "track 4, note:", 0, 127, 4)
   params:set_action("note_4", function (x) t[4].note = x end)
   
   params:add_group("velocity", "velocity", 4)
   params:add_control("velocity_1", "track 1, vel:", controlspec.new(0, 4, "lin", 0.01, 1))
   params:set_action("velocity_1", function (x) t[1].velocity = x end)
   params:add_control("velocity_2", "track 2, vel:", controlspec.new(0, 4, "lin", 0.01, 1))
   params:set_action("velocity_2", function (x) t[2].velocity = x end)
   params:add_control("velocity_3", "track 3, vel:", controlspec.new(0, 4, "lin", 0.01, 1))
   params:set_action("velocity_3", function (x) t[3].velocity = x end)
   params:add_control("velocity_4", "track 4, vel:", controlspec.new(0, 4, "lin", 0.01, 1))
   params:set_action("velocity_4", function (x) t[4].velocity = x end)
   
   params:add_group("duration", "duration", 4)
   params:add_number("duration_1", "track 1, dur:", 0, 1000, 1)
   params:set_action("duration_1", function (x) t[1].duration = x end)
   params:add_number("duration_2", "track 2, dur:", 0, 1000, 1)
   params:set_action("duration_2", function (x) t[2].duration = x end)
   params:add_number("duration_3", "track 3, dur:", 0, 1000, 1)
   params:set_action("duration_3", function (x) t[3].duration = x end)
   params:add_number("duration_4", "track 4, dur:", 0, 1000, 1)
   params:set_action("duration_4", function (x) t[4].duration = x end)
   
   params:add_separator("")
   -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
   
   for n = 1, 4 do t[n] = track.new() end -- create tracks. but, adds params here
   
   -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
   params:add_separator("")
   nb:add_player_params()

   newline()

   params:bang()
   -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

   bpm = params:get("clock_tempo")
   speed_limit = params:get("speed_limit")

   big_message = "bpm:"
   big_number = bpm
   
   for pattern = 1, 4 do
      pattern_clear(pattern)
   end
   
   if crow_trig then
      crow_init()
   end

   clk_main = clock.run(c_main)
   clk_fps = clock.run(c_fps)
   
   if save_on_exit then
      params:read(norns.state.data .. "state.pset")
   end   
   
   g_redraw()
end

-- clock
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function c_main()
   while true do
      clock.sync(1/ppqn)
      
      if retrigger and #loop_buff > 1 and t[1].substep == 1 then
         jump_step = jump_step + 1
         if jump_step > #loop_buff then jump_step = 1 end
      end

      for track = 1, 4 do
         if erase and trig[track] then -- erase steps
            t[track]:write(0)
         end
         
         if fill and trig[track] then -- fill steps
            local rate = ppqn / 4 / fill_rate[util.clamp(#fill_buff, 0, #fill_rate)]

            if ((t[track].substep - 1) % rate) + 1 == ((trig_index[track] - 1) % rate) + 1 then
               if rec[track] then
                  t[track]:write(1)
               end
               
               if not rec[track] and not mute[track] then
                  t[track]:hit()           
               end
            end
            message = "fill " .. track .. " / " .. fill_rate[#fill_buff]
         end
         
         if t[track].data[t[track].index] == 1 and not mute[track] then -- trigger hit if not muted
            t[track]:hit()
         end	
      end
      
      crow_send_trigs(crow_hits)

      if t[1].substep == 1 then -- tick every 16th step
         g_redraw()
      end
      
      for track = 1, 4 do
         g_blink_triggers(track)
         
         if t[track].forward then
            t[track]:inc()
         end
         
         if not t[track].forward then
            t[track]:dec()
         end

         if t[track].substep == 1 and t[track].forward or t[track].substep == 24 and not t[track].forward then -- tick every 16th step
            if retrigger then -- retrigger step
               if jump_step > #loop_buff then jump_step = 1 end
               
               if #loop_buff == 1 then
                  t[track]:reset(loop_buff[1].step)
               end
               
               if #loop_buff > 1 then
                  t[track]:reset(loop_buff[jump_step].step)
               end
            end
         end
      end
   end
end

function c_fps()
   while true do
      clock.sleep(1/fps)
      frame = frame + 1
      if frame > fps then
         frame = 1
      end
      frame_anim = util.clamp(math.floor(frames / fps * frame), 1, frames)
      frame_rnd = math.random(frames)
      g_redraw()
   end
end

-- grid: keys
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function g.key(x, y, z)
   
   local row = y
   local col = x

   -- track held keys
   g_buffer(key_buff, x, z)
   
   -- shift 1 and 2
   if row == 8 and col >=6 and col <=8 then
      g_buffer(shift_buff_1, col, z)
   end
    
   if row == 8 and col >=9 and col <=11 then
      g_buffer(shift_buff_2, col, z)

      if erase then
         for n = 1, 4 do
            t[n]:clear_sequence()
         end
      end
   end

   if #shift_buff_1 > 0 then shift_1 = true else shift_1 = false end
   if #shift_buff_2 > 0 then shift_2 = true else shift_2 = false end
   if #shift_buff_2 > 0 then message = "shift" end
   
   -- sequence
   if row <= 4 then

      if z == 1 then
         
         edit.track = y
         edit.step = x
         edit.substep = 1

         if select then
            edit.track = y
            edit.step = x
            edit.substep = 1
         end

         if not shift_1 and not select then
            if t[row]:get_step(col) then
               t[row]:clear_step(col)
               message = "- step"
            else
               t[row]:write(1, t[row]:step_2_index(col))
               message = "+ step"
            end
         end
         
         if erase then
            t[row]:clear_step(col)
            message = "clear step"
         end
      end
   end
   
   -- loop and retrigger
   if row <= 4 then g_buffer(loop_buff, {track = row, step = col}, z) end

   if #shift_buff_1 == 1 then -- retrigger step
      retrigger = true
      message = "retrigger"
   end

   if #shift_buff_1 ~= 1 then
      retrigger = false
   end

   if #shift_buff_1 == 2 then -- loop single track
      message = "loop one"
      if row <= 4 then
         if #loop_buff > 1 then
            t[loop_buff[1].track]:loop(loop_buff[1].step, loop_buff[#loop_buff].step)
         end
      end
   end
      
   if #shift_buff_1 == 3 then -- loop all tracks
      message = "loop all"
      if #loop_buff > 1 then
         for track = 1, 4 do
            t[track]:loop(loop_buff[1].step, loop_buff[#loop_buff].step)
         end
      end
   end
      
   if shift_1 and erase then -- release loops
      message = "clear loops"
      if #shift_buff_1 == 1 then
         for track = 1, 4 do
            t[track]:loop(1, 16)
         end
      else
         for track = 1, 4 do
            t[track]:loop(1, 16)
            t[track]:reset()
         end
      end
   end

   -- rec
   if row == 5 and col <= 4 then
      if z == 1 then
         if rec[col] then
            rec[col] = false
            message = "rec " .. col .. " off"
         else
            rec[col] = true
            message = "rec " .. col .. " on"
         end
      end   
   end
   
   -- mutes
   if row == 6 and col <= 4 then
      if z == 1 then
         if mute[col] then
            mute[col] = false
            message = "mute " .. col .. " off"
         else
            mute[col] = true
            message = "mute " .. col .. " on"
         end
      end
   end   
   
   -- triggers
   if row >= 7 and col <= 4 then
      if z == 1 then
         edit.track = col
         edit.step = t[col].step
         trig_index[col] = t[col].substep
         trig[col] = true
         message = "trig " .. col
      end
      
      if z == 0 then
         trig[col] = false
         trig_index[col] = 1
      end
      
      if erase then
         t[col]:write(0)
         message = "clear " .. col
      end
      
      if not mute[col] and not erase then
         if z == 1 and rec[col] then
            t[col]:write(1)
            t[col]:hit()
            crow_send_trigs(crow_hits)
         end
         
         if z == 1 and not rec[col] then
            t[col]:hit()
            crow_send_trigs(crow_hits)
         end
      end

   end
   
   -- patterns
   do
      local pattern_number = col - 12

      if row == 5 and col >= 13 then
         if z == 1 then pattern = true else pattern = false end
      end
      
      if pattern and not shift_2 and not erase then
         pattern_to_sequence(pattern_number)
         message = "pat. " .. pattern_number .. " load"
      end
      
      if pattern and shift_2 then
         sequence_to_pattern(pattern_number)
         message = "pat. " .. pattern_number .. " save"
      end
      
      if pattern and erase then 	
         pattern_clear(pattern_number)
         message = "pat. " .. pattern_number .. " clear"
      end
   end

   -- erase
   if row == 6 and col == 16 then
      if z == 1 then erase = true else erase = false end
      message = "clear"
   end

   if erase and shift_2 then
      for track = 1, 4 do
         if rec[track] then
            t[track]:clear_sequence()
         end
      end
      message = "clear all"
   end
   
   -- select
   if row == 6 and col == 15 then
      if z == 1 then select = true else select = false end
      message = "select"
   end

   if select then
      big_message = ""
      local note = t[edit.track].data_note[t[edit.track]:step_2_index(edit.step) + edit.substep - 1]
      big_number = musicutil.note_num_to_name(note, true)
   end

   -- reset
   if row == 6 and col == 14 then
      if z == 1 then seq_reset = true else seq_reset = false end
      
      if z == 1 then
         for track = 1, 4 do
            t[track]:reset()
         end
      end
   halt_step = 1
   message = "reset"
   end
   
   -- play
   if row == 6 and col == 13 then
      if z == 1 then
         if shift_2 then
            for track = 1, 4 do
               if t[track].forward then
                  t[track].forward = false
                  message = "rev."
               else
                  t[track].forward = true
                  message = "fwd."
               end
            end
         end

         if not shift_2 then
            if seq_play then
               clock.cancel(clk_main)
               seq_play = false
               message = "pause"
            else
               clk_main = clock.run(c_main)
               seq_play = true
               message = "play"
            end
         end
      end
   end   

   -- fill
   if (row == 7 or row == 8) and col >= 13 then
      local col = ((row - 7) * 4) + col - 12 
      g_buffer(fill_buff, col, z)
      if #fill_buff > 0 then fill = true else fill = false end
   end      
   
   if fill then
      message = "fill"
   end

   -- substep edit
   if (row == 5 or row == 6 or row == 7) and (col >=5 and col <= 12) then
      if z == 1 then
         local substep = (col - 4) + ((row - 5) * 8)
         local index = t[edit.track]:step_2_index(edit.step) + substep - 1
         
         edit.substep = substep

         if not select then
            if t[edit.track].data[index] == 1 then
               t[edit.track]:write(0, index)
               message = "- substep"
            else
               t[edit.track]:write(1, index)
               message = "+ substep"
            end
         end

         if t[edit.track].data[index] == 1 and erase then
            t[edit.track]:write(0, index)
            message = "clear substep"
         end
      end
   end

   if #key_buff == 0 then screen_name(0.15) end

   g_redraw()
end

-- grid: "color" palette
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local br_seq_l			=  4	-- sequence, looping steps
local br_seq_a			= 12	-- sequence, active steps
local br_seq_t			= 15	-- sequence, tracer
local br_seq_mod		=  1	-- sequence, mod
local br_sub			=  2	-- substeps, background
local br_sub_a			= 10	-- substeps, active steps
local br_sub_t			=  5	-- substeps, tracer
local br_rec			=  1	-- record
local br_m				=  8	-- mute
local br_t				=  4	-- triggers
local br_t_a			= 10	-- triggers, active steps
local br_t_h			= 15	--	triggers, held
local br_t_mod 		=  2	-- triggers, mod
local br_shift_1		=  5	-- shift 1
local br_shift_2		=  5	-- shift 2
local br_pat_e			=  0	-- pattern, empty
local br_pat_f			=  8	-- pattern, full
local br_pat_c			=  4	-- pattern, current, empty
local br_pat_c_f		= 12	-- pattern, current, full
local br_pat_mod 		=  2	-- pattern, mod
local br_e				=  8	-- erase
local br_e_a			=  2	-- erase, active
local br_e_mod			=  2	-- eaase, mode
local br_sel         =  4  -- select step
local br_sel_a       =  8  -- select step, active
local br_sel_mod	   =  4	-- select step, mod
local br_reset			=  8	-- reset
local br_reset_a		= 10	-- reset, active
local br_play			=  4	-- play
local br_play_a		= 10	-- play, active
local br_fill			=  4	-- fill
local br_fill_a		=  5	-- fill, active

local br_t_val       = {0, 0, 0, 0}  -- triggers, value
local br_t_val_prev  = {0, 0, 0, 0}  -- triggers, previous value

-- grid: lights
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function g_redraw()

   g:all(0)

   -- loop
   for y = 1, 4 do
      for x = t[y].loop_start, t[y].loop_end do
         if shift_1 then
            g:led(x, y, br_seq_l + br_seq_mod)
         else
            g:led(x, y, br_seq_l)
         end
      end
   end

   -- sequence
   for y = 1, 4 do
      for x = 1, 16 do
         if t[y].data_step[x] == 1 then
            if erase then
               g:led(x, y, br_seq_a - br_e_mod)
            else
               g:led(x, y, br_seq_a)
            end
         end
      end
   end

   -- track controls
   for x = 1, 4 do
      -- rec
      if rec[x] then g:led(x, 5, br_rec + frame_anim) end
      if not rec[x] then g:led(x, 5, 0) end

      -- mute
      if mute[x] then g:led(x, 6, br_m) end
      if not mute[x] then g:led(x, 6, 0) end
   end
   
   -- triggers
   for x = 1, 4 do
      if trig[x] then
         br_t_val[x] = br_t_h
      end

      if not trig[x] then
         br_t_val[x] = br_t
      end
      
      if mute[x] then
         br_t_val[x] = 0
      end
      
      if fill and not mute[x] then 
         br_t_val[x] = br_t + br_t_mod
      end

      g:led(x, 7, br_t_val[x])
      g:led(x, 8, br_t_val[x])
   end

   -- shift_1 (loop)
   for x = 6, 8 do
      if shift_1 then
         g:led(x, 8, br_shift_1 + #shift_buff_1 * 2)
      else
         g:led(x, 8, br_shift_1)
      end

      if erase then
         g:led(x, 8, br_shift_1 + br_e_mod)
      end
   end
   
   -- shift_2
   for x = 9, 11 do
      if shift_2 then
         g:led(x, 8, br_shift_2 + 4)
      else
         g:led(x, 8, br_shift_2)
      end

      if erase and not shift_1 then 
         g:led(x, 8, br_e_a)
      end
   end
   
   -- patterns
   for x = 1, 4 do		
      if p.state[x] == "empty" then
         g:led(x + 12, 5, br_pat_e)
      end
      
      if p.state[x] == "full" then
         g:led(x + 12, 5, br_pat_f)
      end

      if p_current == x and p.state[x] == "empty" then
         g:led(x + 12, 5, br_pat_c)
      end	

      if p_current == x and p.state[x] == "full" then
         g:led(x + 12, 5, br_pat_c_f)
      end	
      
      if shift_2 and not shift_1 then
         if p.state[x] == "empty" then
            g:led(x + 12, 5, br_pat_e + br_pat_mod)
         end
         
         if p.state[x] == "full" then
            g:led(x + 12, 5, br_pat_f + br_pat_mod)
         end
         
         if p_current == x and p.state[x] == "empty" then
            g:led(x + 12, 5, br_pat_c + br_pat_mod)
         end	
         
         if p_current == x and p.state[x] == "full" then
            g:led(x + 12, 5, br_pat_c_f + br_pat_mod)
         end	
      end
      
      if erase then
         if p.state[x] == "full" then
            g:led(x + 12, 5, br_pat_f - br_pat_mod)
         end

         if p_current == x and p.state[x] == "empty" then
            g:led(x + 12, 5, br_pat_c - br_pat_mod)
         end	

         if p_current == x and p.state[x] == "full" then
            g:led(x + 12, 5, br_pat_c_f - br_pat_mod)
         end	
      end
   end		
   
   -- erase
   if erase then
      g:led(16, 6, br_e_a)
   elseif shift_1 then
      g:led(16, 6, br_e + br_e_mod)
   elseif shift_2 and not shift_1 then
      g:led(16, 6, br_e_a)
   else
      g:led(16, 6, br_e)
   end
   
   -- select
   if select then
      g:led(15, 6, br_sel_a)
   else
      g:led(15, 6, br_sel)
   end

   -- reset
   if seq_reset then
      g:led(14, 6, br_reset_a)
   else
      g:led(14, 6, br_reset)
   end
   
   -- play
   if seq_play then
      if shift_2 then
         if t[1].forward then
            g:led(13, 6, br_play_a + frame_anim - frames)
         end
         if not t[1].forward then
            g:led(13, 6, br_play_a - frame_anim)
         end
      end
      if not shift_2 then
         if t[1].forward then
            g:led(13, 6, br_play_a - frame_anim)
         end
         if not t[1].forward then
            g:led(13, 6, br_play_a + frame_anim - frames)
         end
      end
   end

   if not seq_play then
      g:led(13, 6, br_play)
   end
   
   -- fill
   for x = 13, 16 do
      for y = 7, 8 do
         if fill then
            g:led(x, y, br_fill_a + #fill_buff)
         else
            g:led(x, y, br_fill)
         end
      end
   end

   -- step edit: blink selection
   do
      local track = edit.track
      local step = edit.step
      local edit = t[track]
      
      if edit.data_step[step] == 0 then
         if select then
            if edit.step < edit.loop_start or edit.step > edit.loop_end then
               g:led(step, track, br_seq_l + br_sel_mod - frame_anim)
            else
               g:led(step, track, br_seq_l + br_sel_mod - frame_anim)
            end
         else
            if edit.step < edit.loop_start or edit.step > edit.loop_end then
               g:led(step, track, br_seq_l - math.floor(frame_anim / 3))
            else
               g:led(step, track, br_seq_l - math.floor(frame_anim / 3))
            end
         end
      end
      
      if edit.data_step[step] == 1 then
         g:led(step, track, br_seq_a - frame_anim)
      end
   end
   
   -- substep edit
   for y = 5, 7 do
      for x = 5, 12 do
         local substep = (x - 4) + ((y - 5) * 8)
         local track = edit.track
         local step = t[track]:step_2_index(edit.step)

         if t[track].substep == substep and not seq_play then
            g:led(x, y, br_sub + br_sub_t)
         else
            g:led(x, y, br_sub)
         end

         if t[track].data[step + substep - 1] == 1 then
            if t[track].substep == substep and not seq_play then
               g:led(x, y, br_sub_a + br_sub_t)
            else
               g:led(x, y, br_sub_a)
            end
         end
      end
   end

   -- substep edit: blink selection
   do
      local x = (((edit.substep - 1) % 8) + 1) + 4
      local y = math.floor((edit.substep - 1) / 8) + 5
      local index = t[edit.track]:step_2_index(edit.step) + edit.substep - 1

      if t[edit.track].data[index] == 1 then
         g:led(x, y, br_seq_a - frame_anim)
      else
         g:led(x, y, br_seq_l - math.floor(frame_anim / 3))
      end
      
   end

   -- tracers
   for y = 1, 4 do
      if edit.track == y and edit.step == t[y].step then -- blink tracer on edited step
         g:led(t[y].step, y, br_seq_t - frame_anim)
      else 
         g:led(t[y].step, y, br_seq_t) -- normal bright tracer
      end
   end
      
   g:refresh()
end

function g_blink_triggers(track)
   if trig_pulled[track] then
      g:led(track, 7, br_t_val[track])
      g:led(track, 8, br_t_val[track])
      trig_pulled[track] = false
   end
   
   if t[track].data[t[track].index] == 1 and not mute[track] then
      g:led(track, 7, br_t_h)
      g:led(track, 8, br_t_h)
      trig_pulled[track] = true
   end 

   g:refresh()
end

-- norns: keys
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function key(n, z)

   if n == 1 then
      if z == 1 then k1_held = true else k1_held = false end
   end
   
   if n == 1 then
      if z == 1 then
         big_message = "lim:"
         big_number = speed_limit
      else
         big_message = "bpm:"
         big_number = bpm
      end
   end
   
   if n == 2 then -- play
      if z == 1 then
         if seq_play then
            clock.cancel(clk_main)
            seq_play = false
            halt_step = t[edit.track].step
            message = "pause"
         else
            clk_main = clock.run(c_main)
            seq_play = true
            message = "play"
         end
      end
   end
   
   if n == 3 then -- reset
      if z == 1 then
         for n = 1, 4 do
            t[n]:reset()
         end
      end
      halt_step = 1
      message = "reset"
   end
   
   if z == 0 then
      screen_name(0.5)
   end
end

-- norns: encoders
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function enc(n, d)

   if n == 1 and not k1_held then
      params:delta("clock_tempo", d)
      bpm = params:get("clock_tempo")
      big_number = bpm
      
   end
   
   if n == 1 and k1_held then
      d = util.clamp(d, -1, 1)
      params:delta("speed_limit", d)
      speed_limit = params:get("speed_limit")
      big_number = speed_limit
   end
   
   if n == 2 then
      if not select then -- randomize
         if  #shift_buff_2 == 0 then
            for n = 1, d do
               if d > 0 then -- add step to random 16th
                  for brute_force = 1, 64 do            
                     local track = random_track_if_rec()
                     local step = math.random(16)
                     local index = t[track]:step_2_index(step)
                     if t[track].data_step[step] == 0 then
                        t[track]:write(1, index)
                     end
                     edit.track = track
                     edit.step = step
                     edit.substep = 1
                     break
                  end   
                  message = "+ step"    
               end 
            end
            
            if d < 0 then -- remove last step (either programed or random)
               for n = 1, math.abs(d) do
                  if #active_steps > 0 then
                     local track = t[active_steps[#active_steps].track]
                     local step = track:index_2_step(active_steps[#active_steps].index)
                     track:clear_step(step)
                  end
               end
               message = "- step"
            end
         end

         if #shift_buff_2 > 0 then
            for n = 1, d do
               if d > 0 then -- add step to random substep
                  for brute_force = 1, 4 * 384 do
                     local track = random_track_if_rec()
                     local index = math.random(384)
                     if t[track].data[index] == 0 then
                        t[track]:write(1, index)
                     end
                     edit.track = track
                     edit.step = t[track]:index_2_step(index)
                     edit.substep = ((index - 1) % 24) + 1
                     break
                  end       
                  message = "+ substep"
               end 
            end
         end

         if d < 0 then -- remove last step (either programed or random)
            if #active_steps > 0 then
               local track = t[active_steps[#active_steps].track]
               local index = active_steps[#active_steps].index
               track:write(0, index)
            end
            message = "- substep"
         end
      end
   
      if select then -- skipt to next active step or next step if none are active
         d = util.clamp(d, -1, 1)
         edit.track = ((edit.track - 1 + d) % 4) + 1
         message = "track " .. edit.track
      end
   end

   if n == 3 then 
      local track = edit.track
      local step = t[track]:step_2_index(edit.step)
      local index = t[track]:step_2_index(edit.step) + edit.substep - 1
      local note = t[track].data_note[index] + t[track].note
      
      if not select then -- edit selected note
         if #shift_buff_2 == 0 then
            t[track].data_note[index] = t[track].data_note[index] + d
            message = "♫: substep"
         end

         if #shift_buff_2 == 1 then -- edit all notes on step
            for n = 0, 27 do
               t[track].data_note[step + n] = t[track].data_note[step + n] + d
               message = "♫: step"
            end
         end

         if #shift_buff_2 == 2 then -- edit all notes in track
            for n = 1, 384 do
               t[track].data_note[n] = t[track].data_note[n] + d
               message = "♫: track"
            end
         end

         if #shift_buff_2 == 3 then -- edit all notes
            for n = 1, 4 do
               for m = 1, 384 do
                  t[n].data_note[m] = t[n].data_note[m] + d
                  message = "♫: all"
               end
            end
         end
      end
      
      if erase then -- reset note
         t[track].data_note[index] = 0
         message = "♫ = root"
      end
      
      if erase and select then -- reset all notes on track
         for index = 1, 384 do
            t[track].data_note[index] = 0
            message = "♫ = tr.root"
         end
      end
      
      big_message = ""
      big_number = musicutil.note_num_to_name(note, true)
      
      if select then -- skipt to next active step or next step if none are active
         d = util.clamp(d, -1, 1)
         
         local index = t[edit.track]:step_2_index(edit.step) + edit.substep - 1
         local steps
         for n = 1, 16 do
            steps = false
            if t[edit.track].data_step[n] == 1 then
               steps = true
               break
            end
         end

         if not steps then
            if d > 0 then   
               index = index + 1
               if index >= 384 then index = 1 end
               edit.substep = ((index - 1) % 24) + 1
               edit.step = t[edit.track]:index_2_step(index)
               message = "step: " .. edit.step .. "." .. edit.substep
            end
            
            if d < 0 then
               index = index - 1
               if index < 1 then index = 384 end
               edit.substep = ((index - 1) % 24) + 1
               edit.step = t[edit.track]:index_2_step(index)
               message = "step: " .. edit.step .. "." .. edit.substep
            end
         end
         
         if steps then
            if d > 0 then   
               index = index + 1
               while t[edit.track].data[index] == 0 do
                  index = index + 1
                  if index >= 384 then index = 1 end
                  edit.substep = ((index - 1) % 24) + 1
                  edit.step = t[edit.track]:index_2_step(index)
                  message = "step: " .. edit.step .. "." .. edit.substep
               end
            end
            
            if d < 0 then
               index = index - 1
               while t[edit.track].data[index] == 0 do   
                  index = index - 1
                  if index < 1 then index = 384 end
                  edit.substep = ((index - 1) % 24) + 1
                  edit.step = t[edit.track]:index_2_step(index)
                  message = "step: " .. edit.step .. "." .. edit.substep
               end
            end
         end
      end
   end

   screen_name(1)
end

-- norns: screen
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function redraw()
   screen.clear()
   screen.level(15)
   screen.font_face(1)
   
   screen.rect(0, 46, 128, 19)
   screen.fill()
   
   screen.move(0, 40)
   screen.font_size(16)
   screen.text(big_message)
   screen.move(128, 40)
   screen.font_size(48)
   screen.text_right(big_number)   
   
   screen.level(0)
   screen.font_size(16)
   screen.move(123, 59)
   screen.text_right(message)

   -- debug text
   -- screen.level(15)
   -- screen.font_size(8)
   -- screen.move(0, 8)
   -- screen.text(test or 42)
   -- debug end

   screen.update()
end

function refresh()
   redraw()
end

-- tidy up before we go
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function cleanup()
   nb:stop_all()
   if save_on_exit then
      params:write(norns.state.data .. "state.pset")
   end
end
