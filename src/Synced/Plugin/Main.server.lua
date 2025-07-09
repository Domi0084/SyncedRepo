--!script
local NodeTypes = require(script.Parent.Core.NodeTypes)
local NodeGraphClass = require(script.Parent.Core.NodeGraph)
local TopBar = require(script.Parent.UI.TopBar)
local NodeCanvas = require(script.Parent.UI.NodeCanvas)
local Playback = require(script.Parent.Core.Playback)
local PathEditor = require(script.Parent.UI.PathEditor)
local PropertyPanel = require(script.Parent.UI.PropertyPanel)

local Toolbar = plugin:CreateToolbar("Choreography Editor")
local ButtonOpen = Toolbar:CreateButton("Open", "Open Choreography Editor", "rbxassetid://4458901886")

local dockInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, true, true, 900, 600, 600, 400)
local widget = plugin:CreateDockWidgetPluginGui("ChoreographyEditor", dockInfo)
widget.Title = "Choreography Editor"
widget.Enabled = false

ButtonOpen.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	if not widget.Enabled then
		-- Cleanup UI resources if needed
		for _, child in ipairs(widget:GetChildren()) do
			if child:IsA("Frame") or child:IsA("Folder") then
				child:Destroy()
			end
		end
	end
end)

-- Use an instance of NodeGraph (not the module!)
local nodeGraph = NodeGraphClass.new()

-- Initialize UI components
local propertyPanel = PropertyPanel.new(widget, nodeGraph, NodeTypes)
local nodeCanvas = NodeCanvas.new(widget, nodeGraph, NodeTypes, propertyPanel)
local topBar = TopBar.new(widget, nodeGraph, NodeTypes, Playback)

-- PathEdit mode: allows editing a PathNode (keypoints in 3D)
-- GeneralChoreographyEdit mode: allows editing the full node graph and connecting to PathNodes

local PluginModes = {
    PathEdit = "PathEdit",
    GeneralChoreographyEdit = "GeneralChoreographyEdit"
}

local currentMode = PluginModes.GeneralChoreographyEdit
local currentPathNode = nil
local currentPathEditor = nil

-- Switch modes
local function SetMode(mode)
    currentMode = mode
    if mode == PluginModes.PathEdit then
        -- Show 3D path editing UI, hide general node editor
        if nodeCanvas then nodeCanvas.Visible = false end
        if propertyPanel then propertyPanel:Hide() end
        
        -- Find the first Path node or create a default one
        local pathNode = nil
        for _, node in ipairs(nodeGraph.nodes) do
            if node.type == "Path" then
                pathNode = node
                break
            end
        end
        
        if pathNode then
            Show3DKeypointEditor(pathNode)
        end
    else
        -- Show general node editor, hide 3D path editing UI
        if nodeCanvas then nodeCanvas.Visible = true end
        if currentPathEditor then 
            currentPathEditor:Destroy()
            currentPathEditor = nil
        end
    end
end

-- Example: when user selects a PathNode in the node editor
local function OnSelectPathNode(pathNode)
    Show3DKeypointEditor(pathNode)
end

-- Example: when user finishes editing path and confirms
local function OnFinishPathEdit(editedKeypoints)
    if currentPathNode then
        currentPathNode.params.Keypoints = editedKeypoints
    end
    SetMode(PluginModes.GeneralChoreographyEdit)
end

-- 3D Keypoint Editing UI (PathEdit mode)
local function Show3DKeypointEditor(pathNode)
    if currentPathEditor then currentPathEditor:Destroy() end
    currentPathNode = pathNode
    currentPathEditor = PathEditor.new(widget, pathNode.params.Keypoints or {}, function(editedKeypoints)
        pathNode.params.Keypoints = editedKeypoints
        if currentPathEditor then currentPathEditor:Destroy() end
        currentPathEditor = nil
        SetMode(PluginModes.GeneralChoreographyEdit)
    end, function()
        if currentPathEditor then currentPathEditor:Destroy() end
        currentPathEditor = nil
        SetMode(PluginModes.GeneralChoreographyEdit)
    end)
    SetMode(PluginModes.PathEdit)
end

-- Export global functions for TopBar and NodeCanvas
_G.SetMode = SetMode
_G.Show3DKeypointEditor = Show3DKeypointEditor

-- Export choreography for ChoreographyManager
local function ExportChoreography(nodeGraph)
    return {
        nodes = nodeGraph.nodes,
        connections = nodeGraph.connections
    }
end

-- Helper to require from ReplicatedStorage or fallback to local
local function safeRequire(pathInReplicatedStorage, localModule)
    local ok, mod = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local target = ReplicatedStorage:FindFirstChild(pathInReplicatedStorage, true)
        if target then return require(target) end
        error("Not found in ReplicatedStorage")
    end)
    if ok and mod then
        return mod
    else
        return require(localModule)
    end
end

local ChoreographyManager = safeRequire("Synced/ThreadSystem/Services/ChoreographyManager", script.Parent.ThreadSystem.Services.ChoreographyManager)
local manager = ChoreographyManager.new()

local Playback = {}
Playback.__index = Playback

function Playback:Play(graph)
    local choreoTable = ExportChoreography(graph)
    manager:PlayChoreography(choreoTable)
end

function Playback:Stop()
    manager:Cleanup()
end

return Playback
