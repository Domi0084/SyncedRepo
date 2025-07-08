-- WeaveService.lua
-- Creates and manages WeaveClass objects

local WeaveClass = require(script.Parent.Parent.Classes.WeaveClass)
local WeaveService = {}
WeaveService.__index = WeaveService

function WeaveService.new()
	local self = setmetatable({}, WeaveService)
	return self
end

-- Combines threads into a single weave
function WeaveService:Weave(threadList)
	return WeaveClass.new(threadList)
end

return WeaveService
