-- Signal.lua - Simple event utility similar to Roblox's BindableEvent

local Signal = {}
Signal.__index = Signal

-- Creates a new Signal object
function Signal.new()
    local self = setmetatable({}, Signal)
    self._bindable = Instance.new("BindableEvent")
    return self
end

-- Connects a function to the signal
function Signal:Connect(fn)
    return self._bindable.Event:Connect(fn)
end

-- Fires the signal with any arguments
function Signal:Fire(...)
    self._bindable:Fire(...)
end

-- Waits for the signal to fire and returns the arguments
function Signal:Wait()
    return self._bindable.Event:Wait()
end

-- Destroys the signal
function Signal:Destroy()
    self._bindable:Destroy()
end

return Signal
