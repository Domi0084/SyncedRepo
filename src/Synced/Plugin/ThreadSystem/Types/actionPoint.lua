-- ActionPoint.lua
local actionPoint = {}
actionPoint.__index = actionPoint

function actionPoint.new(position, actionType, params)
    local self = setmetatable({}, actionPoint)
    self.Position = position -- CFrame or Position
    self.Type = actionType -- e.g., "Wrap", "Orbit", etc.
    self.Params = params or {} -- extra params for this action
    return self
end

function actionPoint:Serialize()
    -- Returns a table for saving/exporting
    return {
        Position = self.Position,
        Type = self.Type,
        Params = self.Params
    }
end

function actionPoint:Describe()
    return string.format("actionPoint: %s at %s", self.Type, tostring(self.Position))
end

return actionPoint
