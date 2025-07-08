-- PathParams.lua
-- Defines and validates parameters for a path

local PathParams = {}
PathParams.__index = PathParams

function PathParams.new(params)
    local self = setmetatable({}, PathParams)
    params = params or {}
    self.Mode = params.Mode or "Line" -- Line, Spiral, Wave, etc.
    self.SpiralCount = tonumber(params.SpiralCount) or 1
    self.Points = params.Points or {Vector3.new(), Vector3.new(0,0,10)}
    -- Add more fields as needed
    return self
end

function PathParams:Validate()
    local validModes = {Line=true, Spiral=true, Wave=true}
    if not validModes[self.Mode] then
        error("Invalid path mode: " .. tostring(self.Mode))
    end
    if self.Mode == "Spiral" and (type(self.SpiralCount) ~= "number" or self.SpiralCount <= 0) then
        error("SpiralCount must be a positive number for Spiral mode")
    end
    if type(self.Points) ~= "table" or #self.Points < 2 then
        error("Points must be a table with at least two Vector3s")
    end
    -- Add more validation as needed
    return true
end

return PathParams
