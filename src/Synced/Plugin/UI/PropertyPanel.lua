-- PropertyPanel: advanced, scrollable, editable property panel for node parameters

local PropertyPanel = {}
PropertyPanel.__index = PropertyPanel

function PropertyPanel.new(widget, NodeGraph, NodeTypes)
	local self = setmetatable({}, PropertyPanel)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 340)
	frame.Position = UDim2.new(1, -300, 0, 50)
	frame.BackgroundColor3 = Color3.fromRGB(32,32,48)
	frame.Visible = false
	frame.ZIndex = 100
	frame.Parent = widget
	self.frame = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1,0,0,32)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Text = "Node Parameters"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -10, 1, -42)
	scroll.Position = UDim2.new(0, 5, 0, 38)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 8
	scroll.Parent = frame
	self._scroll = scroll

	self._curIdx = nil
	self._NodeGraph = NodeGraph
	self._NodeTypes = NodeTypes

	return self
end

function PropertyPanel:Show(idx)
	self._curIdx = idx
	self.frame.Visible = true
	local scroll = self._scroll
	local NodeGraph = self._NodeGraph
	local NodeTypes = self._NodeTypes
	-- Clear
	for _, c in ipairs(scroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local node = NodeGraph.nodes[idx]
	local def = NodeTypes[node.type]
	if not def then return end
	local y = 0

	-- Known dropdown options
	local elementOptions = {"Air", "Water", "Fire", "Earth", "Spirit"}
	local colorOptions = {
		{"Blue", Color3.fromRGB(120,180,255)},
		{"Red", Color3.fromRGB(255,80,80)},
		{"Green", Color3.fromRGB(80,255,180)},
		{"Yellow", Color3.fromRGB(255,255,128)},
		{"White", Color3.fromRGB(255,255,255)},
		{"Purple", Color3.fromRGB(210,180,255)},
	}
	local modeOptions = {"Line", "Spiral", "Wave"}

	for _, paramName in ipairs(def.params or {}) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 120, 0, 26)
		label.Position = UDim2.new(0, 0, 0, y)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(220,220,220)
		label.Font = Enum.Font.Gotham
		label.TextSize = 16
		label.Text = paramName
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 102
		label.Parent = scroll

		local isDropdown = false
		local dropdownOptions = nil
		local isColor = false
		if paramName == "element" then
			isDropdown = true
			dropdownOptions = elementOptions
		elseif paramName == "color" then
			isDropdown = true
			isColor = true
			dropdownOptions = colorOptions
		elseif paramName == "Mode" then
			isDropdown = true
			dropdownOptions = modeOptions
		end

		if isDropdown then
			local curValue = node.params[paramName] or (isColor and colorOptions[1][2]) or dropdownOptions[1]
			local dropBtn = Instance.new("TextButton")
			dropBtn.Size = UDim2.new(0, 130, 0, 24)
			dropBtn.Position = UDim2.new(0, 130, 0, y)
			dropBtn.BackgroundColor3 = Color3.fromRGB(60,60,90)
			dropBtn.TextColor3 = Color3.new(1,1,1)
			dropBtn.Font = Enum.Font.Gotham
			dropBtn.TextSize = 16
			dropBtn.ZIndex = 102
			dropBtn.Parent = scroll
			dropBtn.Text = isColor and (function()
				for _, opt in ipairs(colorOptions) do
					if (typeof(node.params[paramName]) == "Color3" and node.params[paramName] == opt[2]) or node.params[paramName] == opt[1] then
						return opt[1]
					end
				end
				return colorOptions[1][1]
			end)() or tostring(node.params[paramName] or dropdownOptions[1])

			if isColor then
				local colorBox = Instance.new("Frame")
				colorBox.Size = UDim2.new(0, 18, 0, 18)
				colorBox.Position = UDim2.new(0, 240, 0, y+3)
				colorBox.BackgroundColor3 = node.params[paramName] or colorOptions[1][2]
				colorBox.BorderSizePixel = 0
				colorBox.ZIndex = 103
				colorBox.Parent = scroll
				dropBtn:GetPropertyChangedSignal("Text"):Connect(function()
					for _, opt in ipairs(colorOptions) do
						if dropBtn.Text == opt[1] then
							colorBox.BackgroundColor3 = opt[2]
						end
					end
				end)
			end

			local openMenu = nil
			dropBtn.MouseButton1Click:Connect(function()
				if openMenu and openMenu.Parent then
					openMenu:Destroy()
					openMenu = nil
					return
				end
				local menu = Instance.new("Frame")
				menu.Size = UDim2.new(0, 130, 0, #dropdownOptions*22)
				menu.Position = UDim2.new(0, dropBtn.AbsolutePosition.X - scroll.AbsolutePosition.X, 0, dropBtn.AbsolutePosition.Y - scroll.AbsolutePosition.Y + dropBtn.AbsoluteSize.Y)
				menu.BackgroundColor3 = Color3.fromRGB(40,40,60)
				menu.BorderSizePixel = 0
				menu.ZIndex = 200
				menu.Parent = scroll
				openMenu = menu
				for i, opt in ipairs(dropdownOptions) do
					local optBtn = Instance.new("TextButton")
					optBtn.Size = UDim2.new(1,0,0,22)
					optBtn.Position = UDim2.new(0,0,0,(i-1)*22)
					optBtn.Font = Enum.Font.Gotham
					optBtn.TextSize = 15
					optBtn.ZIndex = 201
					if isColor then
						optBtn.Text = opt[1]
						optBtn.BackgroundColor3 = opt[2]
						optBtn.TextColor3 = Color3.new(1,1,1)
					else
						optBtn.Text = tostring(opt)
						optBtn.BackgroundColor3 = Color3.fromRGB(60,60,90)
						optBtn.TextColor3 = Color3.new(1,1,1)
					end
					optBtn.Parent = menu
					optBtn.MouseButton1Click:Connect(function()
						if isColor then
							dropBtn.Text = opt[1]
							node.params[paramName] = opt[2]
						else
							dropBtn.Text = tostring(opt)
							node.params[paramName] = opt
						end
						menu:Destroy()
						openMenu = nil
					end)
				end
				-- Close menu if click outside
				local UIS = game:GetService("UserInputService")
				local disconnect
				disconnect = UIS.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						local mouse = UIS:GetMouseLocation()
						if not (mouse.X > menu.AbsolutePosition.X and mouse.X < menu.AbsolutePosition.X + menu.AbsoluteSize.X
							and mouse.Y > menu.AbsolutePosition.Y and mouse.Y < menu.AbsolutePosition.Y + menu.AbsoluteSize.Y) then
							menu:Destroy()
							openMenu = nil
							disconnect:Disconnect()
						end
					end
				end)
			end)
		else
			local box = Instance.new("TextBox")
			box.Size = UDim2.new(0, 130, 0, 24)
			box.Position = UDim2.new(0, 130, 0, y)
			box.BackgroundColor3 = Color3.fromRGB(60,60,90)
			box.TextColor3 = Color3.new(1,1,1)
			box.Font = Enum.Font.Gotham
			box.TextSize = 16
			box.PlaceholderText = "Value"
			box.Text = tostring(node.params[paramName] or "")
			box.ZIndex = 102
			box.Parent = scroll
			box.FocusLost:Connect(function()
				node.params[paramName] = box.Text
			end)
		end
		y = y + 34
	end
	-- Add Delete Node button at the bottom
	local delBtn = Instance.new("TextButton")
	delBtn.Size = UDim2.new(1, -20, 0, 32)
	delBtn.Position = UDim2.new(0, 10, 0, y + 10)
	delBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	delBtn.TextColor3 = Color3.new(1,1,1)
	delBtn.Font = Enum.Font.GothamBold
	delBtn.TextSize = 18
	delBtn.Text = "Delete Node"
	delBtn.ZIndex = 103
	delBtn.Parent = scroll
	delBtn.MouseButton1Click:Connect(function()
		if NodeGraph and NodeGraph.RemoveNode and self._curIdx then
			NodeGraph:RemoveNode(self._curIdx)
			self:Hide()
			if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
		end
	end)
	scroll.CanvasSize = UDim2.new(0,0,0,math.max(y+50, self.frame.AbsoluteSize.Y-10))
end

function PropertyPanel:Hide()
	self.frame.Visible = false
end

return PropertyPanel