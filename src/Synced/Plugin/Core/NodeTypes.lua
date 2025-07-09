-- Defines available node types and their properties

local NodeTypes = {
	-- A. Input/Start Nodes
	StartChoreography = {
		label = "Start Choreography",
		color = Color3.fromRGB(100, 200, 100),
		params = {},
		outputs = {"sequence"},
		inputs = {}
	},
	CreateThread = {
		label = "Create Thread",
		color = Color3.fromRGB(210, 180, 255),
		params = {"color", "width", "threadId"},
		outputs = {"sequence", "thread"},
		inputs = {"sequence"}
	},
	
	-- B. Movement/Transformation Nodes
	MoveAlongPath = {
		label = "Move Along Path",
		color = Color3.fromRGB(180, 255, 120),
		params = {},
		outputs = {"sequence"},
		inputs = {"sequence", "path", "speed", "thread"}
	},
	
	-- C. Appearance Nodes
	SetThreadColor = {
		label = "Set Thread Color",
		color = Color3.fromRGB(255, 200, 100),
		params = {},
		outputs = {"sequence"},
		inputs = {"sequence", "color", "thread"}
	},
	SetThreadIntensity = {
		label = "Set Thread Intensity",
		color = Color3.fromRGB(255, 180, 100),
		params = {},
		outputs = {"sequence"},
		inputs = {"sequence", "intensity", "thread"}
	},
	
	-- D. Logic/Control Flow Nodes
	Delay = {
		label = "Delay",
		color = Color3.fromRGB(200, 200, 100),
		params = {},
		outputs = {"sequence"},
		inputs = {"sequence", "time"}
	},
	Sequence = {
		label = "Sequence",
		color = Color3.fromRGB(150, 150, 200),
		params = {"outputCount"},
		outputs = {"sequence", "sequence"}, -- Can be dynamically extended
		inputs = {"sequence"}
	},
	Tween = {
		label = "Tween",
		color = Color3.fromRGB(240, 220, 128),
		params = {"interpolationStyle"},
		outputs = {"sequence", "interpolatedValue"},
		inputs = {"sequence", "startValue", "endValue", "duration"}
	},
	
	-- Utility Nodes
	Path = {
		label = "Path",
		color = Color3.fromRGB(120, 180, 255),
		params = {"actionPoints"},
		outputs = {"path"},
		inputs = {},
		id = nil -- Will be set when node is created
	}
}

-- Connection compatibility rules - strict typing
local ConnectionRules = {
	-- Define which output types can connect to which input types
	["sequence"] = {"sequence"},
	["number"] = {"number", "speed", "intensity", "time", "duration"},
	["vector3d"] = {"vector3d"},
	["color"] = {"color", "startValue", "endValue"},
	["cframe"] = {"cframe"},
	["path"] = {"path"},
	["thread"] = {"thread"},
	["speed"] = {"speed"},
	["intensity"] = {"intensity"},
	["time"] = {"time"},
	["duration"] = {"duration"},
	["startValue"] = {"startValue"},
	["endValue"] = {"endValue"},
	["interpolatedValue"] = {"number", "color"} -- Can be number or color
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
local InputNodes = {
	StartChoreography = true,
	CreateThread = true,
}
local TransformationNodes = {
	MoveAlongPath = true,
}
local AppearanceNodes = {
	SetThreadColor = true,
	SetThreadIntensity = true,
}
local LogicNodes = {
	Delay = true,
	Sequence = true,
	Tween = true,
}
local UtilityNodes = {
	Path = true,
}

NodeTypes.InputNodes = InputNodes
NodeTypes.TransformationNodes = TransformationNodes
NodeTypes.AppearanceNodes = AppearanceNodes
NodeTypes.LogicNodes = LogicNodes
NodeTypes.UtilityNodes = UtilityNodes

-- For backward compatibility with existing UI
NodeTypes.BuilderNodes = InputNodes
NodeTypes.MovementNodes = TransformationNodes

return NodeTypes