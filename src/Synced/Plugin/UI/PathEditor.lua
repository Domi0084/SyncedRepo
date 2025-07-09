-- PathEditor.lua
-- 3D keypoint editor for PathNodes using a ViewportFrame
-- Also supports actionPointNodes for path actions

local PathEditor = {}
PathEditor.__index = PathEditor

local UserInputService = game:GetService("UserInputService")

-- ActionPoint Node types that can be placed in PathEditor
local ActionPointTypes = {
    Wait = { label = "Wait", color = Color3.fromRGB(160,160,160), params = {"duration"} },
    SetSpeed = { label = "Set Speed", color = Color3.fromRGB(255,210,90), params = {"speed"} },
    PlaySound = { label = "Play Sound", color = Color3.fromRGB(200,120,255), params = {"soundId"} },
    TriggerEvent = { label = "Trigger Event", color = Color3.fromRGB(120,255,120), params = {"eventName"} }
}

-- Creates a new PathEditor UI inside the given parent (e.g., plugin widget)
function PathEditor.new(parent, keypoints, onConfirm, onCancel)
    local self = setmetatable({}, PathEditor)
    self.keypoints = keypoints or {Vector3.new(0,0,0), Vector3.new(10,0,0)}
    self.actionPoints = {} -- Store action points
    self.onConfirm = onConfirm
    self.onCancel = onCancel

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

    -- Action point handles (smaller, different colored)
    self.actionHandles = {}
    
    -- Current selected action point type for placement
    self.selectedActionType = "Wait"

    -- Drag logic for handles
    local dragging = nil
    local dragType = nil -- "keypoint" or "actionpoint"
    local dragOffset = Vector3.new()
    local function screenToWorld(x, y)
        local ray = camera:ScreenPointToRay(x, y)
        local planeY = 0
        local t = (planeY - ray.Origin.Y) / ray.Direction.Y
        return ray.Origin + ray.Direction * t
    end
    
    viewport.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = input.Position
            dragging = nil
            dragType = nil
            
            -- Check keypoint handles first
            for i, part in ipairs(self.handles) do
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
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
                    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude < 16 then
                        dragging = i
                        dragType = "actionpoint"
                        dragOffset = part.Position - screenToWorld(mousePos.X, mousePos.Y)
                        break
                    end
                end
            end
            
            -- If no handle was clicked, place a new action point
            if not dragging then
                local worldPos = screenToWorld(mousePos.X, mousePos.Y)
                self:AddActionPoint(self.selectedActionType, worldPos)
            end
        end
    end)
    
    viewport.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = nil
            dragType = nil
        end
    end)
    
    viewport.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = input.Position
            local newPos = screenToWorld(mousePos.X, mousePos.Y) + dragOffset
            
            if dragType == "keypoint" then
                self.handles[dragging].Position = newPos
            elseif dragType == "actionpoint" then
                self.actionHandles[dragging].Position = newPos
                self.actionPoints[dragging].position = newPos
            end
        end
    end)

    -- Action Point Type Selector
    local actionTypeFrame = Instance.new("Frame")
    actionTypeFrame.Size = UDim2.new(0, 200, 0, 100)
    actionTypeFrame.Position = UDim2.new(1, -220, 0, 10)
    actionTypeFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    actionTypeFrame.BorderSizePixel = 0
    actionTypeFrame.Parent = viewport
    
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
        btn.Size = UDim2.new(1, -10, 0, 18)
        btn.Position = UDim2.new(0, 5, 0, yPos)
        btn.Text = def.label
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
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
        
        yPos = yPos + 20
    end

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
    confirmBtn.Parent = viewport
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
    cancelBtn.Parent = viewport
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
    addBtn.Parent = viewport
    addBtn.MouseButton1Click:Connect(function()
        local last = (#self.handles > 0 and self.handles[#self.handles].Position) or Vector3.new(0,0,0)
        local newPart = Instance.new("Part")
        newPart.Size = Vector3.new(0.6,0.6,0.6)
        newPart.Position = last + Vector3.new(3,0,0)
        newPart.Anchored = true
        newPart.Color = Color3.fromRGB(200,200,255)
        newPart.Parent = viewport
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
    removeBtn.Parent = viewport
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
    clearActionsBtn.Parent = viewport
    clearActionsBtn.MouseButton1Click:Connect(function()
        self:ClearActionPoints()
    end)

    return self
end

-- Add an action point at the specified position
function PathEditor:AddActionPoint(actionType, position)
    local actionDef = ActionPointTypes[actionType]
    if not actionDef then return end
    
    local actionPoint = {
        type = actionType,
        position = position,
        params = {}
    }
    
    -- Create visual handle
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
    
    table.insert(self.actionPoints, actionPoint)
    table.insert(self.actionHandles, part)
end

-- Clear all action points
function PathEditor:ClearActionPoints()
    for _, handle in ipairs(self.actionHandles) do
        handle:Destroy()
    end
    self.actionHandles = {}
    self.actionPoints = {}
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

function PathEditor:Destroy()
    if self.viewport then self.viewport:Destroy() end
end

return PathEditor
