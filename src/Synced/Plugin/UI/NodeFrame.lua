-- NodeFrame: draggable, selectable, robust Vector3 safety

local NodeFrame = {}
NodeFrame.__index = NodeFrame

local function toUDim2(pos)
	if typeof(pos) == "Vector3" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "Vector2" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "UDim2" then
		return pos
	end
	return UDim2.new(0, math.random(0,800), 0, math.random(0,400))
end

function NodeFrame.new(parent, node, def, idx, NodeGraph, zoom, offset, callback, isSelected, nodeCategory, isDragging, hasParametersShown)
	local z = zoom or 1
	local pos = node.pos or UDim2.new(0, math.random(0,800), 0, math.random(0,400))
	pos = toUDim2(pos)
	local x, y = pos.X.Offset, pos.Y.Offset

	local frame = Instance.new("Frame")
	local size = Vector2.new(160, 80) * z
	frame.Size = UDim2.new(0, size.X, 0, size.Y)
	frame.Position = UDim2.new(0, x * z, 0, y * z)
	frame.BackgroundColor3 = def.color or Color3.fromRGB(128,128,128)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 0.04
	frame.Name = node.type
	frame.ZIndex = isSelected and 3 or 2
	frame.Parent = parent
	frame.ClipsDescendants = false

	-- Node style by category
	if nodeCategory == "Builder" then
		frame.BackgroundColor3 = Color3.fromRGB(60, 80, 180)
	elseif nodeCategory == "Movement" then
		frame.BackgroundColor3 = Color3.fromRGB(80, 180, 120)
	elseif nodeCategory == "Utility" then
		frame.BackgroundColor3 = Color3.fromRGB(180, 120, 80)
	else
		frame.BackgroundColor3 = Color3.fromRGB(120, 80, 80)
	end
	local border = Instance.new("UIStroke")
	if isDragging then
		border.Thickness = 0
		border.Transparency = 1
	else
		-- Show border when parameters are displayed or when selected
		if hasParametersShown then
			border.Thickness = 3
			border.Color = Color3.fromRGB(255, 200, 100)
			border.Transparency = 0
		elseif isSelected then
			border.Thickness = 4
			border.Color = Color3.fromRGB(255,255,180)
			border.Transparency = 0
		else
			border.Thickness = 2
			border.Color = Color3.fromRGB(80,80,80)
			border.Transparency = 0
		end
	end
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32 * z)
	title.BackgroundTransparency = 0.15
	title.BackgroundColor3 = Color3.fromRGB(24,24,32)
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.TextStrokeTransparency = 0.2
	title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22 * z
	title.Text = def.label or node.type
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = frame

	-- Icon (optional, placeholder)
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 24, 0, 24)
	icon.Position = UDim2.new(0, 8, 0, 6)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://6031094678"
	icon.ImageColor3 = Color3.fromRGB(255,255,255)
	icon.Parent = frame

	-- Input/output ports
	for i, input in ipairs(def.inputs or {}) do
		local port = Instance.new("Frame")
		port.Size = UDim2.new(0, 16, 0, 16)
		port.Position = UDim2.new(0, -10, 0, 36 + (i-1)*24)
		port.BackgroundColor3 = Color3.fromRGB(60,60,60)
		port.BorderSizePixel = 0
		port.BackgroundTransparency = 0.1
		port.ZIndex = 4
		port.Name = "InputPort" .. i
		port.Parent = frame
		local portCircle = Instance.new("UICorner")
		portCircle.CornerRadius = UDim.new(1,0)
		portCircle.Parent = port
	end
	for i, output in ipairs(def.outputs or {}) do
		local port = Instance.new("Frame")
		port.Size = UDim2.new(0, 16, 0, 16)
		port.Position = UDim2.new(1, -10, 0, 36 + (i-1)*24)
		port.AnchorPoint = Vector2.new(1,0)
		port.BackgroundColor3 = Color3.fromRGB(120,120,220)
		port.BorderSizePixel = 0
		port.BackgroundTransparency = 0.1
		port.ZIndex = 4
		port.Name = "OutputPort" .. i
		port.Parent = frame
		local portCircle = Instance.new("UICorner")
		portCircle.CornerRadius = UDim.new(1,0)
		portCircle.Parent = port
	end

	-- Add collapse/expand button
	local collapseBtn = Instance.new("ImageButton")
	collapseBtn.Size = UDim2.new(0, 18, 0, 18)
	collapseBtn.Position = UDim2.new(1, -26, 0, 6)
	collapseBtn.BackgroundTransparency = 1
	collapseBtn.Image = "rbxassetid://6031090990"
	collapseBtn.ImageColor3 = Color3.fromRGB(200,200,200)
	collapseBtn.Parent = frame
	local collapsed = false
	collapseBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		for _, child in ipairs(frame:GetChildren()) do
			if child ~= title and child ~= icon and child ~= collapseBtn and not child:IsA("UIStroke") then
				child.Visible = not collapsed
			end
		end
	end)

	-- Add delete button
	local deleteBtn = Instance.new("ImageButton")
	deleteBtn.Size = UDim2.new(0, 18, 0, 18)
	deleteBtn.Position = UDim2.new(1, -48, 0, 6)
	deleteBtn.BackgroundTransparency = 1
	deleteBtn.Image = "rbxassetid://6031094678"
	deleteBtn.ImageColor3 = Color3.fromRGB(220,80,80)
	deleteBtn.Parent = frame
	deleteBtn.MouseButton1Click:Connect(function()
		if NodeGraph and NodeGraph.RemoveNode then
			NodeGraph:RemoveNode(idx)
			if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
		end
	end)

	-- Tooltip on hover
	frame.MouseEnter:Connect(function()
		title.TextColor3 = Color3.fromRGB(255,255,180)
	end)
	frame.MouseLeave:Connect(function()
		title.TextColor3 = Color3.fromRGB(255,255,255)
	end)

	-- Selection and drag start callback
	local lastClickTime = 0
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local currentTime = tick()
			if callback then
				callback("select", input)
			end
			if node.type == "Path" then
				-- Check for double-click (within 0.5 seconds)
				if lastClickTime > 0 and currentTime - lastClickTime < 0.5 then
					-- Double-click detected, open PathEditor
					if _G.SetMode then
						_G.SetMode("PathEdit")
					end
				else
					-- Single click, just select
					if NodeGraph.OnSelectPathNode then
						NodeGraph.OnSelectPathNode(node)
					end
				end
			end
			lastClickTime = currentTime
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			if callback then
				callback("dragStart", input)
			end
		end
	end)

	return frame
end

return NodeFrame