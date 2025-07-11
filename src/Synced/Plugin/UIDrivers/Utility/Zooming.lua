-- Zooming.lua
-- Manages zooming in and out of the canvas using mouse wheel input, updating zoom level and view offset.

local Zooming = {}
Zooming.__index = Zooming

function Zooming.new(canvas, state)
	local self = setmetatable({}, Zooming)
	self.canvas = canvas
	self.state = state
	return self
end

-- Zooming logic: handle mouse wheel, update zoom and offset
function Zooming:handleInput(input)
	local canvas = self.canvas
	local state = self.state
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local UIS = game:GetService("UserInputService")
		local mousePos = UIS:GetMouseLocation() - canvas.AbsolutePosition
		local worldBefore = (mousePos - state.offset) / state.zoom
		state.zoom = math.clamp(state.zoom + (input.Position.Z > 0 and 0.1 or -0.1), state.minZoom, state.maxZoom)
		local worldAfter = (mousePos - state.offset) / state.zoom
		state.offset = state.offset + (worldAfter - worldBefore) * state.zoom
		if state.NodeGraph._hookRedraw then state.NodeGraph._hookRedraw() end
		canvas:SetAttribute("OffsetX", state.offset.X)
		canvas:SetAttribute("OffsetY", state.offset.Y)
		canvas:SetAttribute("Zoom", state.zoom)
	end
end

return Zooming
