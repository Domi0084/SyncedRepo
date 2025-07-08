-- Handles playback using your runtime system (stub for now)

local Playback = {}
Playback.__index = Playback

function Playback.new()
    local self = setmetatable({}, Playback)
    return self
end

function Playback:Play(graph)
    -- Traverse graph.nodes/connections and use ThreadSystem to play
    print("Playing choreography with", #graph.nodes, "nodes")
    -- Example: create threads for each node of type 'CreateThread'
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ThreadService = require(ReplicatedStorage.Synced.ThreadSystem.Services.ThreadService)
    local createdThreads = {}
    for idx, node in ipairs(graph.nodes) do
        if node.type == "CreateThread" then
            local threadParams = node.params
            local pathParams = node.params.Path or {} -- Optionally, allow path params in node
            local ThreadParams = require(ReplicatedStorage.Synced.ThreadSystem.Types.threadParams)
            local PathParams = require(ReplicatedStorage.Synced.ThreadSystem.Types.pathParams)
            local tParams = ThreadParams.new(threadParams)
            local pParams = PathParams.new(pathParams)
            local thread = ThreadService:CreateThread{Params = tParams, Path = pParams}
            table.insert(createdThreads, thread)
            thread:Start()
        end
    end
    -- TODO: handle other node types (Weave, MoveTo, etc.)
    self._createdThreads = createdThreads
end

function Playback:Stop()
    print("Stopping choreography preview")
    if self._createdThreads then
        for _, thread in ipairs(self._createdThreads) do
            if thread.Destroy then thread:Destroy() end
        end
        self._createdThreads = nil
    end
end

return Playback