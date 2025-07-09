--[[
NodeCanvas: Full-featured node editor for Roblox
Features: zoom, pan, connections, property panel, strict Vector3 safety
Improvements: Better structure, error handling, cleanup, return value, and selection logic.
--]]

local NodeFrame = require(script.Parent.NodeFrame)

local DEFAULT_NODE_SIZE = Vector2.new(160, 80)

--------------------------------------------------------------------------------
-- Type Conversion Utilities
--------------------------------------------------------------------------------

local function toUDim2(pos)
	if typeof(pos) == "Vector3" or typeof(pos) == "Vector2" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "UDim2" then
		return pos
	end
	return UDim2.new(0, 0, 0, 0)
end

local function toVector2(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "UDim2" then return Vector2.new(pos.X.Offset, pos.Y.Offset) end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	return Vector2.zero
end

local function toVector2Safe(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	error("[NodeCanvas] toVector2Safe: unsupported type " .. typeof(pos))
end

--------------------------------------------------------------------------------
-- Internal Helper Functions
--------------------------------------------------------------------------------

local function clampBounds(val, min, max)
	return math.max(min, math.min(max, val))
end

local function checkCollision(pos1, size1, pos2, size2)
	return pos1.X < pos2.X + size2.X and
	       pos1.X + size1.X > pos2.X and
	       pos1.Y < pos2.Y + size2.Y and
	       pos1.Y + size1.Y > pos2.Y
end

local function wouldCollide(NodeGraph, draggedNodeIdx, newPos, nodeSize)
	nodeSize = nodeSize or DEFAULT_NODE_SIZE
	for idx, node in ipairs(NodeGraph.nodes) do
		if idx ~= draggedNodeIdx then
			local otherPos = toVector2(node.pos)
			local otherSize = node.size or DEFAULT_NODE_SIZE
			if checkCollision(newPos, nodeSize, otherPos, otherSize) then
				return true
			end
		end
	end
	return false
end

local function findFreePosition(NodeGraph)
	local gridSize, nodeSize = 32, DEFAULT_NODE_SIZE
	local startX, startY = 80, 80
	for y = startY, 1000, nodeSize.Y + gridSize do
		for x = startX, 2000, nodeSize.X + gridSize do
			local candidate = Vector2.new(x, y)
			local collision = false
			for _, node in ipairs(NodeGraph.nodes) do
				local pos = toVector2(node.pos)
				if math.abs(pos.X - candidate.X) < nodeSize.X and math.abs(pos.Y - candidate.Y) < nodeSize.Y then
					collision = true
					break
				end
			end
			if not collision then
				return candidate
			end
		end
	end
	return Vector2.new(startX, startY)
end

--------------------------------------------------------------------------------
-- Main NodeCanvas Class
--------------------------------------------------------------------------------

local NodeCanvas = {}
NodeCanvas.__index = NodeCanvas

function NodeCanvas.new(widget, NodeGraph, NodeTypes, PropertyPanel)
	local UIS = game:GetService("UserInputService")
	local connections = {}
	local self = setmetatable({}, NodeCanvas)

	-- UI Structure
	local canvas = Instance.new("Frame")
	canvas.Name = "NodeCanvas"
	canvas.Position = UDim2.new(0,0,0,36)
	canvas.Size = UDim2.new(1,0,1,-36)
	canvas.BackgroundColor3 = Color3.fromRGB(28,28,40)
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true
	canvas.Parent = widget

	local WorkSpace = Instance.new("Frame")
	WorkSpace.Name = "WorkSpace"
	WorkSpace.BackgroundTransparency = 1
	WorkSpace.Size = UDim2.new(1,0,1,0)
	WorkSpace.Position = UDim2.new(0,0,0,0)
	WorkSpace.ClipsDescendants = false
	WorkSpace.Parent = canvas

	local connLayer = Instance.new("Frame")
	connLayer.Name = "ConnectionLayer"
	connLayer.BackgroundTransparency = 1
	connLayer.Size = UDim2.new(1,0,1,0)
	connLayer.Position = UDim2.new(0,0,0,0)
	connLayer.ZIndex = 10
	connLayer.Parent = WorkSpace

	-- State
	local offset, zoom = Vector2.new(0,0), 1.0
	local minZoom, maxZoom = 0.3, 2.5
	local draggingNodeIdx, dragStart, dragOffset = nil, nil, nil
	local panning, panStart, panOffsetStart = false, Vector2.zero, Vector2.zero
	local selectedNodeIdx = nil
	local draggingConnection = nil
	local marqueeSelecting, marqueeStart, marqueeEnd = false, nil, nil
	local selectedConnectionIdx = nil
	local lastMoveBlocked = false

	--------------------------------------------------------------------------------
	-- Redraw/Render Functions
	--------------------------------------------------------------------------------

	local function drawGrid()
		local gridLayer = canvas:FindFirstChild("GridLayer")
		if gridLayer then gridLayer:Destroy() end
		gridLayer = Instance.new("Frame")
		gridLayer.Name = "GridLayer"
		gridLayer.BackgroundTransparency = 1
		gridLayer.Size = UDim2.new(1,0,1,0)
		gridLayer.Position = UDim2.new(0,0,0,0)
		gridLayer.ZIndex = 0
		gridLayer.Parent = canvas
		local gridImage = Instance.new("ImageLabel")
		gridImage.Name = "GridTexture"
		gridImage.Image = "rbxassetid://6372755229"
		gridImage.BackgroundTransparency = 0.9
		gridImage.Size = UDim2.new(1,0,1,0)
		gridImage.Position = UDim2.new(0,0,0,0)
		gridImage.ZIndex = 0
		gridImage.ScaleType = Enum.ScaleType.Tile
		gridImage.TileSize = UDim2.new(0, 64, 0, 64)
		gridImage.Parent = gridLayer
	end

	local function drawConnections()
		connLayer:ClearAllChildren()
		for idx, conn in ipairs(NodeGraph.connections) do
			local fromNode, toNode = NodeGraph.nodes[conn.from], NodeGraph.nodes[conn.to]
			-- Defensive: port index check
			if fromNode and toNode and conn.fromPort and conn.toPort then
				local fromDef = NodeTypes.Definitions and NodeTypes.Definitions[fromNode.type]
				local toDef = NodeTypes.Definitions and NodeTypes.Definitions[toNode.type]
				local fromOuts = fromDef and fromDef.outputs or {}
				local toIns = toDef and toDef.inputs or {}
				if fromOuts[conn.fromPort] and toIns[conn.toPort] then
					local fromPos = toVector2(fromNode.pos) * zoom + offset + Vector2.new(fromNode.size and fromNode.size.X or 160,36 + ((conn.fromPort or 1)-1)*24) * zoom
					local toPos = toVector2(toNode.pos) * zoom + offset + Vector2.new(0,36 + ((conn.toPort or 1)-1)*24) * zoom
					local line = Instance.new("Frame")
					line.AnchorPoint = Vector2.new(0.5,0.5)
					line.BackgroundColor3 = (selectedConnectionIdx == idx) and Color3.fromRGB(255,80,80) or Color3.fromRGB(200, 200, 255)
					line.BorderSizePixel = 0
					local len = (toPos-fromPos).Magnitude
					line.Size = UDim2.new(0, len, 0, math.max(2, zoom*2))
					line.Position = UDim2.new(0, (fromPos.X+toPos.X)/2, 0, (fromPos.Y+toPos.Y)/2)
					line.Rotation = math.deg(math.atan2(toPos.Y-fromPos.Y, toPos.X-fromPos.X))
					line.BackgroundTransparency = 0.15
					line.ZIndex = 0
					line.Parent = connLayer
				end
			end
		end
	end

	local function drawMarquee()
		for _, child in ipairs(canvas:GetChildren()) do
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
			rect.ZIndex = 200
			rect.Parent = canvas
		end
	end

	-- Actually select nodes in the marquee
	local function selectNodesInMarquee()
		local minX, maxX = math.min(marqueeStart.X, marqueeEnd.X), math.max(marqueeStart.X, marqueeEnd.X)
		local minY, maxY = math.min(marqueeStart.Y, marqueeEnd.Y), math.max(marqueeStart.Y, marqueeEnd.Y)
		self.selectedNodes = {}
		for idx, node in ipairs(NodeGraph.nodes) do
			local nodePos = toVector2(node.pos)
			local nodeSize = node.size or DEFAULT_NODE_SIZE
			local nodeMinX, nodeMaxX = nodePos.X, nodePos.X + nodeSize.X
			local nodeMinY, nodeMaxY = nodePos.Y, nodePos.Y + nodeSize.Y
			if nodeMaxX > minX and nodeMinX < maxX and nodeMaxY > minY and nodeMinY < maxY then
				table.insert(self.selectedNodes, idx)
			end
		end
	end

	local function redraw()
		for _, child in ipairs(WorkSpace:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "ConnectionLayer" then
				child:Destroy()
			end
		end
		for idx, node in ipairs(NodeGraph.nodes) do
			local def = NodeTypes.Definitions and NodeTypes.Definitions[node.type] or {}
			local categoryMap = NodeTypes.GetCategoryMap and NodeTypes.GetCategoryMap() or {}
			local nodeCategory = "Special"
			for cat, nodes in pairs(categoryMap) do
				if nodes[node.type] then nodeCategory = cat break end
			end
			local isDragging = (draggingNodeIdx == idx)
			local hasParametersShown = (selectedNodeIdx == idx and PropertyPanel and PropertyPanel.frame and PropertyPanel.frame.Visible)
			NodeFrame.new(
				WorkSpace,
				node,
				def,
				idx,
				NodeGraph,
				zoom,
				offset,
				function(event, input)
					if event == "select" then
						selectedNodeIdx = idx
						if PropertyPanel then PropertyPanel:Show(idx) end
					elseif event == "dragStart" then
						draggingNodeIdx = idx
					end
				end,
				selectedNodeIdx == idx,
				nodeCategory,
				isDragging,
				hasParametersShown
			)
		end
		drawConnections()
		WorkSpace.Size = UDim2.new(zoom,0,zoom,0)
		WorkSpace.Position = UDim2.new(0, offset.X, 0, offset.Y)
		drawGrid()
		drawMarquee()
	end

	-- Defensive: ensure _hookRedraw is set on NodeGraph instance
	if NodeGraph and type(NodeGraph) == "table" and not rawget(NodeGraph, "_hookRedraw") then
		NodeGraph._hookRedraw = redraw
	end

	NodeGraph.OnSelectPathNode = function(pathNode)
		if _G.Show3DKeypointEditor then
			_G.Show3DKeypointEditor(pathNode)
		else
			warn("[NodeCanvas] _G.Show3DKeypointEditor not found when selecting path node.")
		end
	end

	--------------------------------------------------------------------------------
	-- Input Handling
	--------------------------------------------------------------------------------

	local function getMouseCanvasPos()
		local mouse = UIS:GetMouseLocation()
		return Vector2.new(mouse.X, mouse.Y) - canvas.AbsolutePosition
	end

	local function inputBegan(input)
		local mousePos = (input.Position and typeof(input.Position) == "Vector3")
			and Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
			or getMouseCanvasPos()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Marquee selection start
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) then
				marqueeSelecting = true
				marqueeStart = (mousePos - offset) / zoom
				marqueeEnd = marqueeStart
				drawMarquee()
			else
				for idx, node in ipairs(NodeGraph.nodes) do
					local nodePos = toVector2(node.pos) * zoom + offset
					local nodeSize = node.size or DEFAULT_NODE_SIZE
					local nodeRectMin = nodePos
					local nodeRectMax = nodePos + nodeSize * zoom
					if mousePos.X >= nodeRectMin.X and mousePos.X <= nodeRectMax.X and mousePos.Y >= nodeRectMin.Y and mousePos.Y <= nodeRectMax.Y then
						draggingNodeIdx = idx
						dragStart = mousePos
						dragOffset = toVector2(node.pos) * zoom + offset
						break
					end
				end
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			panning = true
			panStart = mousePos
			panOffsetStart = offset
		end
	end

	local function inputChanged(input)
		local mousePos = (input.Position and typeof(input.Position) == "Vector3")
			and Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
			or getMouseCanvasPos()
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local worldBefore = (mousePos - offset) / zoom
			zoom = math.clamp(zoom + (input.Position.Z > 0 and 0.1 or -0.1), minZoom, maxZoom)
			local worldAfter = (mousePos - offset) / zoom
			offset = offset + (worldAfter - worldBefore) * zoom
			if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
			canvas:SetAttribute("OffsetX", offset.X)
			canvas:SetAttribute("OffsetY", offset.Y)
			canvas:SetAttribute("Zoom", zoom)
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if draggingNodeIdx and dragStart and dragOffset then
				local delta = mousePos - dragStart
				local node = NodeGraph.nodes[draggingNodeIdx]
				local nodeSize = node and (node.size or DEFAULT_NODE_SIZE) or DEFAULT_NODE_SIZE
				if node then
					local newPos = (dragOffset + delta - offset) / zoom
					if not wouldCollide(NodeGraph, draggingNodeIdx, newPos, nodeSize) then
						node.pos = toUDim2(newPos)
						lastMoveBlocked = false
						if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
					else
						-- Visual feedback: flash border or some other indicator
						if not lastMoveBlocked then
							lastMoveBlocked = true
							canvas.BackgroundColor3 = Color3.fromRGB(75, 0, 0)
							task.delay(0.15, function()
								-- restore color
								canvas.BackgroundColor3 = Color3.fromRGB(28,28,40)
							end)
						end
					end
				end
			end
			if panning and panStart then
				local delta = mousePos - panStart
				offset = panOffsetStart + delta
				if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
				canvas:SetAttribute("OffsetX", offset.X)
				canvas:SetAttribute("OffsetY", offset.Y)
				canvas:SetAttribute("Zoom", zoom)
			end
			if marqueeSelecting and marqueeStart then
				marqueeEnd = (mousePos - offset) / zoom
				drawMarquee()
			end
		end
	end

	local function inputEnded(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			draggingNodeIdx = nil
			dragStart = nil
			dragOffset = nil
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			panning = false
			if marqueeSelecting then
				marqueeSelecting = false
				selectNodesInMarquee()
				drawMarquee()
			end
		end
		if draggingConnection then
			if draggingConnection.line then draggingConnection.line:Destroy() end
			draggingConnection = nil
		end
	end

	-- Connect and track for cleanup
	table.insert(connections, canvas.InputBegan:Connect(inputBegan))
	table.insert(connections, canvas.InputChanged:Connect(inputChanged))
	table.insert(connections, canvas.InputEnded:Connect(inputEnded))

	--------------------------------------------------------------------------------
	-- Node/Connection Management API
	--------------------------------------------------------------------------------

	function self.AddNode(nodeType, params, size)
		local pos = findFreePosition(NodeGraph)
		local node = {
			type = nodeType,
			params = params or {},
			pos = toUDim2(pos),
			size = size or DEFAULT_NODE_SIZE,
		}
		table.insert(NodeGraph.nodes, node)
		if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
		return node
	end

	function self.Redraw()
		redraw()
	end

	-- Expose selection
	self.selectedNodes = {}

	-- Redraw on NodeGraph change
	NodeGraph.GetConnections = function()
		return NodeGraph.connections
	end

	NodeGraph.SetConnections = function(conns)
		NodeGraph.connections = conns
		if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
	end

	--------------------------------------------------------------------------------
	-- Cleanup
	--------------------------------------------------------------------------------

	function self:Destroy()
		-- Disconnect input events
		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		connections = {}
		-- Remove UI
		if canvas then
			canvas:Destroy()
			canvas = nil
		end
		if WorkSpace then
			WorkSpace:Destroy()
			WorkSpace = nil
		end
		if connLayer then
			connLayer:Destroy()
			connLayer = nil
		end
	end

	return self
end

return NodeCanvas