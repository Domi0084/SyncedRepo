-- WeaveClass.lua
-- Represents a controllable collection of threads

local ThreadClass = require(script.Parent.ThreadClass)
local Signal = require(script.Parent.SignalClass)

local WeaveClass = setmetatable({}, ThreadClass)
WeaveClass.__index = WeaveClass

-- Creates a new weave from a list of ThreadClass instances
-- @param threadList table: array of ThreadClass
function WeaveClass.new(threadList)
    local self = setmetatable(ThreadClass.new(nil, nil), WeaveClass)
    self.Threads = threadList or {}
    self.OnTangled = Signal.new()
    return self
end

-- Example method that tangles the threads together
-- Fires OnTangled event
function WeaveClass:Tangle()
    -- Implementation specific to your game
    self.OnTangled:Fire(self)
end

-- Splits the weave back into individual threads
function WeaveClass:Split()
    -- Implementation placeholder
end

return WeaveClass
