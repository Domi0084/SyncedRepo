local TopBar = {}
TopBar.__index = TopBar

function TopBar.new(widget, NodeGraph, NodeTypes, Playback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1,0,0,36)
	frame.BackgroundColor3 = Color3.fromRGB(38,38,60)
	frame.Parent = widget

	-- Mode switching buttons
	local BtnGeneralEditor = Instance.new("TextButton")
	BtnGeneralEditor.Position = UDim2.new(0, 10, 0, 4)
	BtnGeneralEditor.Size = UDim2.new(0, 120, 0, 28)
	BtnGeneralEditor.Text = "General Editor"
	BtnGeneralEditor.Font = Enum.Font.GothamBold
	BtnGeneralEditor.TextSize = 16
	BtnGeneralEditor.BackgroundColor3 = Color3.fromRGB(80,120,200)
	BtnGeneralEditor.TextColor3 = Color3.new(1,1,1)
	BtnGeneralEditor.Parent = frame

	local BtnPathEditor = Instance.new("TextButton")
	BtnPathEditor.Position = UDim2.new(0, 140, 0, 4)
	BtnPathEditor.Size = UDim2.new(0, 120, 0, 28)
	BtnPathEditor.Text = "Path Editor"
	BtnPathEditor.Font = Enum.Font.GothamBold
	BtnPathEditor.TextSize = 16
	BtnPathEditor.BackgroundColor3 = Color3.fromRGB(120,80,200)
	BtnPathEditor.TextColor3 = Color3.new(1,1,1)
	BtnPathEditor.Parent = frame

	-- Choreography name input
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 270, 0, 4)
	nameLabel.Size = UDim2.new(0, 50, 0, 28)
	nameLabel.Text = "Name:"
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1,1,1)
	nameLabel.Parent = frame

	local nameInput = Instance.new("TextBox")
	nameInput.Position = UDim2.new(0, 330, 0, 4)
	nameInput.Size = UDim2.new(0, 150, 0, 28)
	nameInput.Text = NodeGraph:GetChoreographyName()
	nameInput.Font = Enum.Font.Gotham
	nameInput.TextSize = 14
	nameInput.BackgroundColor3 = Color3.fromRGB(60,60,80)
	nameInput.TextColor3 = Color3.new(1,1,1)
	nameInput.PlaceholderText = "Enter choreography name..."
	nameInput.Parent = frame

	nameInput.FocusLost:Connect(function()
		NodeGraph:SetChoreographyName(nameInput.Text)
	end)

	local BtnAddNode = Instance.new("TextButton")
	BtnAddNode.Position = UDim2.new(0, 490, 0, 4)
	BtnAddNode.Size = UDim2.new(0, 120, 0, 28)
	BtnAddNode.Text = "+ Add Node"
	BtnAddNode.Font = Enum.Font.GothamBold
	BtnAddNode.TextSize = 16
	BtnAddNode.BackgroundColor3 = Color3.fromRGB(58,100,200)
	BtnAddNode.TextColor3 = Color3.new(1,1,1)
	BtnAddNode.Parent = frame

	-- Scrollable dropdown for node type selection
	local menu = nil
	local menuOpen = false
	BtnAddNode.MouseButton1Click:Connect(function()
		if menu and menu.Parent then
			menu:Destroy()
			menu = nil
			menuOpen = false
			return
		end

		local optionHeight = 36
		local categoryHeaders = {"Input", "Transformation", "Appearance", "Logic", "Utility"}
		local categoryMap = NodeTypes.GetCategoryMap()
		local menuHeight = #categoryHeaders * optionHeight

		menu = Instance.new("Frame")
		menu.Size = UDim2.new(0,180,0,menuHeight)
		menu.Position = UDim2.new(0, BtnAddNode.AbsolutePosition.X - widget.AbsolutePosition.X, 0, BtnAddNode.AbsolutePosition.Y - widget.AbsolutePosition.Y + BtnAddNode.AbsoluteSize.Y)
		menu.BackgroundColor3 = Color3.fromRGB(28,28,40)
		menu.BorderSizePixel = 0
		menu.ZIndex = 50
		menu.Parent = widget
		menuOpen = true
		
		-- Ensure menu is destroyed when it's being removed
		menu.Destroying:Connect(function() 
			menu = nil
			menuOpen = false
		end)

		local UIS = game:GetService("UserInputService")
		local openSubmenu = nil
		for i, cat in ipairs(categoryHeaders) do
			local catBtn = Instance.new("TextButton")
			catBtn.Size = UDim2.new(1,0,0,optionHeight)
			catBtn.Position = UDim2.new(0,0,0,(i-1)*optionHeight)
			catBtn.Text = cat .. " Nodes >"
			catBtn.Font = Enum.Font.GothamBold
			catBtn.TextSize = 18
			catBtn.TextColor3 = Color3.fromRGB(200,200,255)
			catBtn.BackgroundTransparency = 0.1
			catBtn.BackgroundColor3 = Color3.fromRGB(38,38,60)
			catBtn.ZIndex = 52
			catBtn.Parent = menu

			catBtn.MouseEnter:Connect(function()
				if openSubmenu then openSubmenu:Destroy() openSubmenu = nil end
				local count = 0
				for key in pairs(categoryMap[cat]) do count = count + 1 end
				if count == 0 then return end
				local submenu = Instance.new("Frame")
				submenu.Size = UDim2.new(0,200,0,math.min(count,8)*optionHeight)
				submenu.Position = UDim2.new(0, menu.AbsolutePosition.X - widget.AbsolutePosition.X + menu.AbsoluteSize.X, 0, menu.AbsolutePosition.Y - widget.AbsolutePosition.Y + (i-1)*optionHeight)
				submenu.BackgroundColor3 = Color3.fromRGB(38,38,60)
				submenu.BorderSizePixel = 0
				submenu.ZIndex = 100
				submenu.Parent = widget
				local idx = 0
				for key, def in pairs(categoryMap[cat]) do
					if not def or type(def) ~= "table" then def = NodeTypes.Definitions[key] end
					if not def then continue end
					local opt = Instance.new("TextButton")
					opt.Size = UDim2.new(1,0,0,optionHeight)
					opt.Position = UDim2.new(0,0,0,idx*optionHeight)
					opt.Text = def.label or key
					opt.Font = Enum.Font.GothamBold
					opt.TextSize = 20
					opt.TextColor3 = Color3.new(1,1,1)
					opt.BackgroundColor3 = def.color or Color3.fromRGB(80,80,80)
					opt.BackgroundTransparency = 0.08
					opt.ZIndex = 101
					opt.Parent = submenu
					opt.AutoButtonColor = true
					opt.MouseEnter:Connect(function() if def.color then opt.BackgroundColor3 = def.color:lerp(Color3.new(1,1,1),0.15) end end)
					opt.MouseLeave:Connect(function() opt.BackgroundColor3 = def.color or Color3.fromRGB(80,80,80) end)
					opt.MouseButton1Click:Connect(function()
						-- Dodaj node w centrum widoku
						local canvas = widget:FindFirstChild("NodeCanvas")
						local offset, zoom = Vector2.new(0,0), 1
						if canvas and canvas:GetAttribute("OffsetX") and canvas:GetAttribute("OffsetY") and canvas:GetAttribute("Zoom") then
							offset = Vector2.new(canvas:GetAttribute("OffsetX"), canvas:GetAttribute("OffsetY"))
							zoom = canvas:GetAttribute("Zoom")
						end
						local center = Vector2.new(canvas.AbsoluteSize.X/2, canvas.AbsoluteSize.Y/2)
						local pos = (center - offset) / zoom
						NodeGraph:AddNode(key, {}, UDim2.new(0, pos.X, 0, pos.Y))
						if NodeGraph._hookRedraw then NodeGraph._hookRedraw() end
						if openSubmenu then openSubmenu:Destroy() openSubmenu = nil end
						menu:Destroy()
					end)
					idx = idx + 1
				end
				openSubmenu = submenu
			end)
			catBtn.MouseLeave:Connect(function()
				-- Submenu will be destroyed on next MouseEnter or menu close
			end)
		end

		-- Click outside to close menu
		local disconnect
		disconnect = UIS.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local mouse = UIS:GetMouseLocation()
				local clickInsideMenu = mouse.X > menu.AbsolutePosition.X and mouse.X < menu.AbsolutePosition.X + menu.AbsoluteSize.X
					and mouse.Y > menu.AbsolutePosition.Y and mouse.Y < menu.AbsolutePosition.Y + menu.AbsoluteSize.Y
				local clickInsideSubmenu = false
				if openSubmenu then
					clickInsideSubmenu = mouse.X > openSubmenu.AbsolutePosition.X and mouse.X < openSubmenu.AbsolutePosition.X + openSubmenu.AbsoluteSize.X
						and mouse.Y > openSubmenu.AbsolutePosition.Y and mouse.Y < openSubmenu.AbsolutePosition.Y + openSubmenu.AbsoluteSize.Y
				end
				
				-- Check if click is on the AddNode button itself
				local clickOnButton = mouse.X > BtnAddNode.AbsolutePosition.X and mouse.X < BtnAddNode.AbsolutePosition.X + BtnAddNode.AbsoluteSize.X
					and mouse.Y > BtnAddNode.AbsolutePosition.Y and mouse.Y < BtnAddNode.AbsolutePosition.Y + BtnAddNode.AbsoluteSize.Y
				
				if not (clickInsideMenu or clickInsideSubmenu or clickOnButton) then
					if openSubmenu then openSubmenu:Destroy() openSubmenu = nil end
					menu:Destroy()
					disconnect:Disconnect()
				end
			end
		end)
	end)

	local BtnPlay = Instance.new("TextButton")
	BtnPlay.Position = UDim2.new(1, -140, 0, 4)
	BtnPlay.Size = UDim2.new(0, 40, 0, 28)
	BtnPlay.AnchorPoint = Vector2.new(1, 0)
	BtnPlay.Text = "▶"
	BtnPlay.Font = Enum.Font.GothamBold
	BtnPlay.TextSize = 18
	BtnPlay.BackgroundColor3 = Color3.fromRGB(60,120,80)
	BtnPlay.TextColor3 = Color3.new(1,1,1)
	BtnPlay.Parent = frame

	local BtnStop = Instance.new("TextButton")
	BtnStop.Position = UDim2.new(1, -90, 0, 4)
	BtnStop.Size = UDim2.new(0, 40, 0, 28)
	BtnStop.AnchorPoint = Vector2.new(1, 0)
	BtnStop.Text = "■"
	BtnStop.Font = Enum.Font.GothamBold
	BtnStop.TextSize = 18
	BtnStop.BackgroundColor3 = Color3.fromRGB(180,60,60)
	BtnStop.TextColor3 = Color3.new(1,1,1)
	BtnStop.Parent = frame

	-- Undo Button
	local BtnUndo = Instance.new("TextButton")
	BtnUndo.Position = UDim2.new(0, 620, 0, 4)
	BtnUndo.Size = UDim2.new(0, 40, 0, 28)
	BtnUndo.Text = "⎌"
	BtnUndo.Font = Enum.Font.GothamBold
	BtnUndo.TextSize = 18
	BtnUndo.BackgroundColor3 = Color3.fromRGB(80,80,120)
	BtnUndo.TextColor3 = Color3.new(1,1,1)
	BtnUndo.Parent = frame

	-- Redo Button
	local BtnRedo = Instance.new("TextButton")
	BtnRedo.Position = UDim2.new(0, 670, 0, 4)
	BtnRedo.Size = UDim2.new(0, 40, 0, 28)
	BtnRedo.Text = "↻"
	BtnRedo.Font = Enum.Font.GothamBold
	BtnRedo.TextSize = 18
	BtnRedo.BackgroundColor3 = Color3.fromRGB(80,80,120)
	BtnRedo.TextColor3 = Color3.new(1,1,1)
	BtnRedo.Parent = frame

	-- Save Button
	local BtnSave = Instance.new("TextButton")
	BtnSave.Position = UDim2.new(0, 720, 0, 4)
	BtnSave.Size = UDim2.new(0, 60, 0, 28)
	BtnSave.Text = "Save"
	BtnSave.Font = Enum.Font.GothamBold
	BtnSave.TextSize = 16
	BtnSave.BackgroundColor3 = Color3.fromRGB(60,120,180)
	BtnSave.TextColor3 = Color3.new(1,1,1)
	BtnSave.Parent = frame

	-- Load Button
	local BtnLoad = Instance.new("TextButton")
	BtnLoad.Position = UDim2.new(0, 790, 0, 4)
	BtnLoad.Size = UDim2.new(0, 60, 0, 28)
	BtnLoad.Text = "Load"
	BtnLoad.Font = Enum.Font.GothamBold
	BtnLoad.TextSize = 16
	BtnLoad.BackgroundColor3 = Color3.fromRGB(60,120,180)
	BtnLoad.TextColor3 = Color3.new(1,1,1)
	BtnLoad.Parent = frame

	-- Export Button
	local BtnExport = Instance.new("TextButton")
	BtnExport.Position = UDim2.new(0, 860, 0, 4)
	BtnExport.Size = UDim2.new(0, 60, 0, 28)
	BtnExport.Text = "Export"
	BtnExport.Font = Enum.Font.GothamBold
	BtnExport.TextSize = 16
	BtnExport.BackgroundColor3 = Color3.fromRGB(120,80,180)
	BtnExport.TextColor3 = Color3.new(1,1,1)
	BtnExport.Parent = frame

	-- Export CSV Button
	local BtnExportCSV = Instance.new("TextButton")
	BtnExportCSV.Position = UDim2.new(0, 930, 0, 4)
	BtnExportCSV.Size = UDim2.new(0, 70, 0, 28)
	BtnExportCSV.Text = "CSV"
	BtnExportCSV.Font = Enum.Font.GothamBold
	BtnExportCSV.TextSize = 16
	BtnExportCSV.BackgroundColor3 = Color3.fromRGB(120,80,180)
	BtnExportCSV.TextColor3 = Color3.new(1,1,1)
	BtnExportCSV.Parent = frame

	-- Import Button
	local BtnImport = Instance.new("TextButton")
	BtnImport.Position = UDim2.new(0, 1010, 0, 4)
	BtnImport.Size = UDim2.new(0, 60, 0, 28)
	BtnImport.Text = "Import"
	BtnImport.Font = Enum.Font.GothamBold
	BtnImport.TextSize = 16
	BtnImport.BackgroundColor3 = Color3.fromRGB(120,80,180)
	BtnImport.TextColor3 = Color3.new(1,1,1)
	BtnImport.Parent = frame

	-- Quick Preview Button
	local BtnPreview = Instance.new("TextButton")
	BtnPreview.Position = UDim2.new(1, -190, 0, 4)
	BtnPreview.Size = UDim2.new(0, 40, 0, 28)
	BtnPreview.AnchorPoint = Vector2.new(1, 0)
	BtnPreview.Text = "👁"
	BtnPreview.Font = Enum.Font.GothamBold
	BtnPreview.TextSize = 18
	BtnPreview.BackgroundColor3 = Color3.fromRGB(80,180,180)
	BtnPreview.TextColor3 = Color3.new(1,1,1)
	BtnPreview.Parent = frame

	-- Mode switching click handlers
	BtnGeneralEditor.MouseButton1Click:Connect(function()
		if _G.SetMode then
			_G.SetMode("GeneralChoreographyEdit")
		end
		-- Update button appearance
		BtnGeneralEditor.BackgroundColor3 = Color3.fromRGB(80,120,200)
		BtnPathEditor.BackgroundColor3 = Color3.fromRGB(120,80,200)
	end)

	BtnPathEditor.MouseButton1Click:Connect(function()
		-- Check if there's a Path node available
		local hasPathNode = false
		for _, node in ipairs(NodeGraph.nodes) do
			if node.type == "Path" then
				hasPathNode = true
				break
			end
		end
		
		if not hasPathNode then
			-- Show warning that Path node is required
			warn("Path Editor requires a Path node to be available in the General Editor")
			return
		end
		
		if _G.SetMode then
			_G.SetMode("PathEdit")
		end
		-- Update button appearance
		BtnPathEditor.BackgroundColor3 = Color3.fromRGB(80,120,200)
		BtnGeneralEditor.BackgroundColor3 = Color3.fromRGB(120,80,200)
	end)

	BtnPlay.MouseButton1Click:Connect(function()
		Playback:Play(NodeGraph)
	end)
	BtnStop.MouseButton1Click:Connect(function()
		Playback:Stop()
	end)
	BtnUndo.MouseButton1Click:Connect(function()
		if NodeGraph.Undo then NodeGraph:Undo() end
	end)
	BtnRedo.MouseButton1Click:Connect(function()
		if NodeGraph.Redo then NodeGraph:Redo() end
	end)
	BtnSave.MouseButton1Click:Connect(function()
		if NodeGraph.SaveGraph then NodeGraph:SaveGraph() end
	end)
	BtnLoad.MouseButton1Click:Connect(function()
		if NodeGraph.LoadGraph then NodeGraph:LoadGraph() end
	end)
	BtnExport.MouseButton1Click:Connect(function()
		if NodeGraph.ExportGraph then NodeGraph:ExportGraph() end
	end)
	BtnExportCSV.MouseButton1Click:Connect(function()
		if NodeGraph.ExportGraphAsCSV then NodeGraph:ExportGraphAsCSV() end
	end)
	BtnImport.MouseButton1Click:Connect(function()
		if NodeGraph.ImportGraph then NodeGraph:ImportGraph() end
	end)
	BtnPreview.MouseButton1Click:Connect(function()
		if Playback.QuickPreview then Playback:QuickPreview(NodeGraph) end
	end)
end

return TopBar