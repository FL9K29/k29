--[[
	RoundManager — the game loop:
	  lobby («подъезд») → everybody presses «Готов» → 10 s lift countdown → round (6 minutes)
	  → results («Победа!» / «Вас поймали...») → back to the lobby.

	Win:  at least one player delivered all 5 snacks and every other player is either
	      finished too or lying in bed.
	Lose: the timer runs out («рассвет»).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiExploit = require(script.Parent.AntiExploit)
local EventService = require(script.Parent.EventService)
local HideService = require(script.Parent.HideService)
local InteractService = require(script.Parent.InteractService)
local NpcBrain = require(script.Parent.NpcBrain)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local StealthService = require(script.Parent.StealthService)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text

local RoundManager = {}
local rng = Random.new()

local function lobbyPosition(): Vector3
	return World.lobbySpawn + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
end

local function everyoneReady(): boolean
	local count = 0
	for _, s in Session.players do
		if not s.ready then
			return false
		end
		count += 1
	end
	return count > 0
end

local function roomCode(): string
	local alphabet = "АБВГДЕЖИКЛМНПРСТ0123456789"
	local letters = {}
	for _, codepoint in utf8.codes(alphabet) do
		table.insert(letters, utf8.char(codepoint))
	end
	local seed = 0
	for index = 1, #game.JobId do
		seed = (seed * 31 + string.byte(game.JobId, index)) % 2147483647
	end
	local generator = Random.new(seed ~= 0 and seed or os.time())
	local code = ""
	for _ = 1, 4 do
		code ..= letters[generator:NextInteger(1, #letters)]
	end
	return code
end

-- ---------------------------------------------------------------- round start / end
local function startRound()
	local bed = 0
	for _, s in Session.players do
		bed = bed % #World.beds + 1
		Session.reset(s)
		s.status = "playing"
		s.bed = bed
		s.ready = false
		StealthService.teleport(s, World.beds[bed].standPosition)
		StealthService.grace(s, 3)
		StealthService.applySpeed(s)
		Session.sync(s)
	end
	InteractService.resetAll()
	NpcBrain.start()
	EventService.start()
	workspace:SetAttribute("Result", "")
	Session.setPhase("round", Config.Round.Duration)
	Remotes.Notify:FireAllClients(Text.RoundStart, "info")
end

-- "win" | "lose" | nil (keep playing)
local function checkRound(endsAt: number): string?
	local participants = Session.participants()
	if #participants == 0 then
		return "lose"
	end
	local anyComplete, allDone = false, true
	for _, s in participants do
		if s.complete then
			anyComplete = true
		elseif s.status ~= "sleeping" then
			allDone = false
		end
	end
	if anyComplete and allDone then
		return "win"
	elseif os.clock() >= endsAt then
		return "lose"
	end
	return nil
end

local function endRound(result: string)
	NpcBrain.stop()
	EventService.stop()
	InteractService.resetAll()
	local participants = Session.participants()
	for _, s in participants do
		if s.spot then
			HideService.release(s, false)
		end
		s.chased = false
		s.pickup = nil
		if result == "win" then
			local bonus = Config.Rewards.Win + (s.complete and Config.Rewards.Complete or 0)
			s.roundStars += bonus
			PlayerData.addStars(s.player, bonus)
			PlayerData.addWin(s.player)
		end
		Session.sync(s)
	end
	workspace:SetAttribute("Result", result)
	Session.setPhase("results", Config.Round.Results)
	Remotes.Effect:FireAllClients("sound", result == "win" and "win" or "lose")
	task.wait(Config.Round.Results)

	for _, s in participants do
		if Session.players[s.player] then
			local character = s.player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
			end
			Session.reset(s)
			StealthService.teleport(s, lobbyPosition())
			StealthService.applySpeed(s)
			Session.sync(s)
			Remotes.Effect:FireClient(s.player, "released")
		end
	end
end

-- A player who respawns in the middle of a round goes back to their bed.
local function onCharacter(player: Player)
	local s = Session.get(player)
	if not s or s.status == "lobby" then
		return
	end
	if s.spot then
		s.spot.occupant = nil
		s.spot = nil
	end
	s.status = "playing"
	s.crouched = false
	s.chased = false
	Session.sync(s)
	task.defer(function()
		local character = player.Character
		if character and character:WaitForChild("HumanoidRootPart", 5) then
			task.wait(0.1)
			StealthService.teleport(s, World.beds[s.bed].standPosition)
			StealthService.applySpeed(s)
		end
	end)
end

function RoundManager.init()
	workspace:SetAttribute("RoomCode", roomCode())
	workspace:SetAttribute("Result", "")

	AntiExploit.connect(Remotes.Ready, 3, 5, function(player, ready)
		local s = Session.get(player)
		if s and s.status == "lobby" and type(ready) == "boolean" then
			s.ready = ready
			Session.sync(s)
		end
	end)
	PlayerData.onLoaded(function(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end)

	task.spawn(function()
		while true do
			-- lobby: wait until everybody is ready
			Session.setPhase("lobby", 0)
			repeat
				task.wait(0.5)
			until everyoneReady()

			-- lift countdown; anybody un-readying cancels it
			Session.setPhase("countdown", Config.Round.Countdown)
			local deadline = os.clock() + Config.Round.Countdown
			local cancelled = false
			while os.clock() < deadline do
				task.wait(0.25)
				if not everyoneReady() then
					cancelled = true
					break
				end
			end

			if not cancelled then
				startRound()
				local endsAt = os.clock() + Config.Round.Duration
				local result = nil
				repeat
					task.wait(0.25)
					result = checkRound(endsAt)
				until result
				endRound(result)
			end
		end
	end)
end

return RoundManager
