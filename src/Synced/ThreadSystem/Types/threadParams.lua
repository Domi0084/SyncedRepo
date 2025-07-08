-- ThreadParams.lua
-- Defines and validates parameters for a single thread

local ThreadParams = {}
ThreadParams.__index = ThreadParams

-- Creates a new ThreadParams table with defaults
function ThreadParams.new(params)
    local self = setmetatable({}, ThreadParams)
    params = params or {}
    self.element = params.element or "Air" -- Air, Water, Fire, Earth, Spirit
    self.width = tonumber(params.width) or 1
    self.color = params.color or Color3.fromRGB(200,200,255)
    -- Add more fields as needed
    return self
end

-- Validates the ThreadParams fields
function ThreadParams:Validate()
    local validElements = {Air=true, Water=true, Fire=true, Earth=true, Spirit=true}
    if not validElements[self.element] then
        error("Invalid element: " .. tostring(self.element))
    end
    if type(self.width) ~= "number" or self.width <= 0 then
        error("Width must be a positive number")
    end
    -- Add more validation as needed
    return true
end

return ThreadParams
