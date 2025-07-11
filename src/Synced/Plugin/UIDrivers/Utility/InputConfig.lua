-- InputConfig.lua
-- Centralizes configuration for all input controls (mouse, keyboard, shortcuts) used in the NodeCanvas UI.

local InputConfig = {
	Mouse = {
		PanButton = Enum.UserInputType.MouseButton2,
		SelectButton = Enum.UserInputType.MouseButton1,
		ConnectionButton = Enum.UserInputType.MouseButton1,
		MarqueeButton = Enum.UserInputType.MouseButton1,
		Wheel = Enum.UserInputType.MouseWheel,
	},
	Keyboard = {
		Delete = Enum.KeyCode.Delete,
		Duplicate = Enum.KeyCode.D,
		MultiSelect = Enum.KeyCode.LeftControl,
		Undo = Enum.KeyCode.Z,
		Redo = Enum.KeyCode.Y,
		Export = Enum.KeyCode.E,
		Import = Enum.KeyCode.I,
	},
	Shortcuts = {
		-- Example: {key = Enum.KeyCode.S, ctrl = true, action = "Save"}
	},
}

return InputConfig
