-- FULL FEATURED NodeCanvas: zoom, pan, connections, property panel, strict Vector3 safety

local NodeFrame = require(script.Parent.NodeFrame)

local NodeCanvas = {}
NodeCanvas.__index = NodeCanvas

-- Helper: always convert pos to UDim2 for storage
local function toUDim2(pos)
	if typeof(pos) == "Vector3" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "Vector2" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "UDim2" then
		return pos
	end
	return UDim2.new(0, 0, 0, 0)
end

-- Helper: always convert pos to Vector2 for math
local function toVector2(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "UDim2" then return Vector2.new(pos.X.Offset, pos.Y.Offset) end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	return Vector2.new(0,0)
end

-- Helper: strict conversion from Vector3/Vector2 to Vector2
local function toVector2Safe(pos)
	if typeof(pos) == "Vector2" then return pos end
	if typeof(pos) == "Vector3" then return Vector2.new(pos.X, pos.Y) end
	error("toVector2Safe: unsupported type " .. typeof(pos))
end

local UIS = game:GetService("UserInputService")

function NodeCanvas.new(widget, NodeGraph, NodeTypes, PropertyPanel)
	local canvas = Instance.new("Frame")
	canvas.Name = "NodeCanvas"
	canvas.Position = UDim2.new(0,0,0,36)
	canvas.Size = UDim2.new(1,0,1,-36)
	canvas.BackgroundColor3 = Color3.fromRGB(28,28,40)
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true
	canvas.Parent = widget

	-- WorkSpace for nodes/connections
	local WorkSpace = Instance.new("Frame")
	WorkSpace.BackgroundTransparency = 1
	WorkSpace.Size = UDim2.new(1,0,1,0)
	WorkSpace.Position = UDim2.new(0,0,0,0)
	WorkSpace.ClipsDescendants = false
	WorkSpace.Parent = canvas

	-- Drawing layer for connections
	local connLayer = Instance.new("Folder")
	connLayer.Name = "ConnectionLayer"
	connLayer.Parent = WorkSpace

	-- Pan/zoom state
	local offset = Vector2.new(0,0)
	local zoom = 1.0
	local minZoom, maxZoom = 0.3, 2.5

	local draggingNodeIdx = nil
	local dragStart, dragOffset = nil, nil

	local panning = false
	local panStart = Vector2.new()
	local panOffsetStart = Vector2.new()

	local selectedNodeIdx = nil

	-- Connection drag state
	local draggingConnection = nil -- {fromNode, fromPort, line}

	-- Draw connection preview while dragging
	canvas.InputChanged:Connect(function(input)
		if draggingConnection and input.UserInputType == Enum.UserInputType.MouseMovement then
			if draggingConnection.line then draggingConnection.line:Destroy() end
			local fromNode = NodeGraph.nodes[draggingConnection.fromNode]
			local def = NodeTypes[fromNode.type] or {}
			local pos2d = toVector2(fromNode.pos)
			local nodePos = pos2d * zoom + offset
			local portY = 36 + (draggingConnection.fromPort-1)*24 -- poprawka: porty wyjściowe
			local fromPos = nodePos + Vector2.new(160, portY) * zoom
			local mouseScreen = UIS:GetMouseLocation()
			local mousePos = Vector2.new(mouseScreen.X, mouseScreen.Y) - canvas.AbsolutePosition
			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0.5,0.5)
			line.BackgroundColor3 = Color3.fromRGB(120,120,220)
			line.BorderSizePixel = 0
			local len = (mousePos-fromPos).Magnitude
			line.Size = UDim2.new(0, len, 0, math.max(2,zoom*2))
			line.Position = UDim2.new(0, (fromPos.X+mousePos.X)/2, 0, (fromPos.Y+mousePos.Y)/2)
			local angle = math.atan2(mousePos.Y-fromPos.Y, mousePos.X-fromPos.X)
			line.Rotation = math.deg(angle)
			line.BackgroundTransparency = 0.15
			line.ZIndex = 100
			line.Parent = canvas
			draggingConnection.line = line
		end
	end)
	canvas.InputEnded:Connect(function(input)
		if draggingConnection then
			if draggingConnection.line then draggingConnection.line:Destroy() end
			draggingConnection = nil
		end
	end)

	-- Redraw connections
	local function drawConnections()
		connLayer:ClearAllChildren()
		for _, conn in ipairs(NodeGraph.connections) do
			local fromNode = NodeGraph.nodes[conn.from]
			local toNode = NodeGraph.nodes[conn.to]
			if fromNode and toNode then
				local fromPos = toVector2(fromNode.pos) * zoom + offset + Vector2.new(160,36 + ((conn.fromPort or 1)-1)*24) * zoom
				local toPos = toVector2(toNode.pos) * zoom + offset + Vector2.new(0,36 + ((conn.toPort or 1)-1)*24) * zoom
				local line = Instance.new("Frame")
				line.AnchorPoint = Vector2.new(0.5,0.5)
				line.BackgroundColor3 = Color3.fromRGB(200, 200, 255)
				line.BorderSizePixel = 0
				local len = (toPos-fromPos).Magnitude
				line.Size = UDim2.new(0, len, 0, math.max(2,zoom*2))
				line.Position = UDim2.new(0, (fromPos.X+toPos.X)/2, 0, (fromPos.Y+toPos.Y)/2)
				local angle = math.atan2(toPos.Y-fromPos.Y, toPos.X-fromPos.X)
				line.Rotation = math.deg(angle)
				line.BackgroundTransparency = 0.15
				line.ZIndex = 0
				line.Parent = connLayer
			end
		end
	end

	-- Redraw nodes/connections
	local function redraw()
		for _, child in ipairs(WorkSpace:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "ConnectionLayer" then
				child:Destroy()
			end
		end
		for idx, node in ipairs(NodeGraph.nodes) do
			local def = NodeTypes[node.type] or {}
			local nodeCategory = NodeTypes.InputNodes[node.type] and "Input" or 
				(NodeTypes.TransformationNodes[node.type] and "Transformation" or 
				(NodeTypes.AppearanceNodes[node.type] and "Appearance" or 
				(NodeTypes.LogicNodes[node.type] and "Logic" or 
				(NodeTypes.UtilityNodes[node.type] and "Utility" or "Special"))))
			local isDragging = (draggingNodeIdx == idx)
			local hasParametersShown = (selectedNodeIdx == idx and PropertyPanel and PropertyPanel.frame and PropertyPanel.frame.Visible)
			local frame = NodeFrame.new(
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
			-- Add port click handlers for connection creation
			for i, _ in ipairs(def.outputs or {}) do
				local port = frame:FindFirstChild("OutputPort"..i)
				if port then
					port.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							draggingConnection = {fromNode=idx, fromPort=i, line=nil}
						end
					end)
				end
			end
			for i, _ in ipairs(def.inputs or {}) do
				local port = frame:FindFirstChild("InputPort"..i)
				if port then
					port.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 and draggingConnection then
							-- Validate connection before creating it
							local fromNode = NodeGraph.nodes[draggingConnection.fromNode]
							local toNode = NodeGraph.nodes[idx]
							
							if fromNode and toNode and NodeTypes.IsConnectionValid(fromNode.type, draggingConnection.fromPort, toNode.type, i) then
								-- Create connection
								table.insert(NodeGraph.connections, {from=draggingConnection.fromNode, to=idx, fromPort=draggingConnection.fromPort, toPort=i})
								draggingConnection = nil
								if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
							else
								-- Invalid connection - show feedback
								print("Invalid connection: Cannot connect " .. (fromNode and fromNode.type or "Unknown") .. " to " .. (toNode and toNode.type or "Unknown"))
								draggingConnection = nil
							end
						end
					end)
				end
			end
		end
		drawConnections()
		WorkSpace.Size = UDim2.new(zoom,0,zoom,0)
		WorkSpace.Position = UDim2.new(0, offset.X, 0, offset.Y)
	end

	NodeGraph._hookRedraw = redraw
	NodeGraph.OnSelectPathNode = function(pathNode)
		if _G.Show3DKeypointEditor then
			_G.Show3DKeypointEditor(pathNode)
		end
	end

	-- Mouse wheel = zoom (centered on mouse position)
	canvas.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local mousePos = Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
			local worldBefore = (mousePos - offset) / zoom
			if input.Position.Z > 0 then
				zoom = math.clamp(zoom + 0.1, minZoom, maxZoom)
			else
				zoom = math.clamp(zoom - 0.1, minZoom, maxZoom)
			end
			local worldAfter = (mousePos - offset) / zoom
			offset = offset + (worldAfter - worldBefore) * zoom
			redraw()

			-- Ustaw atrybuty offset/zoom na canvasie, by TopBar mógł je odczytać
			canvas:SetAttribute("OffsetX", offset.X)
			canvas:SetAttribute("OffsetY", offset.Y)
			canvas:SetAttribute("Zoom", zoom)
		end
	end)

	-- Helper function to check if two rectangles collide
	local function checkCollision(pos1, size1, pos2, size2)
		return pos1.X < pos2.X + size2.X and
			   pos1.X + size1.X > pos2.X and
			   pos1.Y < pos2.Y + size2.Y and
			   pos1.Y + size1.Y > pos2.Y
	end

	-- Helper function to check if a new position would cause collision
	local function wouldCollide(draggedNodeIdx, newPos)
		local nodeSize = Vector2.new(160, 80) -- Standard node size
		local draggedPos = newPos
		
		for idx, node in ipairs(NodeGraph.nodes) do
			if idx ~= draggedNodeIdx then
				local otherPos = toVector2(node.pos)
				if checkCollision(draggedPos, nodeSize, otherPos, nodeSize) then
					return true
				end
			end
		end
		return false
	end

	-- Dragging nodes + panning
	canvas.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local mousePos = Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
			if draggingNodeIdx then
				dragStart = mousePos
				local node = NodeGraph.nodes[draggingNodeIdx]
				if node then
					dragOffset = toVector2(node.pos) * zoom + offset
				end
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			panning = true
			panStart = Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
			panOffsetStart = offset
		end
	end)
	canvas.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos = Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition
			if draggingNodeIdx and dragStart and dragOffset then
				local delta = mousePos - dragStart
				local node = NodeGraph.nodes[draggingNodeIdx]
				if node then
					local newPos = (dragOffset + delta - offset) / zoom
					
					-- Check for collision before updating position
					if not wouldCollide(draggingNodeIdx, newPos) then
						node.pos = toUDim2(newPos)
						if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
					end
				end
			end
			if panning and panStart then
				local delta = mousePos - panStart
				offset = panOffsetStart + delta
				if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end

				-- Po każdej zmianie offset/zoom (np. panning, zooming) też aktualizuj atrybuty
				canvas:SetAttribute("OffsetX", offset.X)
				canvas:SetAttribute("OffsetY", offset.Y)
				canvas:SetAttribute("Zoom", zoom)
			end
		end
	end)
	canvas.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			draggingNodeIdx = nil
			dragStart = nil
			dragOffset = nil
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			panning = false
		end
	end)

	redraw()

	return canvas
end

return NodeCanvas
