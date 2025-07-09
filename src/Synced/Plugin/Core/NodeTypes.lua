-- Defines available node types and their properties

local NodeTypes = {
	CreateThread = {
		label = "Create Thread", color = Color3.fromRGB(210,180,255), params = {"element","width","color"},
		outputs = {"thread"}, inputs = {}
	},
	Tween = {
		label = "Tween", color = Color3.fromRGB(240,220,128), params = {"threadIdx","targetParams","duration"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	Path = {
		label = "Path",
		color = Color3.fromRGB(120, 180, 255),
		params = {"Keypoints"},
		outputs = {"path"},
		inputs = {},
		id = nil -- Will be set when node is created
	},
	MoveThread = {
		label = "Move Thread", color = Color3.fromRGB(180,255,120), params = {"threadIdx","targetPosition","duration"},
		inputs = {"thread", "path"}, outputs = {"thread"}  -- Can accept path input
	},
	Wrap = {
		label = "Wrap", color = Color3.fromRGB(80,255,180), params = {"threadIdx","targetNode","radius","spiralTurns","height","offset"},
		inputs = {"thread", "actionPoint"}, outputs = {"thread"}  -- Can accept actionPoint input
	}
}

-- Connection compatibility rules
local ConnectionRules = {
	-- Define which output types can connect to which input types
	["path"] = {"path"},
	["thread"] = {"thread"},
	["actionPoint"] = {"actionPoint"}
}

-- Helper function to validate if a connection is allowed
function NodeTypes.IsConnectionValid(fromNodeType, fromPort, toNodeType, toPort)
	local fromDef = NodeTypes[fromNodeType]
	local toDef = NodeTypes[toNodeType]
	
	if not fromDef or not toDef then return false end
	
	local fromOutputs = fromDef.outputs or {}
	local toInputs = toDef.inputs or {}
	
	if fromPort > #fromOutputs or toPort > #toInputs then return false end
	
	local outputType = fromOutputs[fromPort]
	local inputType = toInputs[toPort]
	
	-- Check if output type is compatible with input type
	local compatibleTypes = ConnectionRules[outputType]
	if compatibleTypes then
		for _, compatibleType in ipairs(compatibleTypes) do
			if compatibleType == inputType then
				return true
			end
		end
	end
	
	return false
end

-- Node categories for UI/logic
local BuilderNodes = {
	CreateThread = true,
}
local MovementNodes = {
	MoveThread = true,
	Wrap = true,
}
local UtilityNodes = {
	Tween = true,
	Path = true,
}
NodeTypes.BuilderNodes = BuilderNodes
NodeTypes.MovementNodes = MovementNodes
NodeTypes.UtilityNodes = UtilityNodes

return NodeTypes