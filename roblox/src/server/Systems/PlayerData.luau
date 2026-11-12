--[[
	PlayerData — player profiles, DataStore saving and state replication to the client.

	Saved: money, seeds, inventory, upgrades, expansion, pets, rebirth count, total caught.
	Not saved: crops that are still growing and creatures on the loose.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local STORE_NAME = "RunawayHarvest_v1"
local KEY_PREFIX = "player_"
local AUTOSAVE_INTERVAL = 120
local INCOME_WINDOW = 60

local PlayerData = {}

local profiles = {} -- [player] = profile
local loadedCallbacks = {}
local leavingCallbacks = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore недоступен: " .. tostring(result))
	end
end

-- ---------------------------------------------------------------- data shape
local function defaultData()
	return {
		money = Config.StartMoney,
		seeds = table.clone(Config.StartSeeds),
		inventory = {}, -- { s = seedId, m = mutationId?, t = unlock time (runtime only) }
		upgrades = { fence = false, whistle = false, traps = 0 },
		expanded = false,
		pets = {}, -- [petId] = true
		pet = nil, -- equipped pet id
		rebirths = 0,
		caught = 0,
	}
end

-- Never trust stored data blindly: rebuild it field by field.
local function sanitize(raw: any)
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	local function int(value, min, max, fallback)
		if type(value) == "number" and value == value then
			return math.clamp(math.floor(value), min, max)
		end
		return fallback
	end
	data.money = int(raw.money, 0, 1e15, data.money)
	data.rebirths = int(raw.rebirths, 0, 1e6, 0)
	data.caught = int(raw.caught, 0, 1e12, 0)
	data.expanded = raw.expanded == true

	data.seeds = {}
	if type(raw.seeds) == "table" then
		for id, count in raw.seeds do
			if GameData.Seeds[id] then
				data.seeds[id] = int(count, 0, Config.MaxSeedStack, 0)
			end
		end
	end
	if type(raw.inventory) == "table" then
		for _, item in raw.inventory do
			if #data.inventory >= Config.InventoryLimit then
				break
			end
			if type(item) == "table" and GameData.Seeds[item.s] and (item.m == nil or GameData.Mutations[item.m]) then
				table.insert(data.inventory, { s = item.s, m = item.m })
			end
		end
	end
	if type(raw.upgrades) == "table" then
		data.upgrades.fence = raw.upgrades.fence == true
		data.upgrades.whistle = raw.upgrades.whistle == true
		data.upgrades.traps = int(raw.upgrades.traps, 0, Config.MaxTraps, 0)
	end
	if type(raw.pets) == "table" then
		for id, owned in raw.pets do
			if GameData.Pets[id] and owned == true then
				data.pets[id] = true
			end
		end
	end
	if type(raw.pet) == "string" and data.pets[raw.pet] then
		data.pet = raw.pet
	end
	return data
end

local function serialize(data)
	local inventory = table.create(#data.inventory)
	for index, item in data.inventory do
		inventory[index] = { s = item.s, m = item.m }
	end
	return {
		version = 1,
		money = data.money,
		seeds = table.clone(data.seeds),
		inventory = inventory,
		upgrades = table.clone(data.upgrades),
		expanded = data.expanded,
		pets = table.clone(data.pets),
		pet = data.pet,
		rebirths = data.rebirths,
		caught = data.caught,
	}
end

-- ---------------------------------------------------------------- saving
local function save(player: Player, profile)
	if not store or not profile.canSave then
		return
	end
	local payload = serialize(profile.data)
	local key = KEY_PREFIX .. player.UserId
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function()
				return payload
			end)
		end)
		if ok then
			return
		end
		warn(string.format("[PlayerData] сохранение %s, попытка %d: %s", player.Name, attempt, tostring(err)))
		task.wait(1.5 * attempt)
	end
end

local function load(userId: number): (any, boolean)
	if not store then
		return nil, false
	end
	local attempts = RunService:IsStudio() and 1 or 3
	for attempt = 1, attempts do
		local ok, result = pcall(function()
			return store:GetAsync(KEY_PREFIX .. userId)
		end)
		if ok then
			return result, true
		end
		warn(string.format("[PlayerData] загрузка %d, попытка %d: %s", userId, attempt, tostring(result)))
		if attempt < attempts then
			task.wait(1.5)
		end
	end
	return nil, false
end

-- ---------------------------------------------------------------- public API
function PlayerData.get(player: Player)
	return profiles[player]
end

function PlayerData.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	-- a profile can finish loading before a later system registers: catch it up
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function PlayerData.onLeaving(callback: (Player, any) -> ())
	table.insert(leavingCallbacks, callback)
end

function PlayerData.markDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.dirty = true
	end
end

-- kind: "good" | "bad" | "info"
function PlayerData.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function PlayerData.notifyUserId(userId: number, text: string, kind: string?)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		PlayerData.notify(player, text, kind)
	end
end

local function syncLeaderstats(profile)
	profile.moneyStat.Value = profile.data.money
	profile.caughtStat.Value = profile.data.caught
end

-- isIncome = true counts towards the "Доход" readout in the top bar.
function PlayerData.addMoney(player: Player, amount: number, isIncome: boolean?)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.money = math.clamp(profile.data.money + amount, 0, 1e15)
	if isIncome and amount > 0 then
		table.insert(profile.sales, { t = os.clock(), amount = amount })
	end
	syncLeaderstats(profile)
	profile.dirty = true
end

function PlayerData.spend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.data.money < amount then
		return false
	end
	profile.data.money -= amount
	syncLeaderstats(profile)
	profile.dirty = true
	return true
end

function PlayerData.addCaught(player: Player)
	local profile = profiles[player]
	if profile then
		profile.data.caught += 1
		syncLeaderstats(profile)
		profile.dirty = true
	end
end

-- Adds a crop to the inventory. lockSeconds > 0 puts the ownership tag on it.
function PlayerData.addItem(player: Player, seedId: string, mutationId: string?, lockSeconds: number?): boolean
	local profile = profiles[player]
	if not profile or #profile.data.inventory >= Config.InventoryLimit then
		return false
	end
	local item = { s = seedId, m = mutationId, t = nil :: number? }
	if lockSeconds and lockSeconds > 0 then
		item.t = os.clock() + lockSeconds
	end
	table.insert(profile.data.inventory, item)
	profile.dirty = true
	return true
end

function PlayerData.sellMultiplier(player: Player): number
	local profile = profiles[player]
	if not profile then
		return 1
	end
	return GameData.sellMultiplier(profile.data.rebirths, profile.data.pet)
end

local function income(profile): number
	local now = os.clock()
	local total = 0
	for index = #profile.sales, 1, -1 do
		local sale = profile.sales[index]
		if now - sale.t > INCOME_WINDOW then
			table.remove(profile.sales, index)
		else
			total += sale.amount
		end
	end
	return total
end

local function snapshot(profile)
	local data = profile.data
	local now = os.clock()
	local inventory = table.create(#data.inventory)
	for index, item in data.inventory do
		inventory[index] = { s = item.s, m = item.m, l = item.t and math.max(0, math.ceil(item.t - now)) or 0 }
	end
	return {
		money = data.money,
		seeds = data.seeds,
		inventory = inventory,
		upgrades = data.upgrades,
		expanded = data.expanded,
		pets = data.pets,
		pet = data.pet,
		rebirths = data.rebirths,
		income = income(profile),
		whistleLeft = math.max(0, math.ceil(profile.whistleReadyAt - now)),
		trapPlaced = profile.trapPlaced,
		plotId = profile.plotId,
	}
end

-- ---------------------------------------------------------------- lifecycle
local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	local raw, loadedOk = load(player.UserId)
	if not player.Parent then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local moneyStat = Instance.new("IntValue")
	moneyStat.Name = "Деньги"
	moneyStat.Parent = leaderstats
	local caughtStat = Instance.new("IntValue")
	caughtStat.Name = "Урожай Пойман"
	caughtStat.Parent = leaderstats

	local profile = {
		data = sanitize(raw),
		canSave = loadedOk, -- never overwrite a save that failed to load
		dirty = true,
		sales = {},
		whistleReadyAt = 0,
		trapPlaced = false,
		plotId = 0,
		moneyStat = moneyStat,
		caughtStat = caughtStat,
		saved = false,
	}
	profiles[player] = profile
	syncLeaderstats(profile)
	leaderstats.Parent = player

	if not loadedOk then
		PlayerData.notify(player, "Сохранение сейчас недоступно — прогресс этой игры не запишется.", "bad")
	end
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, callback in leavingCallbacks do
		local ok, err = pcall(callback, player, profile)
		if not ok then
			warn("[PlayerData] ошибка при выходе: " .. tostring(err))
		end
	end
	if not profile.saved then
		profile.saved = true
		save(player, profile)
	end
	profiles[player] = nil
end

function PlayerData.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	AntiExploit.connect(Remotes.RequestState, 1, 3, function(player)
		PlayerData.markDirty(player)
	end)

	-- push changed state to clients (batched)
	task.spawn(function()
		local sinceRefresh = 0
		while true do
			local dt = task.wait(0.25)
			sinceRefresh += dt
			local refresh = sinceRefresh >= 5
			if refresh then
				sinceRefresh = 0
			end
			for player, profile in profiles do
				-- the income readout decays even when nothing else changes
				if profile.dirty or (refresh and #profile.sales > 0) then
					profile.dirty = false
					Remotes.StateUpdate:FireClient(player, snapshot(profile))
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(save, player, profile)
				task.wait(0.5)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			if not profile.saved then
				profile.saved = true
				pending += 1
				task.spawn(function()
					save(player, profile)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
