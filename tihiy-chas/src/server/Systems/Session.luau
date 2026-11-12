--[[
	Session — the live state of the current round: phase, timer and one table per player
	(status, snacks, bed, crouch, hiding spot...). It holds data only; other systems change it
	and call Session.sync so the client sees it through Player attributes.

	status: "lobby" | "playing" | "hidden" | "caught" | "stunned" | "sleeping"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Session = {}
Session.phase = "lobby" -- "lobby" | "countdown" | "round" | "results"
Session.players = {} -- [player] = session table

function Session.get(player: Player)
	return Session.players[player]
end

-- Mirrors the session into attributes of the Player (read by every client's UI).
function Session.sync(s)
	local player = s.player
	player:SetAttribute("Status", s.status)
	player:SetAttribute("Delivered", s.delivered)
	player:SetAttribute("Carried", table.concat(s.carried, ","))
	player:SetAttribute("Complete", s.complete)
	player:SetAttribute("Ready", s.ready)
	player:SetAttribute("Crouched", s.crouched)
	player:SetAttribute("Chased", s.chased)
	player:SetAttribute("Holding", s.holding and s.holding.kind or "")
	player:SetAttribute("StunnedUntil", s.stunnedUntilServer)
	player:SetAttribute("RoundStars", s.roundStars)
	player:SetAttribute("Capacity", Session.capacity(s))
end

function Session.capacity(s): number
	return PlayerData.has(s.player, "backpack") and Config.Player.BackpackCapacity or Config.Player.BaseCapacity
end

-- Clears everything that belongs to one round.
function Session.reset(s)
	s.status = "lobby"
	s.delivered = 0
	s.carried = {}
	s.complete = false
	s.bed = 0
	s.crouched = false
	s.chased = false
	s.spot = nil
	s.spotSeen = false
	s.holding = nil
	s.stunnedUntil = 0
	s.stunnedUntilServer = 0
	s.roundStars = 0
	s.noiseRadius = 0
	s.pickup = nil
	s.graceUntil = 0
	s.speedStrikes = 0
end

function Session.setPhase(phase: string, duration: number)
	Session.phase = phase
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEnds", workspace:GetServerTimeNow() + duration)
end

-- Players taking part in the running round.
function Session.participants()
	local list = {}
	for _, s in Session.players do
		if s.status ~= "lobby" then
			table.insert(list, s)
		end
	end
	return list
end

function Session.init()
	workspace:SetAttribute("Phase", "lobby")
	PlayerData.onLoaded(function(player)
		if Session.players[player] then
			return
		end
		local s = { player = player, ready = false, lastPos = nil, lastSampleAt = os.clock(), lastGood = nil }
		Session.reset(s)
		Session.players[player] = s
		Session.sync(s)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local s = Session.players[player]
		if s then
			if s.spot then
				s.spot.occupant = nil
			end
			Session.players[player] = nil
		end
	end)
end

return Session
