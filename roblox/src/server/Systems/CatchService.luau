--[[
	CatchService — the catch meter. The client only says which creature it is trying to catch;
	distance, progress and the final capture are decided here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)
local CreatureService = require(script.Parent.CreatureService)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local SEND_INTERVAL = 0.1

local CatchService = {}
local sessions = {} -- [player] = { id, progress, sentAt, fullWarnedAt }

-- Gives the creature to the player. Returns false if the inventory is full.
function CatchService.capture(player: Player, creature, byPet: boolean?): boolean
	local seedId, mutationId = creature.seedId, creature.mutationId
	if not PlayerData.addItem(player, seedId, mutationId, Config.OwnershipTag) then
		return false
	end
	local ownerId = creature.ownerId
	local position = CreatureService.position(creature)
	CreatureService.despawn(creature, "caught")
	PlayerData.addCaught(player)

	local name = GameData.itemName(seedId, mutationId)
	Remotes.Effect:FireClient(player, "sound", "catch")
	Remotes.Effect:FireAllClients("caught", position)
	if byPet then
		PlayerData.notify(player, string.format("Питомец поймал: %s! Продать можно через %dс.", name, Config.OwnershipTag), "good")
	else
		PlayerData.notify(player, string.format("Пойман: %s! Продать можно через %dс.", name, Config.OwnershipTag), "good")
	end
	if ownerId ~= player.UserId then
		PlayerData.notifyUserId(ownerId, string.format("%s украл твой урожай: %s!", player.DisplayName, name), "bad")
	end
	return true
end

local function stop(player: Player)
	if sessions[player] then
		sessions[player] = nil
		Remotes.CatchProgress:FireClient(player, 0, 0)
	end
end

local function step(dt: number)
	local now = os.clock()
	for player, session in sessions do
		local creature = CreatureService.creatures[session.id]
		local root = AntiExploit.getRoot(player)
		if not creature or not root then
			stop(player)
			continue
		end
		local knocked = (CreatureService.knockedUntil[player] or 0) > now
		local distance = (root.Position - CreatureService.position(creature)).Magnitude
		if knocked or distance > CreatureService.catchRadius(creature) then
			session.progress = 0 -- escaped the radius: start over
		else
			session.progress += dt
		end

		if session.progress >= Config.CatchTime then
			if CatchService.capture(player, creature, false) then
				stop(player)
			else
				session.progress = 0
				if now - session.fullWarnedAt > 4 then
					session.fullWarnedAt = now
					PlayerData.notify(player, "Инвентарь полон! Сначала продай урожай.", "bad")
				end
			end
		elseif now - session.sentAt >= SEND_INTERVAL then
			session.sentAt = now
			Remotes.CatchProgress:FireClient(player, session.id, session.progress / Config.CatchTime)
		end
	end
end

function CatchService.init()
	AntiExploit.connect(Remotes.CatchStart, 6, 10, function(player, id)
		if not AntiExploit.isInt(id, 1, 2 ^ 31) or not CreatureService.creatures[id] then
			return
		end
		local session = sessions[player]
		if session and session.id == id then
			return
		end
		sessions[player] = { id = id, progress = 0, sentAt = 0, fullWarnedAt = 0 }
	end)
	AntiExploit.connect(Remotes.CatchStop, 6, 10, stop)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return CatchService
