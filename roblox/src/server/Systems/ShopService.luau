--[[
	ShopService — everything bought with money: seeds, base defense (Забор, Липкая Ловушка,
	Свисток), Расширение, pets and Перерождение. Also handles trap placement and the whistle.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)
local CreatureService = require(script.Parent.CreatureService)
local PetService = require(script.Parent.PetService)
local PlayerData = require(script.Parent.PlayerData)
local PlotService = require(script.Parent.PlotService)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local ShopService = {}

local function noMoney(player: Player)
	PlayerData.notify(player, "Не хватает денег.", "bad")
	Remotes.Effect:FireClient(player, "sound", "error")
end

local function bought(player: Player, text: string)
	PlayerData.notify(player, text, "good")
	Remotes.Effect:FireClient(player, "sound", "click")
end

-- ---------------------------------------------------------------- purchases
local function buySeed(player: Player, profile, seedId: any, amount: any)
	if not AntiExploit.isId(seedId, GameData.Seeds) or not AntiExploit.isInt(amount, 1, 50) then
		return
	end
	local seed = GameData.Seeds[seedId]
	local data = profile.data
	if seed.requiresRebirth and data.rebirths < seed.requiresRebirth then
		PlayerData.notify(player, "Это семя открывается после Перерождения.", "bad")
		return
	end
	local owned = data.seeds[seedId] or 0
	if owned + amount > Config.MaxSeedStack then
		PlayerData.notify(player, "Столько семян не унести.", "bad")
		return
	end
	if not PlayerData.spend(player, seed.price * amount) then
		noMoney(player)
		return
	end
	data.seeds[seedId] = owned + amount
	bought(player, string.format("Куплено: %s x%d", seed.name, amount))
end

local function buyUpgrade(player: Player, profile, id: any)
	local data = profile.data
	local plot = PlotService.getPlot(player)

	if id == "expansion" then
		if data.expanded then
			return
		end
		if data.money < Config.ExpansionRequirement then
			PlayerData.notify(player, "Расширение откроется, когда накопишь "
				.. GameData.formatMoney(Config.ExpansionRequirement) .. ".", "bad")
			return
		end
		if not PlayerData.spend(player, Config.ExpansionRequirement) then
			return
		end
		data.expanded = true
		if plot then
			PlotService.refresh(plot)
		end
		bought(player, "Расширение куплено: +6 лунок и место для питомца!")
		return
	end

	if not AntiExploit.isId(id, GameData.Upgrades) then
		return
	end
	local upgrade = GameData.Upgrades[id]
	if id == "trap" then
		if data.upgrades.traps >= Config.MaxTraps then
			PlayerData.notify(player, "Больше ловушек не унести.", "bad")
			return
		end
		if not PlayerData.spend(player, upgrade.price) then
			noMoney(player)
			return
		end
		data.upgrades.traps += 1
		bought(player, "Куплена «Липкая Ловушка». Поставь её клавишей T.")
		return
	end

	if data.upgrades[id] then
		return
	end
	if not PlayerData.spend(player, upgrade.price) then
		noMoney(player)
		return
	end
	data.upgrades[id] = true
	if id == "fence" and plot then
		PlotService.refresh(plot)
	end
	bought(player, "Куплено: «" .. upgrade.name .. "»")
end

local function buyPet(player: Player, profile, petId: any)
	if not AntiExploit.isId(petId, GameData.Pets) then
		return
	end
	local data = profile.data
	if not data.expanded then
		PlayerData.notify(player, "Место для питомца появляется после «Расширения».", "bad")
		return
	end
	if data.pets[petId] then
		return
	end
	local pet = GameData.Pets[petId]
	if not PlayerData.spend(player, pet.price) then
		noMoney(player)
		return
	end
	data.pets[petId] = true
	data.pet = petId
	PetService.refresh(player)
	bought(player, "Новый питомец: " .. pet.name .. "!")
end

local function onBuy(player: Player, kind: any, id: any, amount: any)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if kind == "seed" then
		buySeed(player, profile, id, amount)
	elseif kind == "upgrade" then
		buyUpgrade(player, profile, id)
	elseif kind == "pet" then
		buyPet(player, profile, id)
	end
end

local function onEquipPet(player: Player, petId: any)
	local profile = PlayerData.get(player)
	if not profile or not AntiExploit.isId(petId, GameData.Pets) or not profile.data.pets[petId] then
		return
	end
	if profile.data.pet ~= petId then
		profile.data.pet = petId
		PlayerData.markDirty(player)
		PetService.refresh(player)
	end
end

-- ---------------------------------------------------------------- trap & whistle
-- The trap is always placed at the player's own feet: the client sends no position.
local function onPlaceTrap(player: Player)
	local profile = PlayerData.get(player)
	local root = AntiExploit.getRoot(player)
	if not profile or not root then
		return
	end
	local existing = CreatureService.traps[player.UserId]
	if not existing and profile.data.upgrades.traps < 1 then
		PlayerData.notify(player, "Ловушек нет. Купи «Липкую Ловушку» в улучшениях.", "bad")
		return
	end
	local position = Vector3.new(
		math.clamp(root.Position.X, -World.Bounds, World.Bounds), 0,
		math.clamp(root.Position.Z, -World.Bounds, World.Bounds))
	if existing then
		existing.part:Destroy() -- moving an already placed trap is free
	else
		profile.data.upgrades.traps -= 1
	end

	local part = Instance.new("Part")
	part.Name = "StickyTrap"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, Config.TrapRadius * 2, Config.TrapRadius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = Color3.fromRGB(230, 220, 70)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = World.Traps
	World.setSign(part, "Ловушка: " .. player.DisplayName, Color3.fromRGB(255, 240, 120), 9)

	CreatureService.traps[player.UserId] = { part = part, position = position, ownerId = player.UserId }
	profile.trapPlaced = true
	PlayerData.markDirty(player)
	Remotes.Effect:FireClient(player, "sound", "trap")
	PlayerData.notify(player, "Ловушка поставлена. Первый урожай, который наступит, прилипнет.", "good")
end

local function onWhistle(player: Player)
	local profile = PlayerData.get(player)
	local plot = PlotService.getPlot(player)
	if not profile or not plot then
		return
	end
	if not profile.data.upgrades.whistle then
		PlayerData.notify(player, "Сначала купи «Свисток» в улучшениях.", "bad")
		return
	end
	local now = os.clock()
	if now < profile.whistleReadyAt then
		PlayerData.notify(player, string.format("Свисток перезаряжается: %dс.", math.ceil(profile.whistleReadyAt - now)), "bad")
		return
	end
	local count = CreatureService.teleportOwned(player.UserId, plot.entrance)
	if count == 0 then
		PlayerData.notify(player, "Сбежавшего урожая сейчас нет.", "info")
		return
	end
	profile.whistleReadyAt = now + Config.WhistleCooldown
	PlayerData.markDirty(player)
	Remotes.Effect:FireClient(player, "sound", "whistle")
	PlayerData.notify(player, string.format("Свисток! К грядке вернулось: %d.", count), "good")
end

-- ---------------------------------------------------------------- rebirth
-- Resets money, seeds, inventory and growing crops. Upgrades, expansion and pets stay.
local function onRebirth(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local data = profile.data
	if data.money < Config.RebirthRequirement then
		PlayerData.notify(player, "Для Перерождения нужно " .. GameData.formatMoney(Config.RebirthRequirement) .. ".", "bad")
		return
	end
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.clearCrops(plot)
	end
	data.inventory = {}
	data.seeds = table.clone(Config.StartSeeds)
	data.rebirths += 1
	PlayerData.addMoney(player, Config.StartMoney - data.money, false)
	Remotes.Effect:FireClient(player, "sound", "catch")
	Remotes.Notify:FireAllClients(string.format("%s переродился! Перерождений: %d", player.DisplayName, data.rebirths), "info")
	PlayerData.notify(player, "Цены продажи навсегда +25%. В магазине открыто «Золотое Семя»!", "good")
end

-- A player with no money, no seeds and nothing growing could never recover: give one seed.
local function rescueBrokePlayers()
	for _, plot in PlotService.plots do
		local player = plot.owner
		local profile = player and PlayerData.get(player)
		if player and profile then
			local data = profile.data
			local seeds = 0
			for _, count in data.seeds do
				seeds += count
			end
			if seeds == 0 and data.money < GameData.Seeds.carrot.price and #data.inventory == 0
				and PlotService.cropCount(plot) == 0 and CreatureService.countOwned(player.UserId) == 0 then
				data.seeds.carrot = 1
				PlayerData.markDirty(player)
				PlayerData.notify(player, "Подарок от соседей: семя моркови. Не сдавайся!", "good")
			end
		end
	end
end

function ShopService.init()
	AntiExploit.connect(Remotes.Buy, 5, 10, onBuy)
	AntiExploit.connect(Remotes.EquipPet, 2, 4, onEquipPet)
	AntiExploit.connect(Remotes.PlaceTrap, 1, 2, onPlaceTrap)
	AntiExploit.connect(Remotes.Whistle, 1, 2, onWhistle)
	AntiExploit.connect(Remotes.Rebirth, 0.5, 1, onRebirth)
	task.spawn(function()
		while true do
			task.wait(10)
			rescueBrokePlayers()
		end
	end)
end

return ShopService
