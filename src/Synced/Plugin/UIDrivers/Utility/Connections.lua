-- Connections.lua
-- Responsible for drawing visual connections (lines) between nodes in the UI, reflecting the logical links between them.

local Connections = {}
Connections.__index = Connections

function Connections.new(connLayer, state)
	local self = setmetatable({}, Connections)
	self.connLayer = connLayer
	self.state = state
	return self
end

function Connections:draw(NodeGraph, NodeTypes, selectedConnectionIdx)
	self.connLayer:ClearAllChildren()
	local zoom = self.state.zoom
	local offset = self.state.offset
	for idx, conn in ipairs(NodeGraph.connections) do
		local fromNode, toNode = NodeGraph.nodes[conn.from], NodeGraph.nodes[conn.to]
		if fromNode and toNode and conn.fromPort and conn.toPort then
			local fromDef = NodeTypes.Definitions and NodeTypes.Definitions[fromNode.type]
			local toDef = NodeTypes.Definitions and NodeTypes.Definitions[toNode.type]
			local fromOuts = fromDef and fromDef.outputs or {}
			local toIns = toDef and toDef.inputs or {}
			if fromOuts[conn.fromPort] and toIns[conn.toPort] then
				local fromPos = Vector2.new(fromNode.pos.X, fromNode.pos.Y) * zoom + offset + Vector2.new(fromNode.size and fromNode.size.X or 160,36 + ((conn.fromPort or 1)-1)*24) * zoom
				local toPos = Vector2.new(toNode.pos.X, toNode.pos.Y) * zoom + offset + Vector2.new(0,36 + ((conn.toPort or 1)-1)*24) * zoom
				local line = Instance.new("Frame")
				line.AnchorPoint = Vector2.new(0.5,0.5)
				line.BackgroundColor3 = (selectedConnectionIdx == idx) and Color3.fromRGB(255,80,80) or Color3.fromRGB(200, 200, 255)
				line.BorderSizePixel = 0
				local len = (toPos-fromPos).Magnitude
				line.Size = UDim2.new(0, len, 0, math.max(2, zoom*2))
				line.Position = UDim2.new(0, (fromPos.X+toPos.X)/2, 0, (fromPos.Y+toPos.Y)/2)
				line.Rotation = math.deg(math.atan2(toPos.Y-fromPos.Y, toPos.X-fromPos.X))
				line.BackgroundTransparency = 0.15
				line.ZIndex = 2
				line.Parent = self.connLayer
			end
		end
	end
end

return Connections
