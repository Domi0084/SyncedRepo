-- PathClass.lua
-- Represents a path in 3D space and provides sampling utilities

--[[]
Path Parameters (set at the top for easy configuration/debugging):

local PATH_CONFIG = {
    noiseAmount = 0,      -- (number) Adds organic randomness to the path. 0 = no noise, higher = more wobbly/organic.
    tension = 0.5,        -- (number, 0-1) Controls how tight the curve is. 0 = very loose/rounded, 1 = very tight/linear. Standard Catmull-Rom is 0.5.
    centripetal = false,  -- (bool) If true, uses centripetal Catmull-Rom for more stable curves (prevents loops/overshoot with uneven points).
}

How these affect the path:
- noiseAmount: Adds random jitter to the path for a more natural/hand-drawn look.
- tension: Lower values make curves rounder and looser, higher values make them tighter and closer to the points.
- centripetal: When true, the curve is less likely to overshoot or loop, especially with unevenly spaced points.
]]

local PATH_CONFIG = {
    noiseAmount = 0,      -- Try 0.1 to 0.5 for visible organic effect
    tension = 0.5,        -- 0.5 is standard Catmull-Rom
    centripetal = false,  -- Set true for more stable curves
    waveAmplitude = 0.5,  -- (number) Amplitude of delicate waves (studs)
    waveFrequency = 2,    -- (number) Number of wave cycles along the path
    wavePhase = 1,        -- (number) Phase offset for the wave
}

local PathClass = {}
PathClass.__index = PathClass

