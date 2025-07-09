-- PathEditor.lua
-- 3D keypoint editor for PathNodes using a ViewportFrame
-- Enhanced to support actual nodes with 3D representations and Wrap/Tween connections

local PathEditor = {}
PathEditor.__index = PathEditor

local UserInputService = game:GetService("UserInputService")

-- Import NodeTypes for compatibility
local NodeTypes = require(script.Parent.Parent.Core.NodeTypes)

-- ActionPoint Node types that can be placed in PathEditor
local ActionPointTypes = {
    Wait = { label = "Wait", color = Color3.fromRGB(160,160,160), params = {"duration"}, outputs = {"actionPoint"} },
    SetSpeed = { label = "Set Speed", color = Color3.fromRGB(255,210,90), params = {"speed"}, outputs = {"actionPoint"} },
    PlaySound = { label = "Play Sound", color = Color3.fromRGB(200,120,255), params = {"soundId"}, outputs = {"actionPoint"} },
    TriggerEvent = { label = "Trigger Event", color = Color3.fromRGB(120,255,120), params = {"eventName"}, outputs = {"actionPoint"} },
    -- Add Wrap and Tween as connectable action nodes
    Wrap = { label = "Wrap Action", color = Color3.fromRGB(80,255,180), params = {"radius","spiralTurns","height","offset"}, inputs = {"actionPoint"}, outputs = {"actionPoint"} },
    Tween = { label = "Tween Action", color = Color3.fromRGB(240,220,128), params = {"targetParams","duration"}, inputs = {"actionPoint"}, outputs = {"actionPoint"} }
}

-- Creates a new PathEditor UI inside the given parent (e.g., plugin widget)
function PathEditor.new(parent, keypoints, onConfirm, onCancel)
    local self = setmetatable({}, PathEditor)
    self.keypoints = keypoints or {Vector3.new(0,0,0), Vector3.new(10,0,0)}
    self.actionPoints = {} -- Store action points as nodes
    self.actionConnections = {} -- Store connections between action points
    self.onConfirm = onConfirm
    self.onCancel = onCancel
    self.selectedActionType = "Wait"
    self.selectedNode = nil

    -- ViewportFrame for 3D editing
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1,0,1,0)
    viewport.BackgroundColor3 = Color3.fromRGB(20,20,30)
    viewport.Parent = parent
    self.viewport = viewport

    -- Camera setup
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.new(Vector3.new(0,10,30), Vector3.new(0,0,0))
    viewport.CurrentCamera = camera
    self.camera = camera

    -- Keypoint handles (Parts)
    self.handles = {}
    for i, pos in ipairs(self.keypoints) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.6,0.6,0.6)
        part.Position = pos
        part.Anchored = true
        part.Color = Color3.fromRGB(200,200,255)
        part.Parent = viewport
        self.handles[i] = part
    end

    -- Action point handles (smaller, different colored with node representation)
    self.actionHandles = {}
    self.actionNodeFrames = {} -- UI representations of action nodes
    
    -- Node-based interaction system
    self:SetupNodeInteraction()
    
    -- Create UI panels
    self:CreateActionTypeSelector()
    self:CreateNodeConnectionPanel()
    self:CreateControlButtons()

    return self
end

