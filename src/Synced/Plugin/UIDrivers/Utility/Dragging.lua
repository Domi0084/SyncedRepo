-- Dragging.lua
-- Handles logic for dragging nodes within the UI, including collision checks and updating node positions.

local Dragging = {}
Dragging.__index = Dragging

function Dragging.new(canvas, state)
	local self = setmetatable({}, Dragging)
	self.canvas = canvas
	self.state = state
	self.draggingNodeIdx = nil
	self.dragStart = nil
	self.dragOffset = nil
	return self
end

function Dragging:begin(idx, mousePos, node, zoom, offset)
	self.draggingNodeIdx = idx
	self.dragStart = mousePos
	self.dragOffset = Vector2.new(node.pos.X, node.pos.Y) * zoom + offset
end

function Dragging:update(mousePos, NodeGraph, zoom, offset, wouldCollide, toUDim2, DEFAULT_NODE_SIZE, redraw, canvas)
	if self.draggingNodeIdx and self.dragStart and self.dragOffset then
		local delta = mousePos - self.dragStart
		local node = NodeGraph.nodes[self.draggingNodeIdx]
		local nodeSize = node and (node.size or DEFAULT_NODE_SIZE) or DEFAULT_NODE_SIZE
		if node then
			local newPos = (self.dragOffset + delta - offset) / zoom
			if not wouldCollide(NodeGraph, self.draggingNodeIdx, newPos, nodeSize) then
				node.pos = toUDim2(newPos)
				if redraw then redraw() end
				if canvas then canvas.BackgroundColor3 = Color3.fromRGB(28,28,40) end
			else
				if canvas then
					canvas.BackgroundColor3 = Color3.fromRGB(75, 0, 0)
					task.delay(0.15, function()
						canvas.BackgroundColor3 = Color3.fromRGB(28,28,40)
					end)
				end
			end
		end
	end
end

function Dragging:endDrag()
	self.draggingNodeIdx = nil
	self.dragStart = nil
	self.dragOffset = nil
end

return Dragging
