--[[
	SnackService — the objective: take snacks in the kitchen (4 s hold), hide them in a bed
	in the bedroom, and optionally go to bed once a teammate has finished.

	The hold itself is shown by the ProximityPrompt on the client; the server checks the
	real elapsed time, the distance and the carrying capacity before giving a snack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiExploit = require(script.Parent.AntiExploit)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text
local Needed = Config.Round.SnacksNeeded

local SnackService = {}

local function nearBed(player: Player): boolean
	for _, bed in World.beds do
		if AntiExploit.distanceOk(player, bed.mattress.Position, Config.Player.InteractDistance) then
			return true
		end
	end
	return false
end

-- Why the player cannot take one more snack right now (nil = they can).
local function pickupBlock(s): string?
	if s.delivered + #s.carried >= Needed then
		return Text.AlreadyEnough
	elseif #s.carried >= Session.capacity(s) then
		return Text.HandsFull
	end
	return nil
end

local function onPickup(player: Player, action: any, snackId: any)
	local s = Session.get(player)
	if not s or s.status ~= "playing" then
		return
	end
	if action == "cancel" then
		s.pickup = nil
		return
	end
	if not AntiExploit.isId(snackId, Config.Snacks) then
		return
	end
	local source = World.sources[snackId]
	if not source or not AntiExploit.distanceOk(player, source.Position, Config.Player.InteractDistance + 4) then
		return
	end

	if action == "start" then
		local reason = pickupBlock(s)
		if reason then
			PlayerData.notify(player, reason, "bad")
			return
		end
		s.pickup = { id = snackId, startedAt = os.clock() }
	elseif action == "finish" then
		local pickup = s.pickup
		s.pickup = nil
		if not pickup or pickup.id ~= snackId then
			return
		end
		local required = Config.Player.PickupTime * (PlayerData.has(player, "luck") and Config.Player.LuckMultiplier or 1)
		if os.clock() - pickup.startedAt < required - 0.35 or pickupBlock(s) then
			return -- held for too short a time: ignore
		end
		table.insert(s.carried, snackId)
		Session.sync(s)
		Remotes.Effect:FireClient(player, "sound", "pickup")
		PlayerData.notify(player, string.format(Text.PickedUp, Config.Snacks[snackId].name), "good")
	end
end

local function onDeliver(player: Player)
	local s = Session.get(player)
	if not s or s.status ~= "playing" or not nearBed(player) then
		return
	end
	local count = #s.carried
	if count == 0 then
		PlayerData.notify(player, Text.NothingToDeliver, "bad")
		return
	end
	local stars = count * Config.Rewards.PerSnack
	s.carried = {}
	s.delivered = math.min(Needed, s.delivered + count)
	s.roundStars += stars
	PlayerData.addStars(player, stars)
	Remotes.Effect:FireClient(player, "sound", "deliver")
	PlayerData.notify(player, string.format(Text.Delivered, s.delivered, Needed, stars), "good")

	if s.delivered >= Needed and not s.complete then
		s.complete = true
		PlayerData.notify(player, Text.Completed, "good")
		for other in Session.players do
			if other ~= player then
				PlayerData.notify(other, string.format(Text.TeammateCompleted, player.DisplayName), "info")
			end
		end
	end
	Session.sync(s)
end

-- «Лечь спать»: a player who will not finish can go to bed once somebody has all 5 snacks.
local function onSleep(player: Player)
	local s = Session.get(player)
	local character = player.Character
	if not s or not character or s.status ~= "playing" or not nearBed(player) then
		return
	end
	local anyComplete = false
	for _, other in Session.players do
		if other.complete then
			anyComplete = true
		end
	end
	if not anyComplete then
		PlayerData.notify(player, Text.SleepNeedComplete, "bad")
		return
	end
	s.status = "sleeping"
	s.pickup = nil
	World.layInBed(character, s.bed)
	Session.sync(s)
	PlayerData.notify(player, Text.Sleeping, "good")
end

function SnackService.init()
	AntiExploit.connect(Remotes.Pickup, 6, 10, onPickup)
	AntiExploit.connect(Remotes.Deliver, 2, 4, onDeliver)
	AntiExploit.connect(Remotes.Sleep, 1, 2, onSleep)
end

return SnackService
