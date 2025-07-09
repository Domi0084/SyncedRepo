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
    local sequenceFlow = {}
    
    -- First pass: create input nodes (StartChoreography, CreateThread)
    for idx, node in ipairs(choreoTable.nodes) do
        if node.type == "StartChoreography" then
            -- Mark as starting point for sequence flow
            sequenceFlow[idx] = true
        elseif node.type == "CreateThread" then
            local tParams = ThreadParams.new(node.params)
            local pParams = PathParams.new(node.params.Path or {})
            local thread = ThreadService:CreateThread{Params = tParams, Path = pParams}
            nodeMap[idx] = thread
            table.insert(self.activeThreads, thread)
            thread:Start()
        end
    end
    
    -- Second pass: process transformation, appearance, and logic nodes
    for idx, node in ipairs(choreoTable.nodes) do
        if node.type == "MoveAlongPath" then
            -- Handle move along path logic
            local targetIdx = node.params.threadIdx
            local thread = nodeMap[targetIdx]
            if thread and thread.MoveAlongPath then
                thread:MoveAlongPath(node.params)
            end
        elseif node.type == "SetThreadColor" then
            local targetIdx = node.params.threadIdx
            local thread = nodeMap[targetIdx]
            if thread and thread.SetColor then
                thread:SetColor(node.params.color)
            end
        elseif node.type == "SetThreadIntensity" then
            local targetIdx = node.params.threadIdx
            local thread = nodeMap[targetIdx]
            if thread and thread.SetIntensity then
                thread:SetIntensity(node.params.intensity)
            end
        elseif node.type == "Delay" then
            -- Handle delay logic
            if node.params.time then
                wait(node.params.time)
            end
        elseif node.type == "Tween" then
            local targetIdx = node.params.threadIdx
            local thread = nodeMap[targetIdx]
            if thread and thread.Tween then
                thread:Tween(node.params)
            end
        end
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
