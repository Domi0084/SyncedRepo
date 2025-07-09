-- ThreadService.lua
-- Creates ThreadClass instances

local ThreadClass = require(script.Parent.Parent.Classes.ThreadClass)
local PathService = require(script.Parent.PathService)
local ThreadService = {}
ThreadService.__index = ThreadService

function ThreadService.new()
	local self = setmetatable({}, ThreadService)
	self.PathService = PathService.new()
	return self
end

-- Creates a Thread with given configuration table {Params = ThreadParams, Path = PathParams}
function ThreadService:CreateThread(config)
	assert(config.Params, "Missing Params for thread creation")
	if config.Params.Validate then config.Params:Validate() end
	local thread = ThreadClass.new(config.Params)
	return thread
end

return ThreadService
