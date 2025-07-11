-- NodeCanvas.lua
-- Enhanced: Adds zooming, node creation, and dynamic redraw for premade UI NodeCanvas

local NodeCanvas = {}
NodeCanvas.__index = NodeCanvas

local Helpers = require(script.Parent.Utility.Helpers)

function NodeCanvas.GetNodeCanvas(pluginUI)
	return pluginUI:FindFirstChild("NodeCanvas")
end

-- Adds a new node using the NodeTemplate in GridLayer
function NodeCanvas.AddNode(nodeCanvasInstance, nodeData)
	local gridLayer = nodeCanvasInstance:FindFirstChild("GridLayer")
	local display = gridLayer and gridLayer:FindFirstChild("Display")
	local template = gridLayer and gridLayer:FindFirstChild("NodeTemplate")
	if not (display and template) then return end
	local newNode = template:Clone()
	newNode.Name = nodeData.Name or ("Node" .. tostring(math.random(10000,99999)))
	newNode.Visible = true
	if newNode:FindFirstChild("Title") then
		newNode.Title.Text = nodeData.Title or newNode.Name
		if nodeData.Color then
			newNode.Title.BackgroundColor3 = nodeData.Color
		end
	end
	if nodeData.Ports then
		local ports = newNode:FindFirstChild("Ports")
		if ports then
			if ports:FindFirstChild("Input") then ports.Input.Text = nodeData.Ports.Input or "" end
			if ports:FindFirstChild("Output") then ports.Output.Text = nodeData.Ports.Output or "" end
		end
	end
	newNode.Parent = display
	return newNode
end

function NodeCanvas.init(nodeCanvasInstance, nodeGraph)
	if not nodeCanvasInstance then return end
	local gridLayer = nodeCanvasInstance:FindFirstChild("GridLayer")
	local display = gridLayer and gridLayer:FindFirstChild("Display")
	if not display then return end
	-- Mouse wheel zoom
	nodeCanvasInstance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local zoom = nodeCanvasInstance:GetAttribute("Zoom") or 1
			zoom = math.clamp(zoom + (input.Position.Z > 0 and 0.1 or -0.1), 0.2, 2)
			nodeCanvasInstance:SetAttribute("Zoom", zoom)
			NodeCanvas.Redraw(nodeCanvasInstance, nodeGraph)
		end
	end)
	-- Add node button (if exists)
	local addButton = nodeCanvasInstance:FindFirstChild("AddNodeButton")
	if addButton then
		addButton.MouseButton1Click:Connect(function()
			local nodeData = {
				Name = "Node" .. tostring(os.time()),
				Title = "New Node",
				Color = Color3.fromRGB(math.random(100,255),math.random(100,255),math.random(100,255)),
				Ports = { Input = "In", Output = "Out" }
			}
			NodeCanvas.AddNode(nodeCanvasInstance, nodeData)
			if nodeGraph and nodeGraph.AddNode then nodeGraph:AddNode(nodeData) end
			NodeCanvas.Redraw(nodeCanvasInstance, nodeGraph)
		end)
	end
	-- Node selection
	for _, nodeFrame in ipairs(display:GetChildren()) do
		if nodeFrame:IsA("Frame") then
			nodeFrame.MouseButton1Click:Connect(function()
				if nodeGraph and nodeGraph.OnNodeSelected then
					nodeGraph:OnNodeSelected(nodeFrame.Name)
				end
			end)
		end
	end
	NodeCanvas.Redraw(nodeCanvasInstance, nodeGraph)
end

function NodeCanvas.Redraw(nodeCanvasInstance, nodeGraph)
	local gridLayer = nodeCanvasInstance:FindFirstChild("GridLayer")
	local display = gridLayer and gridLayer:FindFirstChild("Display")
	if not (display and nodeGraph and nodeGraph.nodes) then return end
	local zoom = nodeCanvasInstance:GetAttribute("Zoom") or 1
	for _, child in ipairs(display:GetChildren()) do
		if child:IsA("Frame") then child.Visible = false end
	end
	for _, nodeData in ipairs(nodeGraph.nodes) do
		local nodeFrame = display:FindFirstChild(nodeData.Name)
		if not nodeFrame then
			nodeFrame = NodeCanvas.AddNode(nodeCanvasInstance, nodeData)
		end
		if nodeFrame:FindFirstChild("Title") then
			nodeFrame.Title.Text = nodeData.Title or nodeData.Name
		end
		nodeFrame.Visible = true
		-- Apply zoom to node size/position if needed
		-- nodeFrame.Size = UDim2.new(0, 200 * zoom, 0, 100 * zoom) -- example
	end
end

return NodeCanvas
