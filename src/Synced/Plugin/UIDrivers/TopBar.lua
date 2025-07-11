-- TopBar.lua
-- Refactored: Only operates on premade TopBar UI

local TopBar = {}
TopBar.__index = TopBar

function TopBar.GetTopBar(pluginUI)
	return pluginUI:FindFirstChild("TopBar")
end

function TopBar.init(topBarInstance, callbacks)
	if not topBarInstance then return end
	local buttonMap = {
		Play = callbacks.OnPlay,
		Stop = callbacks.OnStop,
		Save = callbacks.OnSave,
		Load = callbacks.OnLoad
	}
	for name, callback in pairs(buttonMap) do
		local button = topBarInstance:FindFirstChild(name)
		if button and callback and button:IsA("ImageButton") then
			button.MouseButton1Click:Connect(callback)
		end
	end
	-- Allow custom callbacks for other buttons
	if callbacks.Other then
		for name, callback in pairs(callbacks.Other) do
			local button = topBarInstance:FindFirstChild(name)
			if button and button:IsA("ImageButton") then
				button.MouseButton1Click:Connect(callback)
			end
		end
	end
end

return TopBar
