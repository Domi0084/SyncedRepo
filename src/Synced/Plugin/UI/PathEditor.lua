-- PathEditor.lua
-- 3D keypoint editor for PathNodes using a ViewportFrame

local PathEditor = {}
PathEditor.__index = PathEditor

local UserInputService = game:GetService("UserInputService")

-- Creates a new PathEditor UI inside the given parent (e.g., plugin widget)
function PathEditor.new(parent, keypoints, onConfirm, onCancel)
    local self = setmetatable({}, PathEditor)
    self.keypoints = keypoints or {Vector3.new(0,0,0), Vector3.new(10,0,0)}
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

    -- Drag logic for handles
    local dragging = nil
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
            for i, part in ipairs(self.handles) do
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude < 16 then
                    dragging = i
                    dragOffset = part.Position - screenToWorld(mousePos.X, mousePos.Y)
                    break
                end
            end
        end
    end)
    viewport.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = nil
        end
    end)
    viewport.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = input.Position
            local newPos = screenToWorld(mousePos.X, mousePos.Y) + dragOffset
            self.handles[dragging].Position = newPos
        end
    end)

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

    return self
end

function PathEditor:GetKeypoints()
    local points = {}
    for _, part in ipairs(self.handles) do
        table.insert(points, part.Position)
    end
    return points
end

function PathEditor:Destroy()
    if self.viewport then self.viewport:Destroy() end
end

return PathEditor
