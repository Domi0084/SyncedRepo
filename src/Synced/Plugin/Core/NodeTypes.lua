-- Defines available node types and their properties

local NodeTypes = {
	CreateThread = {
		label = "Create Thread", color = Color3.fromRGB(210,180,255), params = {"element","width","color"},
		outputs = {"thread"}, inputs = {}
	},
	Weave = {
		label = "Weave", color = Color3.fromRGB(120,200,255), params = {"inputs"},
		inputs = {"thread"}, outputs = {"weave"}
	},
	Wrap = {
		label = "Wrap", color = Color3.fromRGB(80,255,180), params = {"threadIdx","targetNode","radius","spiralTurns","height","offset"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	Tween = {
		label = "Tween", color = Color3.fromRGB(240,220,128), params = {"threadIdx","targetParams","duration"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	Wait = {
		label = "Wait", color = Color3.fromRGB(160,160,160), params = {"duration"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	Delay = {
		label = "Delay", color = Color3.fromRGB(120,120,120), params = {"duration"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	SetColor = {
		label = "Set Color", color = Color3.fromRGB(255,210,90), params = {"threadIdx","color"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	Loop = {
		label = "Loop", color = Color3.fromRGB(190,220,160), params = {"count","targetNode"},
		inputs = {"thread"}, outputs = {"thread"}
	},
	PathNode = {
		label = "Path Node",
		color = Color3.fromRGB(120, 180, 255),
		params = {"Keypoints"},
		outputs = {"path"},
		inputs = {},
	}
}

-- Node categories for UI/logic
local BuilderNodes = {
	CreateThread = true,
	PathNode = true,
}
local ModifierNodes = {
	Weave = true,
	Wrap = true,
	Tween = true,
	Wait = true,
	Delay = true,
	SetColor = true,
	Loop = true,
}
NodeTypes.BuilderNodes = BuilderNodes
NodeTypes.ModifierNodes = ModifierNodes

return NodeTypes