-- Setup node interaction system for 3D viewport
function PathEditor:SetupNodeInteraction()
    local dragging = nil
    local dragType = nil -- "keypoint" or "actionpoint"
    local dragOffset = Vector3.new()
    local connectingFrom = nil -- For creating connections between action nodes
    
    local function screenToWorld(x, y)
        local ray = self.camera:ScreenPointToRay(x, y)
        local planeY = 0
        local t = (planeY - ray.Origin.Y) / ray.Direction.Y
        return ray.Origin + ray.Direction * t
    end
    
    self.viewport.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = input.Position
            dragging = nil
            dragType = nil
            
            -- Check keypoint handles first
            for i, part in ipairs(self.handles) do
                local screenPos, onScreen = self.camera:WorldToViewportPoint(part.Position)
                if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude < 16 then
                    dragging = i
                    dragType = "keypoint"
                    dragOffset = part.Position - screenToWorld(mousePos.X, mousePos.Y)
                    break
                end
            end
            
            -- Check action point handles if no keypoint was clicked
            if not dragging then
                for i, part in ipairs(self.actionHandles) do
                    local screenPos, onScreen = self.camera:WorldToViewportPoint(part.Position)
                    if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude < 16 then
                        dragging = i
                        dragType = "actionpoint"
                        dragOffset = part.Position - screenToWorld(mousePos.X, mousePos.Y)
                        self.selectedNode = i
                        self:UpdateNodeSelection()
                        break
                    end
                end
            end
            
            -- If no handle was clicked, place a new action point
            if not dragging then
                local viewportPos = self.viewport.AbsolutePosition
                local viewportSize = self.viewport.AbsoluteSize
                local clickPos = Vector2.new(input.Position.X, input.Position.Y)
                local relativePos = clickPos - viewportPos
                
                -- Only place action point if click is in the main viewport area
                if relativePos.X > 0 and relativePos.X < viewportSize.X and 
                   relativePos.Y > 0 and relativePos.Y < viewportSize.Y - 150 then
                    local worldPos = screenToWorld(mousePos.X, mousePos.Y)
                    self:AddActionPointNode(self.selectedActionType, worldPos)
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            -- Right-click for connections
            local mousePos = input.Position
            for i, part in ipairs(self.actionHandles) do
                local screenPos, onScreen = self.camera:WorldToViewportPoint(part.Position)
                if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude < 16 then
                    if connectingFrom then
                        -- Create connection
                        if connectingFrom ~= i then
                            self:CreateActionConnection(connectingFrom, i)
                        end
                        connectingFrom = nil
                    else
                        -- Start connection
                        connectingFrom = i
                    end
                    break
                end
            end
        end
    end)
    
    self.viewport.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = nil
            dragType = nil
        end
    end)
    
    self.viewport.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = input.Position
            local newPos = screenToWorld(mousePos.X, mousePos.Y) + dragOffset
            
            if dragType == "keypoint" then
                self.handles[dragging].Position = newPos
            elseif dragType == "actionpoint" then
                self.actionHandles[dragging].Position = newPos
                self.actionPoints[dragging].position = newPos
                self:UpdateActionNodeUI(dragging)
            end
        end
    end)
end

-- Add an action point node at the specified position
function PathEditor:AddActionPointNode(actionType, position)
    local actionDef = ActionPointTypes[actionType]
    if not actionDef then return end
    
    local actionNode = {
        type = actionType,
        position = position,
        params = {},
        connections = {} -- Store connections to other action nodes
    }
    
    -- Create visual 3D handle
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.4, 0.4, 0.4)
    part.Position = position
    part.Anchored = true
    part.Color = actionDef.color
    part.Shape = Enum.PartType.Ball
    part.Parent = self.viewport
    
    -- Add label
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(0, 100, 0, 30)
    gui.StudsOffset = Vector3.new(0, 1, 0)
    gui.Parent = part
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = actionDef.label
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.new(1,1,1)
    label.BackgroundTransparency = 1
    label.Parent = gui
    
    -- Create 2D node representation
    local nodeFrame = self:CreateActionNodeFrame(actionNode, actionDef, #self.actionPoints + 1)
    
    table.insert(self.actionPoints, actionNode)
    table.insert(self.actionHandles, part)
    table.insert(self.actionNodeFrames, nodeFrame)
    
    return #self.actionPoints
end

-- Create 2D node frame for action point
function PathEditor:CreateActionNodeFrame(actionNode, actionDef, index)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 120, 0, 60)
    frame.Position = UDim2.new(0, 10 + ((index-1) % 6) * 130, 0, 10 + math.floor((index-1) / 6) * 70)
    frame.BackgroundColor3 = actionDef.color
    frame.BorderSizePixel = 0
    frame.Parent = self.viewport
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Text = actionDef.label
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Parent = frame
    
    -- Add input/output ports for connections
    if actionDef.inputs then
        for i, input in ipairs(actionDef.inputs) do
            local port = Instance.new("Frame")
            port.Size = UDim2.new(0, 8, 0, 8)
            port.Position = UDim2.new(0, -4, 0, 25 + (i-1)*12)
            port.BackgroundColor3 = Color3.fromRGB(60,60,60)
            port.BorderSizePixel = 0
            port.Parent = frame
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1,0)
            corner.Parent = port
        end
    end
    
    if actionDef.outputs then
        for i, output in ipairs(actionDef.outputs) do
            local port = Instance.new("Frame")
            port.Size = UDim2.new(0, 8, 0, 8)
            port.Position = UDim2.new(1, -4, 0, 25 + (i-1)*12)
            port.BackgroundColor3 = Color3.fromRGB(120,120,220)
            port.BorderSizePixel = 0
            port.Parent = frame
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1,0)
            corner.Parent = port
        end
    end
    
    return frame
