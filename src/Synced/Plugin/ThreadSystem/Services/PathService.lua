-- PathService.lua
-- Generates PathClass objects using PathParams

local PathClass = require(script.Parent.Parent.Classes.PathClass)
local PathService = {}
PathService.__index = PathService

function PathService.new()
	local self = setmetatable({}, PathService)
	return self
end

-- Returns a new PathClass based on parameters
-- @param params PathParams
function PathService:GeneratePath(params)
	assert(params, "Missing PathParams for path generation")
	if params.Validate then params:Validate() end
	local points = {}
	if params.Mode == "Spiral" then
		for i = 0, params.SpiralCount * math.pi * 2, math.pi / 8 do
			local radius = i / (math.pi * 2)
			table.insert(points, Vector3.new(math.cos(i) * radius, i * 0.2, math.sin(i) * radius))
		end
	elseif params.Mode == "Wave" then
		for i = 0, 10 do
			local x = i
			table.insert(points, Vector3.new(x, math.sin(i) * 2, 0))
		end
	else
		points = params.Points or {Vector3.new(), Vector3.new(0,0,10)}
	end
	return PathClass.new(points)
end

return PathService
