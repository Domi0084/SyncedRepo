-- Handles playback using your runtime system (stub for now)

local Playback = {}
Playback.__index = Playback

function Playback.new()
    local self = setmetatable({}, Playback)
    return self
end

function Playback:Play(graph)
	if not graph or type(graph.nodes) ~= "table" then
		warn("[Playback] Invalid graph passed to Play.")
		return
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ok, ThreadService = pcall(function() return require(ReplicatedStorage.Synced.ThreadSystem.Services.ThreadService) end)
	if not ok or not ThreadService then
		warn("[Playback] Could not require ThreadService from ReplicatedStorage.")
		return
	end
	local createdThreads = {}
	for idx, node in ipairs(graph.nodes) do
		if node.type == "CreateThread" then
			local threadParams = node.params
			local pathParams = node.params.Path or {}
			local okT, ThreadParams = pcall(function() return require(ReplicatedStorage.Synced.ThreadSystem.Types.threadParams) end)
			local okP, PathParams = pcall(function() return require(ReplicatedStorage.Synced.ThreadSystem.Types.pathParams) end)
			if not okT or not okP or not ThreadParams or not PathParams then
				warn("[Playback] Could not require ThreadParams or PathParams.")
				continue
			end
			local tParams = ThreadParams.new(threadParams)
			local pParams = PathParams.new(pathParams)
			local thread = ThreadService:CreateThread{Params = tParams, Path = pParams}
			table.insert(createdThreads, thread)
			thread:Start()
		end
	end
	self._createdThreads = createdThreads
end

function Playback:Cleanup()
	if self._createdThreads then
		for _, thread in ipairs(self._createdThreads) do
			if thread.Destroy then thread:Destroy() end
		end
		self._createdThreads = nil
	end
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