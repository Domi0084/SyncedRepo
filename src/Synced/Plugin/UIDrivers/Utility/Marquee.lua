-- Marquee.lua
-- Provides logic for drawing a selection rectangle (marquee) and selecting multiple nodes within that area.

local Marquee = {}
Marquee.__index = Marquee

function Marquee.new(canvas, state)
	local self = setmetatable({}, Marquee)
	self.canvas = canvas
	self.state = state
	return self
end

function Marquee:draw(zoom, offset, marqueeSelecting, marqueeStart, marqueeEnd)
	for _, child in ipairs(self.canvas:GetChildren()) do
		if child.Name == "MarqueeRect" then
			child:Destroy()
		end
	end
	if marqueeSelecting and marqueeStart and marqueeEnd then
		local minX, maxX = math.min(marqueeStart.X, marqueeEnd.X), math.max(marqueeStart.X, marqueeEnd.X)
		local minY, maxY = math.min(marqueeStart.Y, marqueeEnd.Y), math.max(marqueeStart.Y, marqueeEnd.Y)
		local rect = Instance.new("Frame")
		rect.Name = "MarqueeRect"
		rect.BackgroundColor3 = Color3.fromRGB(120,180,255)
		rect.BackgroundTransparency = 0.7
		rect.BorderSizePixel = 0
		rect.Position = UDim2.new(0, minX*zoom+offset.X, 0, minY*zoom+offset.Y)
		rect.Size = UDim2.new(0, (maxX-minX)*zoom, 0, (maxY-minY)*zoom)
		rect.ZIndex = 4
		rect.Parent = self.canvas
	end
end

local function toVector2Safe(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "UDim2" then return Vector2.new(pos.X.Offset, pos.Y.Offset) end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	return Vector2.zero
end

function Marquee:selectNodesInMarquee(NodeGraph, marqueeStart, marqueeEnd, zoom, offset, DEFAULT_NODE_SIZE)
	local minX, maxX = math.min(marqueeStart.X, marqueeEnd.X), math.max(marqueeStart.X, marqueeEnd.X)
	local minY, maxY = math.min(marqueeStart.Y, marqueeEnd.Y), math.max(marqueeStart.Y, marqueeEnd.Y)
	local selected = {}
	for idx, node in ipairs(NodeGraph.nodes) do
		local nodePos = toVector2Safe(node.pos)
		local nodeSize = toVector2Safe(node.size or DEFAULT_NODE_SIZE)
		local nodeMinX, nodeMaxX = nodePos.X, nodePos.X + nodeSize.X
		local nodeMinY, nodeMaxY = nodePos.Y, nodePos.Y + nodeSize.Y
		if nodeMaxX > minX and nodeMinX < maxX and nodeMaxY > minY and nodeMinY < maxY then
			table.insert(selected, idx)
		end
	end
	return selected
end

return Marquee