-- Creates a new PathClass from an array of Vector3 points and pathParams
function PathClass.new(points, pathParams)
    assert(points and #points > 0, "PathClass.new requires a non-empty table of points with Position (Vector3)")
    local self = setmetatable({}, PathClass)
    self.Points = {}
    self.Params = pathParams or {}
    for _, pt in ipairs(points) do
        if type(pt) == "table" and pt.Position and typeof(pt.Position) == "Vector3" then
            table.insert(self.Points, {Position = pt.Position, Type = pt.Type, Params = pt.Params})
        elseif typeof(pt) == "Vector3" then
            table.insert(self.Points, {Position = pt})
        end
    end
    -- Auto-smooth: resample if any points are too close
    local minDist = 1
    local needsResample = false
    for i = 2, #self.Points do
        if (self.Points[i].Position - self.Points[i-1].Position).Magnitude < minDist then
            needsResample = true
            break
        end
    end
    if needsResample then
        print("[PathClass] Resampling for smoothness...")
        self:Resample(minDist)
    end
    return self
end

-- Update applyWave to use skipWave
local function applyWave(self, pos, t)
    local amp = PATH_CONFIG.waveAmplitude or 0
    local freq = PATH_CONFIG.waveFrequency or 0
    local phase = PATH_CONFIG.wavePhase or 0
    if amp > 0 and freq > 0 then
        -- Estimate tangent for direction
        local delta = 0.001
        local t1 = math.clamp(t - delta, 0, 1)
        local t2 = math.clamp(t + delta, 0, 1)
        local p1 = self:GetPointAt(t1, nil, true)
        local p2 = self:GetPointAt(t2, nil, true)
        local tangent = (p2 - p1).Unit
        -- Find a stable perpendicular vector (arbitrary, but consistent)
        local up = Vector3.new(0,1,0)
        if math.abs(tangent:Dot(up)) > 0.99 then up = Vector3.new(1,0,0) end
        local perp = tangent:Cross(up).Unit
        -- Sine-based offset
        local wave = math.sin(2*math.pi*freq*t + phase) * amp
        pos = pos + perp * wave
    end
    return pos
end

-- Returns a point along the path at parameter t (0-1) using Catmull-Rom spline interpolation
function PathClass:GetPointAt(t, noiseAmount, skipWave)
    local n = #self.Points
    local pos
    if n == 0 then
        pos = Vector3.zero
    elseif n == 1 then
        pos = self.Points[1].Position
    elseif n == 2 then
        local a = self.Points[1].Position
        local b = self.Points[2].Position
        pos = a:Lerp(b, t)
    elseif n == 3 then
        -- Use quadratic Bézier for 3 points for a smooth, oval-like arc
        local a = self.Points[1].Position
        local b = self.Points[2].Position
        local c = self.Points[3].Position
        local ab = a:Lerp(b, t)
        local bc = b:Lerp(c, t)
        pos = ab:Lerp(bc, t)
    else
        -- Generalized Catmull-Rom with tension and centripetal
        local tension = PATH_CONFIG.tension or 0.5
        local centripetal = PATH_CONFIG.centripetal
        local totalSegments = n - 1
        local segFloat = t * totalSegments
        local segIdx = math.floor(segFloat) + 1
        local segT = segFloat - (segIdx - 1)
        -- Clamp indices for endpoints
        local i0 = math.max(1, segIdx - 1)
        local i1 = segIdx
        local i2 = math.min(n, segIdx + 1)
        local i3 = math.min(n, segIdx + 2)
        local p0 = self.Points[i0].Position
        local p1 = self.Points[i1].Position
        local p2 = self.Points[i2].Position
        local p3 = self.Points[i3].Position
        -- Centripetal parameterization (optional)
        local function getAlpha(pa, pb)
            if centripetal then
                return ((pb - pa).Magnitude)^0.5
            else
                return 1
            end
        end
        local t0 = 0
        local t1 = t0 + getAlpha(p0, p1)
        local t2 = t1 + getAlpha(p1, p2)
        local t3 = t2 + getAlpha(p2, p3)
        local tt = t1 + segT * (t2 - t1)
        -- Generalized Catmull-Rom with tension and centripetal
        local function interpolate(t, t0, t1, t2, t3, p0, p1, p2, p3)
            local A1 = p0 * ((t1-t)/(t1-t0)) + p1 * ((t-t0)/(t1-t0))
            local A2 = p1 * ((t2-t)/(t2-t1)) + p2 * ((t-t1)/(t2-t1))
            local A3 = p2 * ((t3-t)/(t3-t2)) + p3 * ((t-t2)/(t3-t2))
            local B1 = A1 * ((t2-t)/(t2-t0)) + A2 * ((t-t0)/(t2-t0))
            local B2 = A2 * ((t3-t)/(t3-t1)) + A3 * ((t-t1)/(t3-t1))
            local C = B1 * ((t2-t)/(t2-t1)) + B2 * ((t-t1)/(t2-t1))
            return (1-tension)*C + tension*(p1:Lerp(p2, segT))
        end
        pos = interpolate(tt, t0, t1, t2, t3, p0, p1, p2, p3)
    end
    -- Apply delicate wave offset
    if not skipWave then
        pos = applyWave(self, pos, t)
    end
    noiseAmount = noiseAmount or PATH_CONFIG.noiseAmount
    if noiseAmount and noiseAmount > 0 and not skipWave then
        local n = math.noise(pos.X * 0.1, pos.Y * 0.1, pos.Z * 0.1 + tick())
        pos = pos + Vector3.new(n, n, n) * noiseAmount
    end
    return pos
end

-- Utility: Chaikin's corner-cutting smoothing algorithm
function PathClass:ChaikinSmooth(iterations)
    iterations = iterations or 1
    for _ = 1, iterations do
        local newPoints = {}
        local n = #self.Points
        if n < 3 then return end
        table.insert(newPoints, self.Points[1]) -- Keep first point
        for i = 1, n - 1 do
            local p0 = self.Points[i].Position
            local p1 = self.Points[i+1].Position
            local Q = p0:Lerp(p1, 0.25)
            local R = p0:Lerp(p1, 0.75)
            table.insert(newPoints, {Position = Q})
            table.insert(newPoints, {Position = R})
        end
        table.insert(newPoints, self.Points[n]) -- Keep last point
        self.Points = newPoints
    end
end

-- Utility: Resample and smooth path points for even spacing and minimum distance
function PathClass:Resample(minDist)
    minDist = minDist or 1
    -- Smooth the base points first (before resampling and before waves)
    self:ChaikinSmooth(1) -- You can adjust the number of iterations for more/less smoothing
    local newPoints = {}
    local totalLen = 0
    -- Compute total path length (using base GetPointAt)
    local last = self:GetPointAt(0)
    for i = 1, 20 do -- Use 20 segments for length estimation
        local t = i / 20
        local pt = self:GetPointAt(t)
        totalLen = totalLen + (pt - last).Magnitude
        last = pt
    end
    local numSamples = math.max(8, math.floor(totalLen / minDist))
    for i = 0, numSamples do
        local t = i / (numSamples)
        local pos = self:GetPointAt(t)
        table.insert(newPoints, {Position = pos})
    end
    self.Points = newPoints
    -- Do NOT apply Chaikin smoothing after the wave
end

-- Visualizes the entire path as a dense series of small parts along the curve
function PathClass:Visualize(parent)
    -- Remove previous debug parts if any
    for _, obj in ipairs(parent:GetChildren()) do
        if obj.Name == "PathDebugPart" then
            obj:Destroy()
        end
    end
    -- Draw the full path by sampling at small intervals
    local totalLen = 0
    local last = self:GetPointAt(0)
    local samples = {}
    -- Estimate total path length
    for i = 1, 100 do
        local t = i / 100
        local pt = self:GetPointAt(t)
        totalLen = totalLen + (pt - last).Magnitude
        last = pt
    end
    local step = 0.1
    local numSamples = math.max(2, math.floor(totalLen / step))
    for i = 0, numSamples do
        local t = i / numSamples
        local pos = self:GetPointAt(t)
        local part = Instance.new("Part")
        part.Name = "PathDebugPart"
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(0.15,0.15,0.15)
        part.Position = pos
        part.Color = Color3.new(1, 0, 0)
        part.Parent = parent
    end
end

return PathClass
