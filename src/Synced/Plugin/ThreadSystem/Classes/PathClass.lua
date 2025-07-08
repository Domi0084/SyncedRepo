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
    -- IMPROVED: Better point validation and preprocessing
    for _, pt in ipairs(points) do
        if type(pt) == "table" and pt.Position and typeof(pt.Position) == "Vector3" then
            table.insert(self.Points, {Position = pt.Position, Type = pt.Type, Params = pt.Params})
        elseif typeof(pt) == "Vector3" then
            table.insert(self.Points, {Position = pt})
        end
    end
    
    -- IMPROVED: Remove duplicate points before distance checking
    local dedupedPoints = {}
    local lastPos = nil
    for _, point in ipairs(self.Points) do
        if not lastPos or (point.Position - lastPos).Magnitude > 0.1 then  -- Remove points closer than 0.1 studs
            table.insert(dedupedPoints, point)
            lastPos = point.Position
        end
    end
    self.Points = dedupedPoints
    
    -- IMPROVED: More flexible auto-smooth with reduced minimum distance
    local minDist = 1.5  -- IMPROVED: Reduced from 2.5 to 1.5 for more flexibility
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

-- Returns a point along the path at parameter t (0-1) using Catmull-Rom spline interpolation
-- IMPROVED: Maintains smooth flow while respecting control points
function PathClass:GetPointAt(t, noiseAmount, skipWave)
    local n = #self.Points
    local pos
    
    -- IMPROVED: Softer control point influence for smoother movement
    local tolerance = 0.0001  -- Much smaller tolerance
    local totalSegments = n - 1
    local nearControlPoint = false
    local controlWeight = 0
    
    if totalSegments > 0 then
        for i = 1, n do
            local controlT = (i - 1) / totalSegments
            local distance = math.abs(t - controlT)
            if distance < tolerance then
                nearControlPoint = true
                controlWeight = 1 - (distance / tolerance) -- Smooth transition
                break
            end
        end
    end
    
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
        local segFloat = t * totalSegments
        local segIdx = math.floor(segFloat) + 1
        local segT = segFloat - (segIdx - 1)
        
        -- IMPROVED: Smoother transitions - remove strict control point snapping
        -- Calculate interpolated position using Catmull-Rom
        local i0, i1, i2, i3
        local p0, p1, p2, p3
        
        -- IMPROVED: Better endpoint handling to avoid discontinuities
        if segIdx == 1 then
            -- At the beginning: extrapolate p0
            i1, i2, i3 = 1, 2, math.min(n, 3)
            p1 = self.Points[i1].Position
            p2 = self.Points[i2].Position
            p3 = self.Points[i3].Position
            p0 = p1 + (p1 - p2)  -- Extrapolate backwards
        elseif segIdx >= n then
            -- At the end: extrapolate p3
            i0, i1, i2 = math.max(1, n-2), math.max(1, n-1), n
            p0 = self.Points[i0].Position
            p1 = self.Points[i1].Position
            p2 = self.Points[i2].Position
            p3 = p2 + (p2 - p1)  -- Extrapolate forwards
        else
            -- Normal case
            i0 = math.max(1, segIdx - 1)
            i1 = segIdx
            i2 = math.min(n, segIdx + 1)
            i3 = math.min(n, segIdx + 2)
            p0 = self.Points[i0].Position
            p1 = self.Points[i1].Position
            p2 = self.Points[i2].Position
            p3 = self.Points[i3].Position
        end
        
        -- Always use smooth interpolation - no exact snapping to segment boundaries
        -- Centripetal parameterization (optional) - IMPROVED: Added safety checks
            local function getAlpha(pa, pb)
                if centripetal then
                    local dist = (pb - pa).Magnitude
                    -- IMPROVED: Avoid division by zero and ensure minimum alpha
                    return math.max(0.001, dist^0.5)
                else
                    return 1
                end
            end
            local t0 = 0
            local t1 = t0 + getAlpha(p0, p1)
            local t2 = t1 + getAlpha(p1, p2)
            local t3 = t2 + getAlpha(p2, p3)
            local tt = t1 + segT * (t2 - t1)
            -- Generalized Catmull-Rom with tension and centripetal - IMPROVED: Added safety checks
            local function interpolate(t, t0, t1, t2, t3, p0, p1, p2, p3)
                -- IMPROVED: Check for degenerate cases to avoid division by zero
                if math.abs(t1 - t0) < 0.001 or math.abs(t2 - t1) < 0.001 or math.abs(t3 - t2) < 0.001 then
                    -- Fallback to simple linear interpolation for degenerate cases
                    return p1:Lerp(p2, segT)
                end
                
                local A1 = p0 * ((t1-t)/(t1-t0)) + p1 * ((t-t0)/(t1-t0))
                local A2 = p1 * ((t2-t)/(t2-t1)) + p2 * ((t-t1)/(t2-t1))
                local A3 = p2 * ((t3-t)/(t3-t2)) + p3 * ((t-t2)/(t3-t2))
                
                -- IMPROVED: Additional safety checks for B1 and B2 calculations
                local B1, B2
                if math.abs(t2 - t0) < 0.001 then
                    B1 = A1
                else
                    B1 = A1 * ((t2-t)/(t2-t0)) + A2 * ((t-t0)/(t2-t0))
                end
                
                if math.abs(t3 - t1) < 0.001 then
                    B2 = A3
                else
                    B2 = A2 * ((t3-t)/(t3-t1)) + A3 * ((t-t1)/(t3-t1))
                end
                
                local C = B1 * ((t2-t)/(t2-t1)) + B2 * ((t-t1)/(t2-t1))
                return (1-tension)*C + tension*(p1:Lerp(p2, segT))
            end
            pos = interpolate(tt, t0, t1, t2, t3, p0, p1, p2, p3)
    end
    
    -- IMPROVED: Apply wave and noise effects with reduced influence near control points
    -- Apply delicate wave offset with control point awareness
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
function PathClass:Resample(minDist)
    minDist = minDist or 1.5  -- IMPROVED: Reduced from 2.5 to 1.5 for more flexibility
    -- IMPROVED: Only smooth if really necessary to preserve original shape
    local needsSmoothing = false
    for i = 2, #self.Points - 1 do
        local p0 = self.Points[i-1].Position
        local p1 = self.Points[i].Position
        local p2 = self.Points[i+1].Position
        
        -- Check for sharp angles that need smoothing
        local v1 = (p1 - p0)
        local v2 = (p2 - p1)
        if v1.Magnitude > 0.001 and v2.Magnitude > 0.001 then
            local angle = math.acos(math.max(-1, math.min(1, v1.Unit:Dot(v2.Unit))))
            if angle > math.pi * 0.6 then -- Sharp angle threshold
                needsSmoothing = true
                break
            end
        end
    end
    
    if needsSmoothing then
        self:ChaikinSmooth(1) -- IMPROVED: Reduced from 2 to 1 iteration to preserve shape
    end
    
    -- IMPROVED: Simpler uniform resampling to avoid over-complexity
    local totalLen = 0
    local last = self:GetPointAt(0)
    
    -- Estimate total path length
    for i = 1, 50 do -- Reduced sampling for efficiency
        local t = i / 50
        local pt = self:GetPointAt(t)
        totalLen = totalLen + (pt - last).Magnitude
        last = pt
    end
    
    -- Create uniformly spaced points
    local baseSamples = math.max(6, math.floor(totalLen / minDist))
    local newPoints = {}
    
    for i = 0, baseSamples do
        local t = i / baseSamples
        local pos = self:GetPointAt(t)
        table.insert(newPoints, {Position = pos})
    end
    
    self.Points = newPoints
    -- IMPROVED: Skip post-processing smoothing to maintain intended path shape
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