end

-- Create action connection between two action nodes
function PathEditor:CreateActionConnection(fromIndex, toIndex)
    local fromNode = self.actionPoints[fromIndex]
    local toNode = self.actionPoints[toIndex]
    
    if not fromNode or not toNode then return end
    
    -- Validate connection using NodeTypes logic
    local fromDef = ActionPointTypes[fromNode.type]
    local toDef = ActionPointTypes[toNode.type]
    
    if fromDef.outputs and toDef.inputs then
        table.insert(self.actionConnections, {from = fromIndex, to = toIndex})
        print("Connected " .. fromNode.type .. " to " .. toNode.type)
        self:UpdateConnectionVisuals()
    else
        print("Cannot connect " .. fromNode.type .. " to " .. toNode.type)
    end
end

-- Update connection visuals
function PathEditor:UpdateConnectionVisuals()
    -- Clear existing connection lines
    for _, child in ipairs(self.viewport:GetChildren()) do
        if child.Name == "ConnectionLine" then
            child:Destroy()
        end
    end
    
    -- Draw new connection lines
    for _, conn in ipairs(self.actionConnections) do
        local fromPos = self.actionPoints[conn.from].position
        local toPos = self.actionPoints[conn.to].position
        
        -- Create a simple line part
        local line = Instance.new("Part")
        line.Name = "ConnectionLine"
        line.Size = Vector3.new(0.1, 0.1, (toPos - fromPos).Magnitude)
        line.Position = (fromPos + toPos) / 2
        line.Anchored = true
        line.Color = Color3.fromRGB(100, 200, 255)
        line.CFrame = CFrame.lookAt(line.Position, toPos)
        line.Parent = self.viewport
    end
end

-- Update action node UI position
function PathEditor:UpdateActionNodeUI(index)
    -- Update 2D node frame position based on 3D handle position
    local nodeFrame = self.actionNodeFrames[index]
    if nodeFrame then
        nodeFrame.Position = UDim2.new(0, 10 + ((index-1) % 6) * 130, 0, 10 + math.floor((index-1) / 6) * 70)
    end
end

-- Update node selection visual feedback
function PathEditor:UpdateNodeSelection()
    for i, frame in ipairs(self.actionNodeFrames) do
        if i == self.selectedNode then
            frame.BackgroundTransparency = 0
            -- Add selection border
            local border = frame:FindFirstChild("SelectionBorder")
            if not border then
                border = Instance.new("UIStroke")
                border.Name = "SelectionBorder"
                border.Color = Color3.fromRGB(255, 255, 0)
                border.Thickness = 2
                border.Parent = frame
            end
        else
            frame.BackgroundTransparency = 0.2
            local border = frame:FindFirstChild("SelectionBorder")
            if border then border:Destroy() end
        end
    end
end

