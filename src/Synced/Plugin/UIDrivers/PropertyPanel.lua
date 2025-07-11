-- PropertyPanel.lua
-- Refaktoryzacja: tylko operacje na gotowym UI PropertyPanel

local PropertyPanel = {}
PropertyPanel.__index = PropertyPanel

-- Znajduje instancję PropertyPanel w pluginUI
function PropertyPanel.GetPropertyPanel(pluginUI)
	return pluginUI:FindFirstChild("PropertyPanel")
end

-- Inicjalizuje instancję PropertyPanel, łącząc logikę z interfejsem użytkownika
function PropertyPanel.init(propertyPanelInstance, nodeGraph)
	if not propertyPanelInstance then return end
	local display = propertyPanelInstance:FindFirstChild("Display")
	if not display then return end
	for _, field in ipairs(display:GetChildren()) do
		if field:FindFirstChild("Display") and field.Display:FindFirstChild("TextBox") then
			field.Display.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
				if nodeGraph and nodeGraph.SetProperty then
					nodeGraph:SetProperty(field.Name, field.Display.TextBox.Text)
				end
			end)
		end
	end
end

-- Ustawia wartość pola w interfejsie użytkownika PropertyPanel
function PropertyPanel.SetFieldValue(propertyPanelInstance, fieldName, value)
	local display = propertyPanelInstance:FindFirstChild("Display")
	if not display then return end
	local field = display:FindFirstChild(fieldName)
	if field and field:FindFirstChild("Display") and field.Display:FindFirstChild("TextBox") then
		field.Display.TextBox.Text = value
	end
end

-- Pobiera wartość pola z interfejsu użytkownika PropertyPanel
function PropertyPanel.GetFieldValue(propertyPanelInstance, fieldName)
	local display = propertyPanelInstance:FindFirstChild("Display")
	if not display then return nil end
	local field = display:FindFirstChild(fieldName)
	if field and field:FindFirstChild("Display") and field.Display:FindFirstChild("TextBox") then
		return field.Display.TextBox.Text
	end
	return nil
end

return PropertyPanel
