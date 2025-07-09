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
		inputs = {"thread"}, outputs = {"thread"}
	},
	Wrap = {
		label = "Wrap", color = Color3.fromRGB(80,255,180), params = {"threadIdx","targetNode","radius","spiralTurns","height","offset"},
		inputs = {"thread"}, outputs = {"thread"}
	}
}

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