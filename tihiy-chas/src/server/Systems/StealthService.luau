--[[
	StealthService — how players move during a round:
	  * crouch toggle (slower, quiet)
	  * footstep noise: running 20 studs, crouched 6, creaky floor 35
	  * anti-exploit speed check with rubber-banding
	  * the 10-second "stunned in bed" timer after being caught
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiExploit = require(script.Parent.AntiExploit)
local Noise = require(script.Parent.Noise)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text
local SAMPLE_INTERVAL = 0.25

local StealthService = {}

function StealthService.applySpeed(s)
	local character = s.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local crouching = s.status == "playing" and s.crouched
		humanoid.WalkSpeed = crouching and Config.Player.CrouchSpeed or Config.Player.RunSpeed
	end
end

-- After a server teleport the speed check must not fire.
function StealthService.grace(s, seconds: number?)
	s.graceUntil = os.clock() + (seconds or 2)
	s.lastPos = nil
	s.lastGood = nil
	s.speedStrikes = 0
end

function StealthService.teleport(s, position: Vector3)
	local character = s.player.Character
	if character then
		World.unfreeze(character, position)
	end
	StealthService.grace(s)
end

local function sample(s, now: number)
	local root = AntiExploit.getRoot(s.player)
	if not root then
		s.lastPos = nil
		return
	end
	local position = root.Position
	local dt = now - s.lastSampleAt
	s.lastSampleAt = now

	-- stun timer
	if s.status == "stunned" and now >= s.stunnedUntil then
		s.status = "playing"
		s.stunnedUntilServer = 0
		StealthService.teleport(s, World.beds[s.bed].standPosition)
		StealthService.applySpeed(s)
		Session.sync(s)
		Remotes.Effect:FireClient(s.player, "released")
		PlayerData.notify(s.player, Text.Released, "info")
		return
	end

	if s.status ~= "playing" then
		s.noiseRadius = 0
		s.lastPos = position
		return
	end

	local last = s.lastPos
	s.lastPos = position
	if not last or dt <= 0 then
		s.lastGood = position
		return
	end
	local speed = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude / dt

	-- speed check: nobody may move faster than a running kid (with some tolerance for lag)
	if now > s.graceUntil and speed > Config.Player.RunSpeed * 1.7 + 4 then
		s.speedStrikes += 1
		if s.speedStrikes >= 3 and s.lastGood then
			s.speedStrikes = 0
			local character = s.player.Character
			if character then
				character:PivotTo(CFrame.new(s.lastGood))
			end
			s.lastPos = s.lastGood
			PlayerData.notify(s.player, Text.SpeedWarning, "bad")
			return
		end
	else
		s.speedStrikes = math.max(0, s.speedStrikes - 0.25)
		s.lastGood = position
	end

	-- footstep noise is decided from the real measured speed, not from what the client claims
	local radius = 0
	if speed > 2 then
		local quiet = s.crouched and speed <= Config.Player.CrouchSpeed * 1.6
		radius = quiet and Config.Noise.Crouch or Config.Noise.Run
		if World.inCreak(position) and not PlayerData.has(s.player, "soles") then
			radius = Config.Noise.Creak
		end
		Noise.emit(position, radius, "step")
	end
	s.noiseRadius = radius
end

function StealthService.init()
	AntiExploit.connect(Remotes.Crouch, 4, 6, function(player, enabled)
		local s = Session.get(player)
		if not s or type(enabled) ~= "boolean" or s.status ~= "playing" then
			return
		end
		s.crouched = enabled
		StealthService.applySpeed(s)
		Session.sync(s)
	end)

	task.spawn(function()
		while true do
			task.wait(SAMPLE_INTERVAL)
			local now = os.clock()
			for _, s in Session.players do
				sample(s, now)
			end
		end
	end)
end

return StealthService
