--[[
	PlayerData — the saved profile: Звёздочки, owned skins, equipped skin, upgrades, wins.
	The profile is mirrored into Player attributes (Stars, Wins, Skin, Skins, Upgrades) so the
	client UI can read it without extra remotes.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text

local STORE_NAME = "TikhiyChas_v1"
local KEY_PREFIX = "player_"
local AUTOSAVE_INTERVAL = 120

local PlayerData = {}
local profiles = {} -- [player] = profile
local loadedCallbacks = {}

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

local function defaultData()
	return { stars = 0, wins = 0, skins = { default = true }, skin = "default", upgrades = {} }
end

-- Never trust stored data blindly: rebuild it field by field.
local function sanitize(raw: any)
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	local function int(value, max)
		if type(value) == "number" and value == value then
			return math.clamp(math.floor(value), 0, max)
		end
		return 0
	end
	data.stars = int(raw.stars, 1e9)
	data.wins = int(raw.wins, 1e9)
	if type(raw.skins) == "table" then
		for id, owned in raw.skins do
			if Config.Skins[id] and owned == true then
				data.skins[id] = true
			end
		end
	end
	if type(raw.upgrades) == "table" then
		for id, owned in raw.upgrades do
			if Config.Upgrades[id] and owned == true then
				data.upgrades[id] = true
			end
		end
	end
	if type(raw.skin) == "string" and data.skins[raw.skin] then
		data.skin = raw.skin
	end
	return data
end

local function keys(dictionary): string
	local list = {}
	for id in dictionary do
		table.insert(list, id)
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function sync(player: Player, profile)
	local data = profile.data
	player:SetAttribute("Stars", data.stars)
	player:SetAttribute("Wins", data.wins)
	player:SetAttribute("Skin", data.skin)
	player:SetAttribute("Skins", keys(data.skins))
	player:SetAttribute("Upgrades", keys(data.upgrades))
	profile.starsStat.Value = data.stars
	profile.winsStat.Value = data.wins
end

local function save(player: Player, profile)
	if not store or not profile.canSave then
		return
	end
	local data = profile.data
	local payload = {
		version = 1, stars = data.stars, wins = data.wins,
		skins = table.clone(data.skins), skin = data.skin, upgrades = table.clone(data.upgrades),
	}
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(KEY_PREFIX .. player.UserId, function()
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

-- callback(player, profile) runs once the profile is ready (also for already loaded players).
function PlayerData.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function PlayerData.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function PlayerData.has(player: Player, upgradeId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.data.upgrades[upgradeId] == true
end

function PlayerData.addStars(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.data.stars = math.clamp(profile.data.stars + amount, 0, 1e9)
		sync(player, profile)
	end
end

function PlayerData.spend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount < 0 or profile.data.stars < amount then
		return false
	end
	profile.data.stars -= amount
	sync(player, profile)
	return true
end

function PlayerData.addWin(player: Player)
	local profile = profiles[player]
	if profile then
		profile.data.wins += 1
		sync(player, profile)
	end
end

function PlayerData.sync(player: Player)
	local profile = profiles[player]
	if profile then
		sync(player, profile)
	end
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
	local starsStat = Instance.new("IntValue")
	starsStat.Name = Text.LeaderStars
	starsStat.Parent = leaderstats
	local winsStat = Instance.new("IntValue")
	winsStat.Name = Text.LeaderWins
	winsStat.Parent = leaderstats

	local profile = {
		data = sanitize(raw),
		canSave = loadedOk, -- never overwrite a save that failed to load
		starsStat = starsStat,
		winsStat = winsStat,
		saved = false,
	}
	profiles[player] = profile
	sync(player, profile)
	leaderstats.Parent = player

	if not loadedOk then
		PlayerData.notify(player, Text.SaveUnavailable, "bad")
	end
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

function PlayerData.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile and not profile.saved then
			profile.saved = true
			save(player, profile)
		end
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

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
