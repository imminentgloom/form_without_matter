Track = {   
   number = 0,
   active_steps = {},
   ordered_steps = {},
}

Track.__index = Track

-- useage: table[track_number] = Track:new() 
function Track:new()
	Track.number = Track.number + 1
   local t = setmetatable({}, Track)
	t.track = Track.number
	t.voice = "nb_voice_" .. t.track
   t.index = 1
   t.step = 1
   t.substep = 1
	t.forward = true
   t.root_note = 60
   t.default_velocity = 1.0
   t.default_duration = 1
   t.loop_start = 1
   t.loop_end = 16
   t.gate = {}
	t.note = {}
	t.velocity = {}
	t.duration = {}
	for index = 1, 384 do
		t.gate[index] = 0
		t.note[index] = 0
		t.velocity[index] = 0
		t.duration[index] = 0
	end
	t.step_status = {}
	for step = 1, 16 do
		t.step_status[step] = 0
	end
   t.last_hit = 0
   t.speed_limit = 0
   t.fill_index = 1
	return t
end

-- play note, hit drum
function Track:hit()

   -- skip consecutive hits if they are too close
   if self.last_hit >= self.speed_limit then

      -- trigger nb-voice
      player = params:lookup_param(self.voice):get_player()
      player:play_note(self.note[self.index] + self.root_note, self.velocity[self.index] + self.default_velocity, self.duration[self.index] + self.default_duration)
      
      -- trigger crow (for later)
      
      -- reset speed_limit count
      self.last_hit = 0
   end
end

-- toggels current step, or sets chosen step/value
function Track:write(gate, index)
   index = index or self.index
   gate = gate or self.gate[index] % 2
   local step = self:get_step(index)

   -- write data
   self.gate[index] = gate

   -- set step status to active
   if gate == 1 then
      self.step_status[step] = 1
   end

   -- set step status if no substeps remain active
   if gate == 0 then 
      if not self:get_status(step) then
         self.step_status[step] = 0
      end
   end

   -- track active steps
   if gate == 1 then
      table.insert(Track.active_steps, {track = self.track, index = index})
   end

   -- release as steps are cleared
   if gate == 0 then
      for i , v in ipairs(Track.active_steps) do
         if v.track == self.track and v.index == index then
            table.remove(Track.active_steps, i)
            break
         end
      end
   end

   -- build ordered table of active steps
   self:sort_active_steps()
end

-- Sort by "track", then by "index"
function Track:sort_active_steps()
   for n = 1, #Track.active_steps do Track.ordered_steps[n] = Track.active_steps[n] end
   table.sort(Track.ordered_steps, function(a, b)
       if a.track == b.track then
           return a.index < b.index
       else
           return a.track < b.track
       end
   end)
end

-- clear entire step
function Track:clear_step(step)
   step = step or self.step
   for index = self:get_index(step), self:get_index(step) + 23 do
      self:write(0, index)
   end
end

-- clear entire track
function Track:clear_track(track)
   track = track or self.track
   for index = 1, 384 do self.gate[index] = 0 end
   for step = 1, 16 do self.step_status[step] = 0 end
   for step = 1, #Track.active_steps do Track.active_steps[step] = nil end
   self:sort_active_steps()  
end

-- clock +
function Track:inc()
   self.index = self.index + 1
   if self.index > self:get_index(self.loop_end, 24) then
      self.index = self:get_index(self.loop_start)
   elseif
   self.index < self:get_index(self.loop_start) then
      self.index = self:get_index(self.loop_end, 24)
   end
   self.step = self:get_step(self.index)
   self.substep = self:get_substep(self.index)
   self:speed_limit_counter()
end

-- clock -
function Track:dec()
   self.index = self.index - 1
   if self.index < self:get_index(self.loop_start) then
      self.index = self:get_index(self.loop_end, 24)
   elseif
      self.index > self:get_index(self.loop_end, 24) then
      self.index = self:get_index(self.loop_start)
   end
   self.step = self:get_step(self.index)
   self.substep = self:get_substep(self.index)
   self:speed_limit_counter()
end

-- count substeps since last hit
function Track:speed_limit_counter()
   self.last_hit = self.last_hit + 1
   if self.last_hit > 23 then
      self.last_hit = 0
   end
end

-- set loop-points, step order is irrelevant
function Track:loop(l1, l2)
   l1 = l1 or 1
   l2 = l2 or 16
   self.loop_start = math.min(l1, l2)
   self.loop_end = math.max(l1, l2)   
end

-- reset to step or extents, both constrained by loop
function Track:reset(step)
   if self.forward then
      step = step or self.loop_start
      self.step = step
      self.substep = 1
      self.index = self:get_index(step, 1)
   else
      step = step or self.loop_end
      self.step = step
      self.substep = 24
      self.index = self:get_index(step, 24)
   end
end

-- get index for current or chosen step and first or choosen substep
function Track:get_index(step, substep)
   step = step or self.step
   substep = substep or 1
   return math.floor((step - 1) * 24 + substep)	
end

-- get index for current or chosen step
function Track:get_step(index)
   index = index or self.index
	return math.floor((index - 1) / 24) + 1
end

-- get substep (but not step) for current or chosen index
function Track:get_substep(index)
   index = index or self.index
	return ((index - 1) % 24) + 1
end

-- return true if there are active substeps on current or chosen step
function Track:get_status(step)
	step = step or self.step
   local status = nil
   for substep = 1, 24 do
      if self.gate[(step - 1) * 24 + substep] == 1 then
         status = true
         break
      end
   end
   return status or false
end

return Track
