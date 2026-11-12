--[[
	PlotService — garden plots: ownership, soil slots, planting and harvesting.
	Growth itself is driven by GrowthService; this module owns the slot state and visuals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local SOIL_COLOR = Color3.fromRGB(106, 72, 48)
local LOCKED_COLOR = Color3.fromRGB(74, 70, 66)
local TOTAL_SLOTS = Config.BaseSlots + Config.ExpansionSlots

local PlotService = {}
PlotService.plots = {} -- array of plot tables
local plotByPlayer = {}

-- ---------------------------------------------------------------- slot visuals
local function updateSlot(plot, slot)
	local state
	if not plot.owner then
		state = "free"
	elseif slot.index > plot.unlocked then
		state = "locked"
	elseif not slot.crop then
		state = "empty"
	elseif slot.crop.stage < 3 then
		state = "growing"
	else
		state = "ripe"
	end
	slot.prompt:SetAttribute("State", state)
	slot.prompt.Enabled = state == "empty" or state == "ripe"
	slot.prompt.ActionText = state == "ripe" and "Собрать" or "Посадить"
	slot.part.Color = (state == "locked" or state == "free") and LOCKED_COLOR or SOIL_COLOR
end

function PlotService.setStage(plot, slot, stage: number)
	local crop = slot.crop
	if not crop then
		return
	end
	crop.stage = stage
	local seed = GameData.Seeds[crop.seedId]
	local part = crop.part
	if stage == 1 then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(0.6, 1.2, 0.6)
		part.Color = Color3.fromRGB(110, 200, 90)
	elseif stage == 2 then
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(1.3, 2.4, 1.3)
		part.Color = Color3.fromRGB(70, 160, 70)
	else
		part.Shape = (Enum.PartType :: any)[seed.head.shape]
		part.Size = seed.head.size * 1.15
		part.Color = seed.head.color
	end
	local top = slot.part.Position.Y + slot.part.Size.Y / 2
	part.Position = Vector3.new(slot.part.Position.X, top + part.Size.Y / 2, slot.part.Position.Z)
	updateSlot(plot, slot)
end

local function createCrop(plot, slot, seedId: string)
	local seed = GameData.Seeds[seedId]
	local part = Instance.new("Part")
	part.Name = "Crop"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 40)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = GameData.Rarities[seed.rarity].color
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = gui
	gui.Parent = part

	slot.crop = {
		seedId = seedId,
		growTime = seed.growTime,
		progress = 0, -- seconds grown so far
		stage = 0,
		nextRoll = 0,
		part = part,
		label = label,
	}
	PlotService.setStage(plot, slot, 1)
	part.Parent = World.Crops
end

function PlotService.removeCrop(plot, slot)
	if slot.crop then
		slot.crop.part:Destroy()
		slot.crop = nil
	end
	updateSlot(plot, slot)
end

function PlotService.clearCrops(plot)
	for _, slot in plot.slots do
		PlotService.removeCrop(plot, slot)
	end
end

function PlotService.cropCount(plot): number
	local count = 0
	for _, slot in plot.slots do
		if slot.crop then
			count += 1
		end
	end
	return count
end

-- ---------------------------------------------------------------- ownership
function PlotService.getPlot(player: Player)
	return plotByPlayer[player]
end

function PlotService.setFence(plot, enabled: boolean)
	for _, rail in plot.model.Fence:GetChildren() do
		if rail:IsA("BasePart") then
			rail.Transparency = enabled and 0 or 1
		end
	end
end

-- Re-reads the owner's profile: unlocked slots and fence.
function PlotService.refresh(plot)
	local profile = plot.owner and PlayerData.get(plot.owner)
	plot.unlocked = Config.BaseSlots + ((profile and profile.data.expanded) and Config.ExpansionSlots or 0)
	PlotService.setFence(plot, profile ~= nil and profile.data.upgrades.fence)
	for _, slot in plot.slots do
		updateSlot(plot, slot)
	end
end

local function teleportToPlot(plot, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		task.wait(0.1)
		character:PivotTo(CFrame.new(plot.entrance + Vector3.new(0, 4, -3)) * CFrame.Angles(0, math.pi, 0))
	end
end

local function assign(player: Player, profile)
	for _, plot in PlotService.plots do
		if not plot.owner then
			plot.owner = player
			plotByPlayer[player] = plot
			profile.plotId = plot.id
			plot.model:SetAttribute("OwnerId", player.UserId)
			for _, slot in plot.slots do
				slot.prompt:SetAttribute("OwnerId", player.UserId)
			end
			World.setSign(plot.sign, "Грядка: " .. player.DisplayName, Color3.fromRGB(255, 232, 150), 12)
			PlotService.refresh(plot)

			plot.characterConnection = player.CharacterAdded:Connect(function(character)
				teleportToPlot(plot, character)
			end)
			if player.Character then
				task.spawn(teleportToPlot, plot, player.Character)
			end
			PlayerData.notify(player, string.format("Твоя грядка №%d. Выбери семя внизу и нажми F у земли.", plot.id), "info")
			return
		end
	end
	PlayerData.notify(player, "Свободных грядок нет. Можно ловить чужой сбежавший урожай!", "bad")
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	if plot.characterConnection then
		plot.characterConnection:Disconnect()
		plot.characterConnection = nil
	end
	PlotService.clearCrops(plot)
	plot.owner = nil
	plot.model:SetAttribute("OwnerId", 0)
	for _, slot in plot.slots do
		slot.prompt:SetAttribute("OwnerId", 0)
	end
	World.setSign(plot.sign, "Свободная грядка", Color3.fromRGB(200, 200, 200), 12)
	PlotService.refresh(plot)
end

-- ---------------------------------------------------------------- remotes
local function plant(player: Player, index: any, seedId: any)
	if not AntiExploit.isInt(index, 1, TOTAL_SLOTS) or not AntiExploit.isId(seedId, GameData.Seeds) then
		return
	end
	local plot = plotByPlayer[player]
	local profile = PlayerData.get(player)
	if not plot or not profile then
		return
	end
	local slot = plot.slots[index]
	if index > plot.unlocked then
		PlayerData.notify(player, "Эта лунка откроется после «Расширения».", "bad")
		return
	end
	if slot.crop or not AntiExploit.distanceOk(player, slot.part.Position, Config.PlantDistance) then
		return
	end
	local count = profile.data.seeds[seedId] or 0
	if count < 1 then
		PlayerData.notify(player, "Нет таких семян. Загляни в магазин.", "bad")
		return
	end
	profile.data.seeds[seedId] = count - 1
	PlayerData.markDirty(player)
	createCrop(plot, slot, seedId)
	Remotes.Effect:FireClient(player, "sound", "plant")
end

local function harvest(player: Player, index: any)
	if not AntiExploit.isInt(index, 1, TOTAL_SLOTS) then
		return
	end
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	local slot = plot.slots[index]
	local crop = slot.crop
	if not crop or crop.stage < 3 or not AntiExploit.distanceOk(player, slot.part.Position, Config.PlantDistance) then
		return
	end
	if not PlayerData.addItem(player, crop.seedId, nil, 0) then
		PlayerData.notify(player, "Инвентарь полон! Сначала продай урожай.", "bad")
		return
	end
	PlotService.removeCrop(plot, slot)
	Remotes.Effect:FireClient(player, "sound", "grow")
	PlayerData.notify(player, "Собрано: " .. GameData.itemName(crop.seedId, nil), "good")
end

function PlotService.init()
	local folder = World.map:WaitForChild("Plots")
	local index = 1
	while folder:FindFirstChild("Plot" .. index) do
		local model = folder:FindFirstChild("Plot" .. index) :: any
		local base = model.Base :: BasePart
		local half = base.Size / 2
		local plot = {
			id = index,
			model = model,
			sign = model.Sign :: BasePart,
			entrance = (model.Entrance :: BasePart).Position,
			minX = base.Position.X - half.X,
			maxX = base.Position.X + half.X,
			minZ = base.Position.Z - half.Z,
			maxZ = base.Position.Z + half.Z,
			owner = nil :: Player?,
			unlocked = Config.BaseSlots,
			slots = {},
			characterConnection = nil :: RBXScriptConnection?,
		}
		for slotIndex = 1, TOTAL_SLOTS do
			local part = model.Slots:FindFirstChild("Slot" .. slotIndex) :: BasePart
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "SlotPrompt"
			prompt.ObjectText = "Грядка"
			prompt.ActionText = "Посадить"
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("SlotIndex", slotIndex)
			prompt:SetAttribute("OwnerId", 0)
			prompt.Parent = part
			plot.slots[slotIndex] = { index = slotIndex, part = part, prompt = prompt, crop = nil }
		end
		World.setSign(plot.sign, "Свободная грядка", Color3.fromRGB(200, 200, 200), 12)
		table.insert(PlotService.plots, plot)
		PlotService.refresh(plot)
		index += 1
	end

	PlayerData.onLoaded(assign)
	PlayerData.onLeaving(release)
	AntiExploit.connect(Remotes.Plant, 4, 8, plant)
	AntiExploit.connect(Remotes.Harvest, 4, 8, harvest)
end

return PlotService
