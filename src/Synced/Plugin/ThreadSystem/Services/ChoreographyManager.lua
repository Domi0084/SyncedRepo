-- ChoreographyManager.lua
-- Interprets a choreography table and commands the ThreadSystem

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThreadService = require(ReplicatedStorage.Synced.ThreadSystem.Services.ThreadService)
local WeaveService = require(ReplicatedStorage.Synced.ThreadSystem.Services.WeaveService)
local ThreadParams = require(ReplicatedStorage.Synced.ThreadSystem.Types.threadParams)
local PathParams = require(ReplicatedStorage.Synced.ThreadSystem.Types.pathParams)

local ChoreographyManager = {}
ChoreographyManager.__index = ChoreographyManager

function ChoreographyManager.new()
    local self = setmetatable({}, ChoreographyManager)
    self.activeThreads = {}
    self.activeWeaves = {}
    return self
end

-- Interprets a choreography table (from plugin)
function ChoreographyManager:PlayChoreography(choreoTable)
    self:Cleanup()
    local nodeMap = {}
    -- First pass: create builder nodes (threads, weaves, etc)
    for idx, node in ipairs(choreoTable.nodes) do
        if node.type == "CreateThread" then
            local tParams = ThreadParams.new(node.params)
            local pParams = PathParams.new(node.params.Path or {})
            local thread = ThreadService:CreateThread{Params = tParams, Path = pParams}
            nodeMap[idx] = thread
            table.insert(self.activeThreads, thread)
            thread:Start()
        elseif node.type == "Weave" then
            -- Example: combine threads from input nodes
            local inputThreads = {}
            for _, inputIdx in ipairs(node.params.inputs or {}) do
                if nodeMap[inputIdx] then table.insert(inputThreads, nodeMap[inputIdx]) end
            end
            local weave = WeaveService:Weave(inputThreads)
            nodeMap[idx] = weave
            table.insert(self.activeWeaves, weave)
        end
        -- Add more builder node types as needed
    end
    -- Second pass: apply modifier nodes (tween, color, etc)
    for idx, node in ipairs(choreoTable.nodes) do
        if node.type == "Tween" then
            local targetIdx = node.params.threadIdx
            local thread = nodeMap[targetIdx]
            if thread and thread.Tween then
                thread:Tween(node.params)
            end
        end
        -- Add more modifier node types as needed
    end
end

function ChoreographyManager:Cleanup()
    for _, thread in ipairs(self.activeThreads) do
        if thread.Destroy then thread:Destroy() end
    end
    for _, weave in ipairs(self.activeWeaves) do
        if weave.Destroy then weave:Destroy() end
    end
    self.activeThreads = {}
    self.activeWeaves = {}
end

return ChoreographyManager
