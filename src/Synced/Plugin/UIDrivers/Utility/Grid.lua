-- Grid.lua
-- Draws a background grid on the canvas, adjusting for zoom and offset, to help users align nodes visually.

local Grid = {}
Grid.__index = Grid

function Grid.new(canvas, state)
	local self = setmetatable({}, Grid)
	self.canvas = canvas
	self.state = state
	return self
end

function Grid:draw()
	local offset = self.state.offset
	local zoom = self.state.zoom
	local canvas = self.canvas
	local GRID_TEXTURE = self.state.GRID_TEXTURE

	local gridLayer = canvas:FindFirstChild("GridLayer")
	if gridLayer then gridLayer:Destroy() end
	gridLayer = Instance.new("Frame")
	gridLayer.Name = "GridLayer"
	gridLayer.BackgroundTransparency = 1
	gridLayer.Size = UDim2.new(1,0,1,0)
	gridLayer.ZIndex = 1
	gridLayer.Parent = canvas

	local gridSpacing = 32 * zoom
	local width = math.ceil(canvas.AbsoluteSize.X)
	local height = math.ceil(canvas.AbsoluteSize.Y)

	local offsetX = offset.X % gridSpacing
	local offsetY = offset.Y % gridSpacing

	local gridImage = Instance.new("ImageLabel")
	gridImage.Name = "GridImage"
	gridImage.BackgroundTransparency = 1
	gridImage.Image = GRID_TEXTURE
	gridImage.ImageColor3 = Color3.new(0,0,0)
	gridImage.ImageTransparency = 0.5
	gridImage.Size = UDim2.new(0, width + gridSpacing, 0, height + gridSpacing)
	gridImage.Position = UDim2.new(0, -offsetX, 0, -offsetY)
	gridImage.ZIndex = 1
	gridImage.ScaleType = Enum.ScaleType.Tile
	gridImage.TileSize = UDim2.new(0, gridSpacing, 0, gridSpacing)
	gridImage.Parent = gridLayer
end

return Grid
