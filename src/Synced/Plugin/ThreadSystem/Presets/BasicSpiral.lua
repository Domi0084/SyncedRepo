-- BasicSpiral.lua
-- Sample preset choreography for quick testing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThreadParams = require(ReplicatedStorage.Synced.ThreadSystem.Types.threadParams)
local PathParams = require(ReplicatedStorage.Synced.ThreadSystem.Types.pathParams)

local preset = {}

function preset.create()
	local tParams = ThreadParams.new()
	tParams.element = "Air"
	tParams.width = 1

	local pParams = PathParams.new()
	pParams.Mode = "Spiral"
	pParams.SpiralCount = 2

	return {
		Params = tParams,
		Path = pParams,
	}
end

return preset