-- Create action type selector UI
function PathEditor:CreateActionTypeSelector()
    local actionTypeFrame = Instance.new("Frame")
    actionTypeFrame.Size = UDim2.new(0, 200, 0, 120)
    actionTypeFrame.Position = UDim2.new(1, -220, 0, 10)
    actionTypeFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    actionTypeFrame.BorderSizePixel = 0
    actionTypeFrame.Parent = self.viewport
    
    local actionTypeLabel = Instance.new("TextLabel")
    actionTypeLabel.Size = UDim2.new(1, 0, 0, 20)
    actionTypeLabel.Text = "Action Point Type:"
    actionTypeLabel.Font = Enum.Font.GothamBold
    actionTypeLabel.TextSize = 14
    actionTypeLabel.TextColor3 = Color3.new(1,1,1)
    actionTypeLabel.BackgroundTransparency = 1
    actionTypeLabel.Parent = actionTypeFrame
    
    local yPos = 25
    for actionType, def in pairs(ActionPointTypes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 15)
        btn.Position = UDim2.new(0, 5, 0, yPos)
        btn.Text = def.label
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 10
        btn.BackgroundColor3 = def.color
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = actionTypeFrame
        
        btn.MouseButton1Click:Connect(function()
            self.selectedActionType = actionType
            -- Update button appearance to show selection
            for _, child in ipairs(actionTypeFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundTransparency = 0.3
                end
            end
            btn.BackgroundTransparency = 0
        end)
        
        if actionType == self.selectedActionType then
            btn.BackgroundTransparency = 0
        else
            btn.BackgroundTransparency = 0.3
        end
        
        yPos = yPos + 17
    end
end

-- Create node connection panel
function PathEditor:CreateNodeConnectionPanel()
    local connectionFrame = Instance.new("Frame")
    connectionFrame.Size = UDim2.new(0, 200, 0, 80)
    connectionFrame.Position = UDim2.new(1, -220, 0, 140)
    connectionFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    connectionFrame.BorderSizePixel = 0
    connectionFrame.Parent = self.viewport
    
    local connectionLabel = Instance.new("TextLabel")
    connectionLabel.Size = UDim2.new(1, 0, 0, 20)
    connectionLabel.Text = "Node Connections:"
    connectionLabel.Font = Enum.Font.GothamBold
    connectionLabel.TextSize = 14
    connectionLabel.TextColor3 = Color3.new(1,1,1)
    connectionLabel.BackgroundTransparency = 1
    connectionLabel.Parent = connectionFrame
    
    local instructionLabel = Instance.new("TextLabel")
    instructionLabel.Size = UDim2.new(1, 0, 0, 40)
    instructionLabel.Position = UDim2.new(0, 0, 0, 20)
    instructionLabel.Text = "Right-click nodes to connect\nWrap/Tween can connect to action points"
    instructionLabel.Font = Enum.Font.Gotham
    instructionLabel.TextSize = 10
    instructionLabel.TextColor3 = Color3.new(0.8,0.8,0.8)
    instructionLabel.BackgroundTransparency = 1
    instructionLabel.TextWrapped = true
    instructionLabel.Parent = connectionFrame
    
    local clearConnectionsBtn = Instance.new("TextButton")
    clearConnectionsBtn.Size = UDim2.new(1, -10, 0, 15)
    clearConnectionsBtn.Position = UDim2.new(0, 5, 0, 60)
    clearConnectionsBtn.Text = "Clear Connections"
    clearConnectionsBtn.Font = Enum.Font.Gotham
    clearConnectionsBtn.TextSize = 10
    clearConnectionsBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    clearConnectionsBtn.TextColor3 = Color3.new(1,1,1)
    clearConnectionsBtn.Parent = connectionFrame
    
    clearConnectionsBtn.MouseButton1Click:Connect(function()
        self.actionConnections = {}
        self:UpdateConnectionVisuals()
    end)
end

-- Create control buttons
function PathEditor:CreateControlButtons()
    -- UI Buttons: Add, Remove, Confirm, Cancel
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0,120,0,36)
    confirmBtn.Position = UDim2.new(1,-260,1,-46)
    confirmBtn.AnchorPoint = Vector2.new(0,1)
    confirmBtn.Text = "✔ Confirm"
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 20
    confirmBtn.BackgroundColor3 = Color3.fromRGB(80,200,120)
    confirmBtn.TextColor3 = Color3.new(1,1,1)
    confirmBtn.Parent = self.viewport
    confirmBtn.MouseButton1Click:Connect(function()
        if self.onConfirm then self.onConfirm(self:GetKeypoints()) end
    end)

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0,120,0,36)
    cancelBtn.Position = UDim2.new(1,-130,1,-46)
    cancelBtn.AnchorPoint = Vector2.new(0,1)
    cancelBtn.Text = "✖ Cancel"
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 20
    cancelBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
    cancelBtn.TextColor3 = Color3.new(1,1,1)
    cancelBtn.Parent = self.viewport
    cancelBtn.MouseButton1Click:Connect(function()
        if self.onCancel then self.onCancel() end
    end)

    local addBtn = Instance.new("TextButton")
    addBtn.Size = UDim2.new(0,120,0,36)
    addBtn.Position = UDim2.new(0,10,1,-46)
    addBtn.AnchorPoint = Vector2.new(0,1)
    addBtn.Text = "+ Add Keypoint"
    addBtn.Font = Enum.Font.GothamBold
    addBtn.TextSize = 20
    addBtn.BackgroundColor3 = Color3.fromRGB(80,120,200)
    addBtn.TextColor3 = Color3.new(1,1,1)
    addBtn.Parent = self.viewport
    addBtn.MouseButton1Click:Connect(function()
        local last = (#self.handles > 0 and self.handles[#self.handles].Position) or Vector3.new(0,0,0)
        local newPart = Instance.new("Part")
        newPart.Size = Vector3.new(0.6,0.6,0.6)
        newPart.Position = last + Vector3.new(3,0,0)
        newPart.Anchored = true
        newPart.Color = Color3.fromRGB(200,200,255)
        newPart.Parent = self.viewport
        table.insert(self.handles, newPart)
    end)

    local removeBtn = Instance.new("TextButton")
    removeBtn.Size = UDim2.new(0,120,0,36)
    removeBtn.Position = UDim2.new(0,140,1,-46)
    removeBtn.AnchorPoint = Vector2.new(0,1)
    removeBtn.Text = "- Remove Keypoint"
    removeBtn.Font = Enum.Font.GothamBold
    removeBtn.TextSize = 20
    removeBtn.BackgroundColor3 = Color3.fromRGB(120,80,200)
    removeBtn.TextColor3 = Color3.new(1,1,1)
    removeBtn.Parent = self.viewport
    removeBtn.MouseButton1Click:Connect(function()
        if #self.handles > 2 then
            self.handles[#self.handles]:Destroy()
            table.remove(self.handles)
        end
    end)

    local clearActionsBtn = Instance.new("TextButton")
    clearActionsBtn.Size = UDim2.new(0,120,0,36)
    clearActionsBtn.Position = UDim2.new(0,270,1,-46)
    clearActionsBtn.AnchorPoint = Vector2.new(0,1)
    clearActionsBtn.Text = "Clear Actions"
    clearActionsBtn.Font = Enum.Font.GothamBold
    clearActionsBtn.TextSize = 20
    clearActionsBtn.BackgroundColor3 = Color3.fromRGB(200,120,80)
    clearActionsBtn.TextColor3 = Color3.new(1,1,1)
    clearActionsBtn.Parent = self.viewport
    clearActionsBtn.MouseButton1Click:Connect(function()
        self:ClearActionPoints()
    end)
end

-- Clear all action points
function PathEditor:ClearActionPoints()
    for _, handle in ipairs(self.actionHandles) do
        handle:Destroy()
    end
    for _, frame in ipairs(self.actionNodeFrames) do
        frame:Destroy()
    end
    self.actionHandles = {}
    self.actionPoints = {}
    self.actionNodeFrames = {}
    self.actionConnections = {}
    self:UpdateConnectionVisuals()
end

function PathEditor:GetKeypoints()
    local points = {}
    for _, part in ipairs(self.handles) do
        table.insert(points, part.Position)
    end
    return points
end

function PathEditor:GetActionPoints()
    return self.actionPoints
end

function PathEditor:GetActionConnections()
    return self.actionConnections
end

function PathEditor:Destroy()
    if self.viewport then self.viewport:Destroy() end
end

return PathEditor
