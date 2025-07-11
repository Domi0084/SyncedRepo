-- Stores and manages the node graph structure

local NodeGraph = {}
NodeGraph.__index = NodeGraph

-- Helper: always ensure node positions are UDim2 (never Vector3/Vector2)
local function sanitizePos(pos)
	if typeof(pos) == "Vector3" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "Vector2" then
		return UDim2.new(0, pos.X, 0, pos.Y)
	elseif typeof(pos) == "UDim2" then
		return pos
	end
	return UDim2.new(0, 0, 0, 0)
end

local HttpService = game:GetService("HttpService")
local plugin = getfenv(0).plugin or nil -- Only available in plugin context

function NodeGraph.new()
	local self = setmetatable({}, NodeGraph)
	self.nodes = {}
	self.connections = {}
	self.choreographyName = "Untitled Choreography"
	self._undoStack = {}
	self._redoStack = {}
	return self
end

local function deepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function NodeGraph:PushUndo()
	table.insert(self._undoStack, {nodes = deepCopy(self.nodes), connections = deepCopy(self.connections)})
	self._redoStack = {}
end

function NodeGraph:Undo()
	if #self._undoStack > 0 then
		table.insert(self._redoStack, {nodes = deepCopy(self.nodes), connections = deepCopy(self.connections)})
		local last = table.remove(self._undoStack)
		self.nodes = deepCopy(last.nodes)
		self.connections = deepCopy(last.connections)
		if self._hookRedraw then self._hookRedraw() end
	end
end

function NodeGraph:Redo()
	if #self._redoStack > 0 then
		table.insert(self._undoStack, {nodes = deepCopy(self.nodes), connections = deepCopy(self.connections)})
		local nextState = table.remove(self._redoStack)
		self.nodes = deepCopy(nextState.nodes)
		self.connections = deepCopy(nextState.connections)
		if self._hookRedraw then self._hookRedraw() end
	end
end

function NodeGraph:SaveGraph()
	if not plugin then return end
	local data = HttpService:JSONEncode({
		choreographyName = self.choreographyName,
		nodes = self.nodes, 
		connections = self.connections
	})
	plugin:SetSetting("ChoreoGraph", data)
end

function NodeGraph:LoadGraph()
	if not plugin then return end
	local data = plugin:GetSetting("ChoreoGraph")
	if data then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(data) end)
		if not ok or type(decoded) ~= "table" then
			warn("[NodeGraph] Failed to decode saved graph data.")
			return
		end
		self.choreographyName = decoded.choreographyName or "Untitled Choreography"
		self.nodes = type(decoded.nodes) == "table" and decoded.nodes or {}
		self.connections = type(decoded.connections) == "table" and decoded.connections or {}
		if self._hookRedraw then self._hookRedraw() end
	end
end

function NodeGraph:Clear()
	self.nodes = {}
	self.connections = {}
	self.choreographyName = "Untitled Choreography"
	self._undoStack = {}
	self._redoStack = {}
	if self._hookRedraw then self._hookRedraw() end
end

-- Remove all JSON/CSV export logic and replace with table-based export/import

function NodeGraph:ExportGraphTable()
	return {
		choreographyName = self.choreographyName,
		nodes = deepCopy(self.nodes),
		connections = deepCopy(self.connections)
	}
end

function NodeGraph:ImportGraphTable(tbl)
	if type(tbl) ~= "table" then warn("[NodeGraph] Import failed: not a table") return end
	self.choreographyName = tbl.choreographyName or "Untitled Choreography"
	self.nodes = type(tbl.nodes) == "table" and tbl.nodes or {}
	self.connections = type(tbl.connections) == "table" and tbl.connections or {}
	-- Defensive: validate node structure
	for _, node in ipairs(self.nodes) do
		node.id = node.id or HttpService:GenerateGUID()
		node.pos = sanitizePos(node.pos)
		node.params = node.params or {}
		node.connections = node.connections or {}
	end
	if self._hookRedraw then self._hookRedraw() end
end

function NodeGraph:ExportGraph()
	local exportTable = self:ExportGraphTable()
	local HttpService = game:GetService("HttpService")
	local json = ""
	local ok, result = pcall(function()
		json = HttpService:JSONEncode(exportTable)
	end)
	if ok then
		-- Zamiast printować, twórz nowy ModuleScript
		local exportFolder = game:GetService("ServerStorage"):FindFirstChild("ExportedChoreography")
		if not exportFolder then
			exportFolder = Instance.new("Folder")
			exportFolder.Name = "ExportedChoreography"
			exportFolder.Parent = game:GetService("ServerStorage")
		end
		local moduleName = "Choreography_" .. tostring(os.time())
		local module = Instance.new("ModuleScript")
		module.Name = moduleName
		module.Source = "return " .. json
		module.Parent = exportFolder
		print("[ChoreoEditor] Exported to ModuleScript: ServerStorage/ExportedChoreography/" .. moduleName)
	else
		warn("[ChoreoEditor] Export failed!")
	end
	return exportTable
end

function NodeGraph:SetChoreographyName(name)
	self.choreographyName = name or "Untitled Choreography"
end

function NodeGraph:GetChoreographyName()
	return self.choreographyName
end

function NodeGraph:AddNode(nodeType, params, pos)
	local node = {
		type = nodeType,
		params = params or {},
		pos = sanitizePos(pos),
		connections = {},
		id = HttpService:GenerateGUID(), -- Assign unique ID to all nodes
	}
	-- For Path nodes, keep legacy id field for compatibility
	if nodeType == "Path" then
		node.pathId = node.id
	end
	table.insert(self.nodes, node)
	return node, #self.nodes
end

-- Get node by unique ID
function NodeGraph:GetNodeById(id)
	for _, node in ipairs(self.nodes) do
		if node.id == id or node.pathId == id then return node end
	end
	return nil
end

function NodeGraph:RemoveNode(idx)
	table.remove(self.nodes, idx)
	-- remove all connections to/from
	for i=#self.connections,1,-1 do
		if self.connections[i].from == idx or self.connections[i].to == idx then
			table.remove(self.connections, i)
		end
	end
end

function NodeGraph:AddConnection(fromIdx, toIdx)
	table.insert(self.connections, {from=fromIdx, to=toIdx})
end

return NodeGraph