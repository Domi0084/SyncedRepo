-- Choreography Editor Plugin Initialization
-- Refactored for premade UI only, modular event delegation

local NodeTypes = require(script.Parent.Core.NodeTypes)
local NodeGraphClass = require(script.Parent.Core.NodeGraph)
local Playback = require(script.Parent.Core.Playback)
local PathEditor = require(script.Parent.UIDrivers.PathEditor)
local NodeCanvas = require(script.Parent.UIDrivers.NodeCanvas)
local TopBar = require(script.Parent.UIDrivers.TopBar)
local PropertyPanel = require(script.Parent.UIDrivers.PropertyPanel)

local Toolbar = plugin:CreateToolbar("Choreography Editor")
local ButtonOpen = Toolbar:CreateButton("Open", "Open Choreography Editor", "rbxassetid://4458901886")

local dockInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, true, 900, 600, 600, 400)
local widget = plugin:CreateDockWidgetPluginGui("ChoreographyEditor", dockInfo)
widget.Title = "Choreography Editor"
widget.Enabled = false
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local nodeGraph = NodeGraphClass.new()

local pluginUI = script.Parent:FindFirstChild("PluginUI")
local uiClone = pluginUI and pluginUI:Clone() or nil
print(uiClone)
if uiClone then
	for _, child in ipairs(uiClone:GetChildren()) do
		child.Parent = widget
	end
end

local topBar = uiClone and uiClone:FindFirstChild("TopBar")
local nodeCanvas = uiClone and uiClone:FindFirstChild("NodeCanvas")
local propertyPanel = uiClone and uiClone:FindFirstChild("PropertyPanel")
local addNodesPanel = uiClone and uiClone:FindFirstChild("AddNodesPanel")

if topBar then TopBar.init(topBar, { OnPlay = function() Playback:Play(nodeGraph) end, OnStop = function() Playback:Stop() end }) end
if propertyPanel then PropertyPanel.init(propertyPanel, nodeGraph) end
if nodeCanvas then NodeCanvas.init(nodeCanvas, nodeGraph) end

ButtonOpen.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- No UI creation, all logic delegated to UIDrivers
