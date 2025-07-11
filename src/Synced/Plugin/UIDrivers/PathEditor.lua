-- PathEditor.lua
-- Refactored: Only operates on premade PathEditor UI

local PathEditor = {}
PathEditor.__index = PathEditor

function PathEditor.GetPathEditor(pluginUI)
	return pluginUI:FindFirstChild("Path")
end

function PathEditor.SetKeypoints(pluginUI, keypoints)
	local pathEditor = PathEditor.GetPathEditor(pluginUI)
	if not pathEditor then return end
	if pathEditor:FindFirstChild("Keypoints") then
		pathEditor.Keypoints.Value = keypoints
	end
end

return PathEditor