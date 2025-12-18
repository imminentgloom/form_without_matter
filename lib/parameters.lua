-- init
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local musicutil = require("musicutil")
local nb        = include(norns.state.shortname .. "/lib/nb/lib/nb")

local state = _G.state

local prms = {
   line_count = 1
}

-- functions
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- add an "empty" line to the params menu without triggering namespace errors
function prms:newline()
   params:add_trigger(tostring("void_" .. self.line_count), "")
   params:set_action(tostring("void_" .. self.line_count), function() print("the void whispers back") end)
   self.line_count = self.line_count + 1
end

-- set up parameter menu
function prms:init()
   params:add_separator("form!matter")
   
   -- track
   params:add_trigger("heading track", "TRACK")
   for track = 1 , 4 do 
      params:add_group("↳ " .. track, 6)
      nb:add_param(tostring(t[track].voice), "voice:" )
      params:add_number("root_note_" .. track, "root note:", 0, 127, 60, function(x) return musicutil.note_num_to_name(x:get("note_" .. track), true) end)
      params:set_action("root_note_" .. track, function (x) t[track].root_note = x end)
      params:add_number("default_velocity_" .. track, "velocity:", 0, 400, 100, function(x) return x:get("default_velocity_" .. track) * 0.01 end)
      params:set_action("default_velocity_" .. track, function (x) t[track].default_velocity = x * 0.01 end)
      params:add_number("default_duration_" .. track, "duration:", 0, 1000, 1)
      params:set_action("default_duration_" .. track, function (x) t[track].default_duration = x * 0.001 end)
      params:add_number("speed_limit_" .. track, "speed limit:", 0, 24, 0)
      params:set_action("speed_limit_" .. track, function(x) t[track].speed_limit = x end)
   end
   self:newline()
   
   -- voice
   nb:add_player_params()
   
   -- initial pattern
   self:newline()
   params:add_trigger("heading pat. select", "INITIAL PATTERN")
   params:add_option("pattern_load", "↳ load", {"no", "yes"}, 1)
   params:add_number("pattern_bank", "↳ bank", 1, 4, 1)
   params:set_action("pattern_bank", function (x) state.pattern_bank = x end)
   params:add_number("pattern_slot", "↳ slot", 1, 4, 1)
   
   -- pattern load behaviour
   self:newline()
   params:add_trigger("heading pat. load", "PATTERN LOAD")
   params:add_option("pattern_blank", "↳ clear if blank", {"no", "yes"}, 2)
   params:add_option("pattern_rec", "↳ rec state", {"no", "yes"}, 1)
   params:add_option("pattern_mute", "↳ mute state", {"no", "yes"}, 1)
   params:add_option("pattern_loop", "↳ loop state", {"no", "yes"}, 1)
   params:add_option("pattern_reset", "↳ reset", {"no", "yes"}, 1)
   
   -- end
   self:newline()
end

return prms
