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
	local data = HttpService:JSONEncode({nodes = self.nodes, connections = self.connections})
	plugin:SetSetting("ChoreoGraph", data)
end

function NodeGraph:LoadGraph()
	if not plugin then return end
	local data = plugin:GetSetting("ChoreoGraph")
	if data then
		local decoded = HttpService:JSONDecode(data)
		self.nodes = decoded.nodes or {}
		self.connections = decoded.connections or {}
		if self._hookRedraw then self._hookRedraw() end
	end
end

function NodeGraph:ExportGraph()
	local data = HttpService:JSONEncode({nodes = self.nodes, connections = self.connections})
	print("[ChoreoEditor] Copy this JSON to import later:\n" .. data)
end

function NodeGraph:ImportGraph()
	print("[ChoreoEditor] Paste your exported JSON string below and call NodeGraph:ImportGraphFromString(jsonString)")
end

function NodeGraph:ImportGraphFromString(jsonString)
	local ok, decoded = pcall(function() return HttpService:JSONDecode(jsonString) end)
	if ok and decoded then
		self.nodes = decoded.nodes or {}
		self.connections = decoded.connections or {}
		if self._hookRedraw then self._hookRedraw() end
	else
		warn("Failed to decode graph JSON.")
	end
end

function NodeGraph:AddNode(nodeType, params, pos)
	local node = {
		type = nodeType,
		params = params or {},
		pos = sanitizePos(pos),
		connections = {}
	}
	table.insert(self.nodes, node)
	return node, #self.nodes
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