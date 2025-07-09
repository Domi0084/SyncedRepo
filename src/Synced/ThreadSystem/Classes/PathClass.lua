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

RECENT FIX: Brush Offset Issue
- Modified GetPointAt() to ensure exact passage through control points while maintaining smooth curves
- Enhanced wave function to have zero effect at control points
- Added tolerance checks to guarantee brush hits all specified path points
- Maintains circular/oval/flowy shape between control points through Catmull-Rom spline interpolation
]]

local PATH_CONFIG = {
    noiseAmount = 0,      -- Try 0.1 to 0.5 for visible organic effect
    tension = 0.5,        -- 0.5 is standard Catmull-Rom
    centripetal = true,   -- Set true for more stable curves - IMPROVED: enabled by default
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
    -- Always preserve user points
    local userPoints = {}
    for _, pt in ipairs(points) do
        if type(pt) == "table" and pt.Position and typeof(pt.Position) == "Vector3" then
            table.insert(userPoints, {Position = pt.Position, Type = pt.Type, Params = pt.Params})
        elseif typeof(pt) == "Vector3" then
            table.insert(userPoints, {Position = pt})
        end
    end
    -- Add extrapolated support points at start and end for circular/flowy shape
    local n = #userPoints
    if n >= 2 then
        local first = userPoints[1].Position
        local second = userPoints[2].Position
        local last = userPoints[n].Position
        local penultimate = userPoints[n-1].Position
        -- Extrapolate before first and after last
        local pre = {Position = first + (first - second)}
        local post = {Position = last + (last - penultimate)}
        table.insert(self.Points, pre)
        for _, pt in ipairs(userPoints) do table.insert(self.Points, pt) end
        table.insert(self.Points, post)
    else
        for _, pt in ipairs(userPoints) do table.insert(self.Points, pt) end
    end
    -- Optionally, insert support points at sharp angles for extra smoothness
    local angleThreshold = math.pi * 0.7 -- ~126 degrees
    local i = 2
    while i < #self.Points do
        local p0 = self.Points[i-1].Position
        local p1 = self.Points[i].Position
        local p2 = self.Points[i+1].Position
        local v1 = (p1 - p0)
        local v2 = (p2 - p1)
        if v1.Magnitude > 0.001 and v2.Magnitude > 0.001 then
            local angle = math.acos(math.max(-1, math.min(1, v1.Unit:Dot(v2.Unit))))
            if angle > angleThreshold then
                -- Insert a support point between p1 and p2
                local support = {Position = p1:Lerp(p2, 0.5)}
                table.insert(self.Points, i+1, support)
                i = i + 1 -- Skip over the new support point
            end
        end
        i = i + 1
    end
    return self
end

-- FIXED: Update applyWave to ensure zero offset at control points
local function applyWave(self, pos, t)
    local amp = PATH_CONFIG.waveAmplitude or 0
    local freq = PATH_CONFIG.waveFrequency or 0
    local phase = PATH_CONFIG.wavePhase or 0
    if amp > 0 and freq > 0 then
        -- Find which segment t is in
        local n = #self.Points
        if n < 2 then return pos end
        local totalSegments = n - 1
        local segFloat = t * totalSegments
        local segIdx = math.floor(segFloat) + 1
        local localT = segFloat - (segIdx - 1) -- 0 at start, 1 at end of segment
        
        -- FIXED: Enhanced weight calculation to ensure zero at control points
        local tolerance = 0.01
        local weight = 0
        
        -- Check if we're near a control point
        local nearControlPoint = false
        for i = 1, n do
            local controlT = (i - 1) / totalSegments
            if math.abs(t - controlT) < tolerance then
                nearControlPoint = true
                break
            end
        end
        
        if not nearControlPoint then
            -- Weight: 0 at control points, 1 at middle of segments
            weight = math.sin(math.pi * localT)
        end
        
        -- Only apply wave if not at or near a control point
        if weight > 0.001 then
            local delta = 0.01
            local t1 = math.max(0, math.min(1, t - delta))
            local t2 = math.max(0, math.min(1, t + delta))
            local p1 = self:GetPointAt(t1, nil, true)
            local p2 = self:GetPointAt(t2, nil, true)
            local tangent = (p2 - p1)
            if tangent.Magnitude > 0.001 then
                tangent = tangent.Unit
                local up = Vector3.new(0,1,0)
                if math.abs(tangent:Dot(up)) > 0.99 then up = Vector3.new(1,0,0) end
                local perp = tangent:Cross(up).Unit
                local wave = math.sin(2*math.pi*freq*t + phase) * amp * weight
                pos = pos + perp * wave
            end
        end
    end
    return pos
end

-- Returns a point along the path at parameter t (0-1) using centripetal Catmull-Rom spline
-- Passes through all user points, and overlays a smooth organic wave (zero at control points)
function PathClass:GetPointAt(t, noiseAmount, skipWave)
    local n = #self.Points
    if n == 0 then
        return Vector3.zero
    elseif n == 1 then
        return self.Points[1].Position
    elseif n == 2 then
        local a = self.Points[1].Position
        local b = self.Points[2].Position
        return a:Lerp(b, t)
    end
    -- Clamp t to [0, 1]
    t = math.clamp(t, 0, 1)
    local totalSegments = n - 1
    local segFloat = t * totalSegments
    local segIdx = math.floor(segFloat) + 1
    local localT = segFloat - (segIdx - 1)
    -- Guarantee: if t is exactly at a control point, return that point
    local tolerance = 1e-6
    for i = 1, n do
        local controlT = (i - 1) / totalSegments
        if math.abs(t - controlT) < tolerance then
            return self.Points[i].Position
        end
    end
    -- Clamp segment index to valid range
    segIdx = math.clamp(segIdx, 1, n - 1)
    local i0 = math.max(1, segIdx - 1)
    local i1 = segIdx
    local i2 = math.min(n, segIdx + 1)
    local i3 = math.min(n, segIdx + 2)
    local p0 = self.Points[i0].Position
    local p1 = self.Points[i1].Position
    local p2 = self.Points[i2].Position
    local p3 = self.Points[i3].Position
    -- Centripetal Catmull-Rom
    local function getAlpha(pa, pb)
        local dist = (pb - pa).Magnitude
        return math.max(0.001, dist^0.5)
    end
    local t0 = 0
    local t1 = t0 + getAlpha(p0, p1)
    local t2 = t1 + getAlpha(p1, p2)
    local t3 = t2 + getAlpha(p2, p3)
    local tt = t1 + localT * (t2 - t1)
    local function interpolate(t, t0, t1, t2, t3, p0, p1, p2, p3)
        local A1 = p0 * ((t1-t)/(t1-t0)) + p1 * ((t-t0)/(t1-t0))
        local A2 = p1 * ((t2-t)/(t2-t1)) + p2 * ((t-t1)/(t2-t1))
        local A3 = p2 * ((t3-t)/(t3-t2)) + p3 * ((t-t2)/(t3-t2))
        local B1 = A1 * ((t2-t)/(t2-t0)) + A2 * ((t-t0)/(t2-t0))
        local B2 = A2 * ((t3-t)/(t3-t1)) + A3 * ((t-t1)/(t3-t1))
        local C = B1 * ((t2-t)/(t2-t1)) + B2 * ((t-t1)/(t2-t1))
        return C
    end
    local pos = interpolate(tt, t0, t1, t2, t3, p0, p1, p2, p3)
    -- Organic wave overlay: sine-based, zero at control points, max at segment mid
    if not skipWave then
        local amp = PATH_CONFIG.waveAmplitude or 0.5
        local freq = PATH_CONFIG.waveFrequency or 2
        if amp > 0 and freq > 0 then
            -- Weight: 0 at control points, 1 at middle of segment
            local weight = math.sin(math.pi * localT)
            if weight > 0.001 then
                -- Perpendicular direction for wave
                local delta = 0.01
                local t1w = math.max(0, math.min(1, t - delta))
                local t2w = math.max(0, math.min(1, t + delta))
                local p1w = self:GetPointAt(t1w, nil, true)
                local p2w = self:GetPointAt(t2w, nil, true)
                local tangent = (p2w - p1w)
                if tangent.Magnitude > 0.001 then
                    tangent = tangent.Unit
                    local up = Vector3.new(0,1,0)
                    if math.abs(tangent:Dot(up)) > 0.99 then up = Vector3.new(1,0,0) end
                    local perp = tangent:Cross(up).Unit
                    local wave = math.sin(2*math.pi*freq*t) * amp * weight
                    pos = pos + perp * wave
                end
            end
        end
    end
    noiseAmount = noiseAmount or PATH_CONFIG.noiseAmount
    if noiseAmount and noiseAmount > 0 and not skipWave then
        local n = math.noise(pos.X * 0.1, pos.Y * 0.1, pos.Z * 0.1 + tick())
        pos = pos + Vector3.new(n, n, n) * noiseAmount
    end
    return pos
end

-- Utility: Chaikin's corner-cutting smoothing algorithm - IMPROVED: More iterations
function PathClass:ChaikinSmooth(iterations)
    iterations = iterations or 2  -- IMPROVED: Increased default from 1 to 2 for smoother curves
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
-- This version guarantees the path passes through all original points,
-- and adds support points only if the path is rough (sharp angles or uneven spacing).
function PathClass:Resample(minDist)
    minDist = minDist or 1.5
    local origPoints = {}
    for _, pt in ipairs(self.Points) do
        table.insert(origPoints, {Position = pt.Position})
    end

    -- Detect roughness: sharp angles or very uneven spacing
    local roughSegments = {}
    local angleThreshold = math.pi * 0.6 -- ~108 degrees
    local distThreshold = minDist * 2.5
    for i = 2, #origPoints-1 do
        local p0 = origPoints[i-1].Position
        local p1 = origPoints[i].Position
        local p2 = origPoints[i+1].Position
        local v1 = (p1 - p0)
        local v2 = (p2 - p1)
        if v1.Magnitude > 0.001 and v2.Magnitude > 0.001 then
            local angle = math.acos(math.max(-1, math.min(1, v1.Unit:Dot(v2.Unit))))
            if angle > angleThreshold or v1.Magnitude > distThreshold or v2.Magnitude > distThreshold then
                table.insert(roughSegments, i)
            end
        end
    end

    -- Build new point list: always include original points, add support points if rough
    local newPoints = {}
    for i = 1, #origPoints do
        table.insert(newPoints, {Position = origPoints[i].Position})
        -- If this is a rough segment, insert a support point between i and i+1
        if table.find(roughSegments, i) and i < #origPoints then
            local p1 = origPoints[i].Position
            local p2 = origPoints[i+1].Position
            -- Insert a support point at 1/3 and 2/3 between the points for extra smoothness
            local support1 = p1:Lerp(p2, 1/3)
            local support2 = p1:Lerp(p2, 2/3)
            table.insert(newPoints, {Position = support1})
            table.insert(newPoints, {Position = support2})
        end
    end
    self.Points = newPoints
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
        part.Size = Vector3.new(0.05,0.05,0.05)
        part.Position = pos
        part.Color = Color3.new(0, 0.850980, 1)
        part.Parent = parent
        part.Transparency = 1
    end
end

return PathClass
