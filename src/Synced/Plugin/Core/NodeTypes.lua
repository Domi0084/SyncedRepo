-- Defines available node types and their properties
-- Updated for strict typing, structured params, enums, and unique Path IDs

local NodeTypes = {}

-- Utility for unique Path IDs
do
    local pathIdCounter = 0
    function NodeTypes.GeneratePathId()
        pathIdCounter = pathIdCounter + 1
        return "Path_" .. tostring(pathIdCounter)
    end
end

-- Node definitions
NodeTypes.Definitions = {
    -- Input/Start Nodes
    StartChoreography = {
        label = "Start Choreography",
        color = Color3.fromRGB(100, 200, 100),
        category = "Input",
        params = {},
        outputs = {{name = "sequence", type = "Sequence"}},
        inputs = {},
    },
    CreateThread = {
        label = "Create Thread",
        color = Color3.fromRGB(210, 180, 255),
        category = "Input",
        params = {
            {name = "color", type = "Color", label = "Color", default = Color3.new(1,1,1)},
            {name = "width", type = "Number", label = "Width", default = 1},
            {name = "threadId", type = "Text", label = "Thread ID", default = ""},
        },
        outputs = {
            {name = "sequence", type = "Sequence"},
            {name = "thread", type = "Thread"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
        },
    },
    -- Movement/Transformation Nodes
    MoveAlongPath = {
        label = "Move Along Path",
        color = Color3.fromRGB(80, 180, 255), -- zmieniony kolor
        category = "Transformation",
        params = {
            {name = "speed", type = "Number", label = "Speed", default = 1},
        },
        outputs = {
            {name = "sequence", type = "Sequence"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
            {name = "path", type = "Path"},
            {name = "speed", type = "Number"},
            {name = "thread", type = "Thread", multi = true}, -- multiport
        },
    },
    -- Appearance Nodes
    SetThreadColor = {
        label = "Set Thread Color",
        color = Color3.fromRGB(255, 120, 120), -- zmieniony kolor
        category = "Appearance",
        params = {
            {name = "color", type = "Color", label = "Color", default = Color3.new(1,1,1)},
        },
        outputs = {
            {name = "sequence", type = "Sequence"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
            {name = "color", type = "Color"},
            {name = "thread", type = "Thread", optional = true},
        },
    },
    SetThreadIntensity = {
        label = "Set Thread Intensity",
        color = Color3.fromRGB(255, 200, 80), -- zmieniony kolor
        category = "Appearance",
        params = {
            {name = "intensity", type = "Number", label = "Intensity", default = 1},
        },
        outputs = {
            {name = "sequence", type = "Sequence"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
            {name = "intensity", type = "Number"},
            {name = "thread", type = "Thread", optional = true},
        },
    },
    -- Logic/Control Flow Nodes
    Delay = {
        label = "Delay",
        color = Color3.fromRGB(255, 220, 120), -- zmieniony kolor
        category = "Logic",
        params = {
            {name = "time", type = "Number", label = "Time (s)", default = 1},
        },
        outputs = {
            {name = "sequence", type = "Sequence"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
            {name = "time", type = "Number"},
        },
    },
    Sequence = {
        label = "Sequence",
        color = Color3.fromRGB(120, 200, 255), -- zmieniony kolor
        category = "Logic",
        params = {
            {name = "outputCount", type = "Number", label = "Outputs", default = 2, min = 2, dynamic = true},
        },
        outputs = {
            {name = "sequence1", type = "Sequence"},
            {name = "sequence2", type = "Sequence"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
        },
    },
    Tween = {
        label = "Tween",
        color = Color3.fromRGB(180, 120, 255), -- zmieniony kolor
        category = "Logic",
        params = {
            {name = "interpolationStyle", type = "Enum", label = "Interpolation Style", default = "Linear", values = {"Linear", "EaseInQuad", "EaseOutQuad", "EaseInOutQuad"}},
        },
        outputs = {
            {name = "sequence", type = "Sequence"},
            {name = "interpolatedValue", type = "NumberOrColor"},
        },
        inputs = {
            {name = "sequence", type = "Sequence"},
            {name = "startValue", type = "NumberOrColor"},
            {name = "endValue", type = "NumberOrColor"},
            {name = "duration", type = "Number"},
        },
    },
    -- Utility Nodes
    Path = {
        label = "Path",
        color = Color3.fromRGB(80, 255, 180), -- zmieniony kolor
        category = "Utility",
        params = {
            {name = "actionPoints", type = "ActionPoints", label = "Action Points"},
            {name = "id", type = "Text", label = "Path ID", readonly = true},
        },
        outputs = {
            {name = "path", type = "Path"},
        },
        inputs = {},
        assignId = function(self)
            self.params[2].default = NodeTypes.GeneratePathId()
        end
    },
}

-- Strict connection compatibility
NodeTypes.ConnectionRules = {
    Sequence = {"Sequence"},
    Number = {"Number", "Speed", "Intensity", "Time", "Duration"},
    Vector3D = {"Vector3D"},
    Color = {"Color", "StartValue", "EndValue"},
    CFrame = {"CFrame"},
    Path = {"Path"},
    Thread = {"Thread"},
    NumberOrColor = {"Number", "Color", "StartValue", "EndValue"},
    Speed = {"Speed"},
    Intensity = {"Intensity"},
    Time = {"Time"},
    Duration = {"Duration"},
    StartValue = {"StartValue"},
    EndValue = {"EndValue"},
    ActionPoints = {"ActionPoints"},
}

function NodeTypes.IsConnectionValid(fromType, toType)
    local allowed = NodeTypes.ConnectionRules[fromType]
    if not allowed then return false end
    for _, t in ipairs(allowed) do
        if t == toType then return true end
    end
    return false
end

-- Utility to build category maps for TopBar
function NodeTypes.GetCategoryMap()
    local map = {
        Input = {},
        Transformation = {},
        Appearance = {},
        Logic = {},
        Utility = {},
    }
    for name, def in pairs(NodeTypes.Definitions) do
        if def.category and map[def.category] then
            map[def.category][name] = def
        end
    end
    return map
end

-- Defensive: Validate node definitions
function NodeTypes.ValidateDefinitions()
	for name, def in pairs(NodeTypes.Definitions) do
		assert(def.label, "NodeType '"..name.."' missing label")
		assert(def.category, "NodeType '"..name.."' missing category")
		assert(def.outputs, "NodeType '"..name.."' missing outputs")
		assert(def.inputs, "NodeType '"..name.."' missing inputs")
	end
end

return NodeTypes