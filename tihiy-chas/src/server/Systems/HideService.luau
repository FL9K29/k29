--[[
	HideService — hiding spots: 2 шкафа, 3 места «под кроватью» and the bath curtain.
	A hidden player is invisible to Родитель unless he was watching when they climbed in
	(HideService.watchCheck is provided by NpcBrain).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiExploit = require(script.Parent.AntiExploit)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local StealthService = require(script.Parent.StealthService)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text

local HideService = {}

-- Replaced by NpcBrain: returns true if Родитель saw the player enter the spot.
HideService.watchCheck = function(_s): boolean
	return false
end

-- Takes the player out of the spot. toPlaying = false when Родитель is pulling them out.
function HideService.release(s, toPlaying: boolean)
	local spot = s.spot
	if not spot then
		return
	end
	spot.occupant = nil
	s.spot = nil
	s.spotSeen = false
	local character = s.player.Character
	if character then
		World.unfreeze(character, spot.exit)
	end
	if toPlaying then
		s.status = "playing"
	end
	StealthService.grace(s)
	Session.sync(s)
end

local function onHide(player: Player, spotId: any)
	local s = Session.get(player)
	if not s then
		return
	end
	if s.status == "hidden" then
		HideService.release(s, true)
		Remotes.Effect:FireClient(player, "sound", "hide")
		return
	end
	if s.status ~= "playing" or type(spotId) ~= "string" then
		return
	end
	local spot = World.spots[spotId]
	local character = player.Character
	if not spot or not character then
		return
	end
	if spot.occupant then
		PlayerData.notify(player, Text.SpotBusy, "bad")
		return
	end
	if not AntiExploit.distanceOk(player, spot.part.Position, Config.Player.InteractDistance) then
		return
	end

	local seen = HideService.watchCheck(s)
	spot.occupant = s
	s.spot = spot
	s.spotSeen = seen
	s.status = "hidden"
	s.pickup = nil
	World.freeze(character, World.spotCFrame(spot))
	Session.sync(s)
	Remotes.Effect:FireClient(player, "sound", "hide")
	PlayerData.notify(player, seen and Text.HiddenSeen or Text.Hidden, seen and "bad" or "good")
end

function HideService.init()
	AntiExploit.connect(Remotes.Hide, 2, 4, onHide)
end

return HideService
