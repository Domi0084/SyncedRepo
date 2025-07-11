-- Main.lua
-- Główny moduł NodeFrame (modularna wersja)

local NodeFrame = {}
NodeFrame.__index = NodeFrame

-- Finds NodeFrame instance in parent UI
function NodeFrame.GetNodeFrame(parent)
	return parent:FindFirstChild("NodeFrame")
end

-- Initializes NodeFrame logic (selection, drag, etc.)
function NodeFrame.init(nodeFrameInstance, callbacks)
	if not nodeFrameInstance then return end
	-- Example: connect selection logic
	if callbacks and callbacks.OnSelect then
		nodeFrameInstance.MouseButton1Click:Connect(callbacks.OnSelect)
	end
	-- Example: connect drag logic
	if callbacks and callbacks.OnDrag then
		-- Add drag event connection here
	end
end

-- Sets node title
function NodeFrame.SetTitle(nodeFrameInstance, title)
	local titleLabel = nodeFrameInstance:FindFirstChild("Title")
	if titleLabel then titleLabel.Text = title end
end

-- Sets port values
function NodeFrame.SetPorts(nodeFrameInstance, inputText, outputText)
	local ports = nodeFrameInstance:FindFirstChild("Ports")
	if ports then
		local input = ports:FindFirstChild("Input")
		local output = ports:FindFirstChild("Output")
		if input then input.Text = inputText end
		if output then output.Text = outputText end
	end
end

return NodeFrame
