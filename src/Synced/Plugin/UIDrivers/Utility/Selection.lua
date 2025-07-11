-- Selection.lua
-- Implements logic for selecting nodes in the UI, including single-click selection and deselection.

local Selection = {}
Selection.__index = Selection

function Selection.new(canvas, state)
	local self = setmetatable({}, Selection)
	self.canvas = canvas
	self.state = state
	return self
end

-- Selection logic: single click, marquee, deselect
function Selection:handleInput(input)
	local UIS = game:GetService("UserInputService")
	local canvas = self.canvas
	local state = self.state
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UIS:GetMouseLocation() - canvas.AbsolutePosition
		-- Check if click is on a node
		local overNode = false
		for idx, node in ipairs(state.NodeGraph.nodes) do
			local pos = node.pos
			if typeof(pos) == "UDim2" then pos = Vector2.new(pos.X.Offset, pos.Y.Offset) end
			local size = state.DEFAULT_NODE_SIZE * state.zoom
			if mousePos.X >= pos.X and mousePos.X <= pos.X + size.X and mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + size.Y then
				overNode = true
				state.selectedNodeIdx = idx
				if state.PropertyPanel then state.PropertyPanel:Show(idx) end
				break
			end
		end
		if not overNode then
			state.selectedNodeIdx = nil
			if state.PropertyPanel then state.PropertyPanel:Hide() end
		end
	end
end

return Selection
