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
    -- IMPROVED: Arc-length parameterization for uniform movement speed
    self._pathLength = self:_calculatePathLength()
    -- IMPROVED: Pre-calculate arc-length parameters for action points (reuses path length calculation)
    self._actionPointParams = self:_calculateActionPointParameters(self._pathLength)
    self._distanceTraveled = 0
    local nextActionIdx = 1
    if self._moveConn then self._moveConn:Disconnect() end
    print("[ThreadClass:Move] Starting Heartbeat connection, speed:", speed)
    self._moveConn = RunService.Heartbeat:Connect(function(dt)
        if self.Status ~= "Moving" then return end
        
        -- IMPROVED: Arc-length based movement for uniform speed
        local moveDistance = dt * speed
        self._distanceTraveled = math.min(self._distanceTraveled + moveDistance, self._pathLength)
        self._moveT = self._pathLength > 0 and (self._distanceTraveled / self._pathLength) or 0
        
        if self.Path and self.Path.GetPointAt then
            local pos = self.Path:GetPointAt(self._moveT)
            -- IMPROVED: Better orientation calculation with lookahead
            if self._lastPos then
                local dir = (pos - self._lastPos)
                if dir.Magnitude > 0.001 then
                    -- Add slight lookahead for smoother orientation
                    local lookaheadT = math.min(self._moveT + 0.01, 1)
                    local lookaheadPos = self.Path:GetPointAt(lookaheadT)
                    local lookaheadDir = (lookaheadPos - pos)
                    if lookaheadDir.Magnitude > 0.001 then
                        part.CFrame = CFrame.new(pos, pos + lookaheadDir.Unit)
                    else
                        part.CFrame = CFrame.new(pos, pos + dir.Unit)
                    end
                else
                    part.CFrame = CFrame.new(pos)
                end
            else
                part.CFrame = CFrame.new(pos)
            end
            self._lastPos = pos
            print("[ThreadClass:Move] t=", self._moveT, "distance=", self._distanceTraveled, "pos=", pos)
        else
            print("[ThreadClass:Move] No valid path or GetPointAt")
        end
        -- IMPROVED: Check for action points with arc-length based parameters and tolerance
        while nextActionIdx <= #self.Path.Points do
            local ap = self.Path.Points[nextActionIdx]
            local apT = self._actionPointParams[nextActionIdx] or ((nextActionIdx-1)/(#self.Path.Points-1))
            local tolerance = 0.02 -- Tolerance for detecting action points (2% of path)
            
            -- Check if we're close enough to or have passed the action point
            if self._moveT >= (apT - tolerance) then
                if ap.Type == "wrap" then
                    local pos = ap.Position
                    local params = ap.Params or {}
                    print("[ThreadClass:Move] ActionPoint: wrap at", pos, params, "t=", apT, "current_t=", self._moveT)
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

-- IMPROVED: Calculate total path length for arc-length parameterization
function ThreadClass:_calculatePathLength()
    if not self.Path or not self.Path.GetPointAt then
        return 1 -- Default fallback
    end
    
    local totalLength = 0
    local samples = 100 -- Number of samples to estimate length
    local lastPos = self.Path:GetPointAt(0)
    
    for i = 1, samples do
        local t = i / samples
        local currentPos = self.Path:GetPointAt(t)
        local segmentLength = (currentPos - lastPos).Magnitude
        totalLength = totalLength + segmentLength
        lastPos = currentPos
    end
    
    print("[ThreadClass:_calculatePathLength] Calculated path length:", totalLength)
    return math.max(totalLength, 1) -- Ensure minimum length
end

-- IMPROVED: Calculate arc-length based parameter values for action points
function ThreadClass:_calculateActionPointParameters(preCalculatedPathLength)
    if not self.Path or not self.Path.Points or #self.Path.Points == 0 then
        return {}
    end
    
    local actionPointParams = {}
    local samples = 1000 -- High resolution for accuracy
    local totalLength = preCalculatedPathLength or 0
    
    -- Safety check for GetPointAt method
    if not self.Path.GetPointAt then
        print("[ThreadClass:_calculateActionPointParameters] Warning: Path missing GetPointAt method, using fallback")
        -- Fallback to uniform distribution
        for i = 1, #self.Path.Points do
            actionPointParams[i] = (i-1) / math.max(1, #self.Path.Points-1)
        end
        return actionPointParams
    end
    
    -- If path length wasn't pre-calculated, calculate it now
    local distanceMap = {0} -- Distance at each sample point
    if not preCalculatedPathLength or totalLength <= 0 then
        totalLength = 0
        local lastPos = self.Path:GetPointAt(0)
        
        -- Build distance map along the path
        for i = 1, samples do
            local t = i / samples
            local currentPos = self.Path:GetPointAt(t)
            if currentPos then
                local segmentLength = (currentPos - lastPos).Magnitude
                totalLength = totalLength + segmentLength
                distanceMap[i + 1] = totalLength
                lastPos = currentPos
            else
                print("[ThreadClass:_calculateActionPointParameters] Warning: GetPointAt returned nil at t=", t)
            end
        end
    else
        -- Reuse path length calculation and build distance map
        local lastPos = self.Path:GetPointAt(0)
        for i = 1, samples do
            local t = i / samples
            local currentPos = self.Path:GetPointAt(t)
            if currentPos then
                local segmentLength = (currentPos - lastPos).Magnitude
                distanceMap[i + 1] = distanceMap[i] + segmentLength
                lastPos = currentPos
            end
        end
    end
    
    -- Safety check for zero-length paths
    if totalLength <= 0 then
        print("[ThreadClass:_calculateActionPointParameters] Warning: Zero path length, using uniform distribution")
        for i = 1, #self.Path.Points do
            actionPointParams[i] = (i-1) / math.max(1, #self.Path.Points-1)
        end
        return actionPointParams
    end
    
    -- For each action point, find the closest sample point and calculate its arc-length parameter
    for pointIdx = 1, #self.Path.Points do
        local targetPos = self.Path.Points[pointIdx].Position
        if not targetPos then
            print("[ThreadClass:_calculateActionPointParameters] Warning: Point", pointIdx, "missing Position")
            actionPointParams[pointIdx] = (pointIdx-1) / math.max(1, #self.Path.Points-1)
        else
            local closestDistance = math.huge
            local closestSampleIdx = 1
            
            -- Find the sample point closest to this action point
            for sampleIdx = 1, samples + 1 do
                local t = (sampleIdx - 1) / samples
                local samplePos = self.Path:GetPointAt(t)
                if samplePos then
                    local distance = (samplePos - targetPos).Magnitude
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestSampleIdx = sampleIdx
                    end
                end
            end
            
            -- Calculate arc-length parameter for this action point
            local arcLengthT = distanceMap[closestSampleIdx] / totalLength
            actionPointParams[pointIdx] = arcLengthT
            
            print(string.format("[ThreadClass:_calculateActionPointParameters] Point %d: t=%.4f (distance to path: %.3f)", 
                  pointIdx, arcLengthT, closestDistance))
        end
    end
    
    return actionPointParams
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
