-- Helpers.lua
-- Provides common helper functions for UI and utility code, such as clamping values and converting between position types (Vector2, UDim2, Vector3).

local Helpers = {}

function Helpers.clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

function Helpers.toUDim2(pos)
	if typeof(pos) == "UDim2" then return pos end
	if typeof(pos) == "Vector2" then return UDim2.new(0, pos.X, 0, pos.Y) end
	if typeof(pos) == "Vector3" then return UDim2.new(0, pos.X, 0, pos.Y) end
	return UDim2.new(0, 0, 0, 0)
end

function Helpers.toVector2(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "UDim2" then return Vector2.new(pos.X.Offset, pos.Y.Offset) end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	return Vector2.zero
end

function Helpers.toVector2Safe(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	return Vector2.zero
end

return Helpers
