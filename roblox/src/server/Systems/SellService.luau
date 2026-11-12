--[[
	SellService — the sell stand. Prices are computed on the server from GameData;
	crops that still carry the ownership tag are kept.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local SellService = {}

local function sell(player: Player)
	local profile = PlayerData.get(player)
	local stand = World.SellStand
	if not profile or not stand then
		return
	end
	if not AntiExploit.distanceOk(player, stand.Position, Config.SellDistance) then
		PlayerData.notify(player, "Подойди к прилавку «Продажа урожая» на площади.", "bad")
		return
	end

	local now = os.clock()
	local multiplier = PlayerData.sellMultiplier(player)
	local kept = {}
	local total, sold = 0, 0
	for _, item in profile.data.inventory do
		if item.t and item.t > now then
			table.insert(kept, item) -- ownership tag still active
		else
			total += GameData.itemPrice(item.s, item.m, multiplier)
			sold += 1
		end
	end
	if sold == 0 then
		if #kept > 0 then
			PlayerData.notify(player, "На урожае ещё метка владения. Подожди немного.", "bad")
		else
			PlayerData.notify(player, "Продавать нечего. Вырасти или поймай урожай!", "bad")
		end
		return
	end
	profile.data.inventory = kept
	PlayerData.addMoney(player, total, true)
	Remotes.Effect:FireClient(player, "sound", "sell")
	PlayerData.notify(player, string.format("Продано: %d шт. на %s", sold, GameData.formatMoney(total)), "good")
end

function SellService.init()
	AntiExploit.connect(Remotes.Sell, 1, 3, sell)
end

return SellService
