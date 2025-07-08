-- ThreadClass.lua
-- Manages a single magic thread

local Signal = require(script.Parent.SignalClass)
local RunService = game:GetService("RunService")

local ThreadClass = {}
ThreadClass.__index = ThreadClass

-- Creates a new Thread instance
-- @param params ThreadParams
function ThreadClass.new(params)
    local self = setmetatable({}, ThreadClass)

    self.Params = params
    self.Path = nil
    self.Status = "Idle"
    self.Owner = nil
    self.Tags = {}

    -- Events
    self.OnStarted = Signal.new()
    self.OnComplete = Signal.new()
    self.OnTouched = Signal.new()
    self.OnDestroyed = Signal.new()

    return self
end

-- Begins moving along the assigned path
function ThreadClass:Move(path, moveParams, part)
    print("[ThreadClass:Move] called", self, path, moveParams, part)
    self.Path = path
    moveParams = moveParams or {}
    self.Status = "Moving"
    self.OnStarted:Fire(self)
    if not part then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local brush = ReplicatedStorage:FindFirstChild("Brush")
        if brush then
            part = brush:Clone()
            part.Parent = workspace
            print("[ThreadClass:Move] Cloned brush part", part)
            -- Set up trail color if present
            local threadFolder = part:FindFirstChild("Thread")
            if threadFolder then
                local trail = threadFolder:FindFirstChildWhichIsA("Trail")
                if trail and self.Params.color then
                    trail.Color = ColorSequence.new(self.Params.color)
                end
            end
            -- IMPROVED: Apply width scaling to brush and attachments
            self:_applyWidth(part, self.Params.width or 1)
        else
            part = Instance.new("Part")
            part.Anchored = true
            part.CanCollide = false
            part.Size = Vector3.new(self.Params.width or 1, self.Params.width or 1, self.Params.width or 1)
            part.Color = self.Params.color or Color3.fromRGB(200,200,255)
            part.Parent = workspace
            print("[ThreadClass:Move] Created fallback part", part)
        end
    end
    self._part = part
    self._moveT = 0
    local speed = moveParams.speed or self.Params.speed or 1
    local nextActionIdx = 1
    if self._moveConn then self._moveConn:Disconnect() end
    print("[ThreadClass:Move] Starting Heartbeat connection, speed:", speed)
    self._moveConn = RunService.Heartbeat:Connect(function(dt)
        if self.Status ~= "Moving" then return end
        self._moveT = math.min(self._moveT + dt * speed, 1)
        if self.Path and self.Path.GetPointAt then
            local pos = self.Path:GetPointAt(self._moveT)
            -- Face the part toward the direction of movement
            if self._lastPos then
                local dir = (pos - self._lastPos)
                if dir.Magnitude > 0.001 then
                    part.CFrame = CFrame.new(pos, pos + dir)
                else
                    part.CFrame = CFrame.new(pos)
                end
            else
                part.CFrame = CFrame.new(pos)
            end
            self._lastPos = pos
            print("[ThreadClass:Move] t=", self._moveT, "pos=", pos)
        else
            print("[ThreadClass:Move] No valid path or GetPointAt")
        end
        -- Check for action points (Type/Params) at each path point
        while nextActionIdx <= #self.Path.Points do
            local ap = self.Path.Points[nextActionIdx]
            local apT = (nextActionIdx-1)/(#self.Path.Points-1)
            if self._moveT >= apT then
                if ap.Type == "wrap" then
                    local pos = ap.Position
                    local params = ap.Params or {}
                    print("[ThreadClass:Move] ActionPoint: wrap at", pos, params)
                    self:_doWrap(pos, params)
                end
                nextActionIdx = nextActionIdx + 1
            else
                break
            end
        end
        if self._moveT >= 1 then
            self.Status = "Complete"
            self.OnComplete:Fire(self)
            print("[ThreadClass:Move] Complete, disconnecting Heartbeat")
            if self._moveConn then self._moveConn:Disconnect() self._moveConn = nil end
        end
    end)
end

function ThreadClass:_doWrap(targetPos, params)
    -- params: radius, turns, height, duration
    local part = self._part
    if not part then return end
    local duration = params.duration or 2
    local turns = params.turns or 2
    local radius = params.radius or 5
    local height = params.height or 5
    local t = 0
    if self._wrapConn then self._wrapConn:Disconnect() end
    self._wrapConn = RunService.Heartbeat:Connect(function(dt)
        t = math.min(t + dt, duration)
        local alpha = t/duration
        local angle = alpha * turns * math.pi * 2
        local x = math.cos(angle) * radius
        local y = alpha * height
        local z = math.sin(angle) * radius
        part.CFrame = CFrame.new(targetPos + Vector3.new(x, y, z))
        if t >= duration then
            if self._wrapConn then self._wrapConn:Disconnect() self._wrapConn = nil end
        end
    end)
end

-- IMPROVED: Apply width scaling to brush part and position attachments
function ThreadClass:_applyWidth(part, width)
    width = width or 1
    
    -- Scale the main part
    if part.Size then
        local originalSize = part.Size
        part.Size = Vector3.new(width, width, width)
    end
    
    -- Find and position attachments based on width
    local function updateAttachments(obj)
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("Attachment") then
                local name = child.Name:lower()
                if name:find("top") then
                    -- Top attachment: half of part's size up
                    child.Position = Vector3.new(0, width * 0.5, 0)
                    print("[ThreadClass:_applyWidth] Updated top attachment", child.Name, "to position", child.Position)
                elseif name:find("bottom") then
                    -- Bottom attachment: half of part's size down
                    child.Position = Vector3.new(0, -width * 0.5, 0)
                    print("[ThreadClass:_applyWidth] Updated bottom attachment", child.Name, "to position", child.Position)
                end
            elseif child:IsA("Folder") or child:IsA("Model") then
                -- Recursively check folders and models for attachments
                updateAttachments(child)
            end
        end
    end
    
    updateAttachments(part)
    print("[ThreadClass:_applyWidth] Applied width", width, "to brush part", part.Name)
end

-- Pauses the thread movement
function ThreadClass:Pause()
    self.Status = "Idle"
end

function ThreadClass:Tween(params, duration)
    duration = duration or 1
    local part = self._part
    if not part then return end
    local startColor = part.Color
    local startSize = part.Size
    local endColor = params.color or startColor
    local endWidth = params.width or startSize.X
    local t = 0
    if self._tweenConn then self._tweenConn:Disconnect() end
    self._tweenConn = RunService.Heartbeat:Connect(function(dt)
        t = math.min(t + dt, duration)
        local alpha = t/duration
        if params.color then
            part.Color = startColor:Lerp(endColor, alpha)
        end
        if params.width then
            local currentWidth = startSize.X + (endWidth - startSize.X) * alpha
            part.Size = Vector3.new(currentWidth, currentWidth, currentWidth)
            -- IMPROVED: Update attachment positions during width animation
            self:_applyWidth(part, currentWidth)
        end
        if t >= duration then
            if self._tweenConn then self._tweenConn:Disconnect() self._tweenConn = nil end
        end
    end)
end

-- Destroys the thread and cleans up events
function ThreadClass:Destroy()
    self.Status = "Destroyed"
    self.OnDestroyed:Fire(self)
    self.OnStarted:Destroy()
    self.OnComplete:Destroy()
    self.OnTouched:Destroy()
    self.OnDestroyed:Destroy()
    self.OnStarted = nil
    self.OnComplete = nil
    self.OnTouched = nil
    self.OnDestroyed = nil
end

-- Validates thread parameters
function ThreadClass:Validate()
    if self.Params and self.Params.Validate then
        self.Params:Validate()
    end
    return true
end

return ThreadClass
