--[[
	World — references to the static map (Workspace.Map) plus the runtime folders.
	Adds Russian signs and the proximity prompts of the sell stand and the seed shop.
]]

local World = {}

World.map = workspace:WaitForChild("Map")
World.Bounds = 262 -- creatures stay inside ±Bounds on X and Z
World.ForestCenter = Vector3.new(0, 0, -190)
World.SellStand = nil :: BasePart?
World.ShopStand = nil :: BasePart?

local function runtimeFolder(name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

World.Creatures = runtimeFolder("Creatures")
World.Pets = runtimeFolder("Pets")
World.Traps = runtimeFolder("Traps")
World.Crops = runtimeFolder("Crops")

local ZONE_SIGNS = {
	ZoneSignForest = "ЛЕС",
	ZoneSignGardens = "ГРЯДКИ",
	ZoneSignFieldsW = "ДИКИЕ ПОЛЯ",
	ZoneSignFieldsE = "ДИКИЕ ПОЛЯ",
}

-- Creates or updates a text sign that floats on a part and faces the camera.
function World.setSign(part: BasePart, text: string, color: Color3?, studsWide: number?)
	local gui = part:FindFirstChild("SignGui") :: BillboardGui?
	local label
	if gui then
		label = gui:FindFirstChild("Label") :: TextLabel
	else
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "SignGui"
		newGui.Size = UDim2.fromScale(studsWide or 10, 2.6)
		newGui.MaxDistance = 220
		newGui.LightInfluence = 0
		newGui.Adornee = part
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextStrokeTransparency = 0.2
		label.Parent = newGui
		newGui.Parent = part
	end
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 244, 214)
end

local function addPrompt(part: BasePart, name: string, objectText: string, actionText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.F -- E is reserved for catching
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

function World.init()
	local plaza = World.map:WaitForChild("Plaza")
	local sell = plaza:WaitForChild("SellStand") :: BasePart
	local shop = plaza:WaitForChild("ShopStand") :: BasePart
	World.SellStand = sell
	World.ShopStand = shop

	World.setSign(plaza:WaitForChild("SellSign") :: BasePart, "ПРОДАЖА УРОЖАЯ", Color3.fromRGB(255, 214, 90), 14)
	World.setSign(plaza:WaitForChild("ShopSign") :: BasePart, "МАГАЗИН СЕМЯН", Color3.fromRGB(150, 220, 255), 14)
	addPrompt(sell, "SellPrompt", "Прилавок", "Продать Урожай")
	addPrompt(shop, "ShopPrompt", "Магазин семян", "Открыть магазин")

	for _, sign in World.map:WaitForChild("Signs"):GetChildren() do
		local text = ZONE_SIGNS[sign.Name]
		if text and sign:IsA("BasePart") then
			World.setSign(sign, text)
		end
	end
end

return World
