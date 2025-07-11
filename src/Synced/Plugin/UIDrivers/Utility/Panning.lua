-- Panning.lua
-- Handles mouse-based panning of the canvas, updating the view offset as the user drags.

local Panning = {}
Panning.__index = Panning

function Panning.new(canvas, state)
	local self = setmetatable({}, Panning)
	self.canvas = canvas
	self.state = state
	return self
end

function Panning:inputBegan(input, mousePos)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self.state.panning = true
		self.state.panStart = mousePos
		self.state.panOffsetStart = self.state.offset
	end
end

function Panning:inputChanged(input, mousePos)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local worldBefore = (mousePos - self.state.offset) / self.state.zoom
		self.state.zoom = math.clamp(self.state.zoom + (input.Position.Z > 0 and 0.1 or -0.1), self.state.minZoom, self.state.maxZoom)
		local worldAfter = (mousePos - self.state.offset) / self.state.zoom
		self.state.offset = self.state.offset + (worldAfter - worldBefore) * self.state.zoom
		if self.state.redraw then self.state.redraw() end
		self.canvas:SetAttribute("OffsetX", self.state.offset.X)
		self.canvas:SetAttribute("OffsetY", self.state.offset.Y)
		self.canvas:SetAttribute("Zoom", self.state.zoom)
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if self.state.panning and self.state.panStart then
			local delta = mousePos - self.state.panStart
			self.state.offset = self.state.panOffsetStart + delta
			if self.state.redraw then self.state.redraw() end
			self.canvas:SetAttribute("OffsetX", self.state.offset.X)
			self.canvas:SetAttribute("OffsetY", self.state.offset.Y)
			self.canvas:SetAttribute("Zoom", self.state.zoom)
		end
	end
end

function Panning:inputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self.state.panning = false
	end
end

return Panning
