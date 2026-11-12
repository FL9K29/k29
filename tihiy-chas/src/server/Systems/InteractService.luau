--[[
	InteractService — things players use to manage noise:
	  * throwable items (тапки, мячик): pick up, throw, the landing lures Родитель
	  * the TV: 30 seconds during which he hears twice as badly
	  * the bathroom tap: a noisy distraction
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiExploit = require(script.Parent.AntiExploit)
local Noise = require(script.Parent.Noise)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text

local STORAGE = CFrame.new(0, -200, 0) -- where a held item waits, out of sight
local RESPAWN_TIME = 25
local THROW_SPEED = 60

local InteractService = {}
local items: { [string]: any } = {} -- [itemId] = { id, kind, name, part, prompt, home, state, token, holder }
local tvToken = 0
local tvCooldownUntil = 0
local tapCooldownUntil = 0

-- ---------------------------------------------------------------- throwables
local function sendHome(item)
	item.token += 1
	item.state = "home"
	item.holder = nil
	item.part.Anchored = true
	item.part.AssemblyLinearVelocity = Vector3.zero
	item.part.AssemblyAngularVelocity = Vector3.zero
	item.part.CFrame = item.home
	item.prompt.Enabled = true
end

local function onGrab(player: Player, itemId: any)
	local s = Session.get(player)
	if not s or s.status ~= "playing" or type(itemId) ~= "string" then
		return
	end
	local item = items[itemId]
	if not item or (item.state ~= "home" and item.state ~= "landed") then
		return
	end
	if s.holding then
		PlayerData.notify(player, Text.HandsItemBusy, "bad")
		return
	end
	if not AntiExploit.distanceOk(player, item.part.Position, Config.Player.InteractDistance) then
		return
	end
	item.token += 1
	item.state = "held"
	item.part.Anchored = true
	item.part.CFrame = STORAGE
	item.prompt.Enabled = false
	item.holder = player
	s.holding = item
	Session.sync(s)
	Remotes.Effect:FireClient(player, "sound", "pickup")
	PlayerData.notify(player, string.format(Text.ItemGrabbed, item.name), "info")
end

local function onThrow(player: Player, direction: any)
	local s = Session.get(player)
	local root = AntiExploit.getRoot(player)
	if not s or not root or s.status ~= "playing" or not s.holding then
		return
	end
	if typeof(direction) ~= "Vector3" or direction ~= direction or direction.Magnitude < 0.1 or direction.Magnitude > 10 then
		return
	end
	local item = s.holding
	s.holding = nil
	Session.sync(s)

	-- only the direction comes from the client; origin and speed are decided here
	local aim = direction.Unit
	aim = Vector3.new(aim.X, math.clamp(aim.Y, -0.2, 0.5), aim.Z).Unit
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	if flatAim.Magnitude < 0.05 then
		flatAim = root.CFrame.LookVector
	end
	local part = item.part
	item.token += 1
	item.state = "flying"
	local token = item.token
	part.CFrame = CFrame.new(root.Position + Vector3.new(0, 2, 0) + flatAim.Unit * 2.5)
	part.Anchored = false
	part:SetNetworkOwner(nil)
	part.AssemblyLinearVelocity = aim * THROW_SPEED + Vector3.new(0, 14, 0)

	local connection: RBXScriptConnection? = nil
	local function land()
		if item.token ~= token or item.state ~= "flying" then
			return
		end
		if connection then
			connection:Disconnect()
		end
		item.state = "landed"
		item.prompt.Enabled = true
		Noise.emit(part.Position, Config.Noise.Throw, "throw")
		Remotes.Effect:FireAllClients("thud", part.Position)
		task.delay(RESPAWN_TIME, function()
			if item.token == token and (item.state :: string) == "landed" then
				sendHome(item)
			end
		end)
	end
	local character = player.Character
	connection = part.Touched:Connect(function(hit)
		if hit.CanCollide and not (character and hit:IsDescendantOf(character)) then
			land()
		end
	end)
	task.delay(2.5, land)
end

-- ---------------------------------------------------------------- TV and tap
local function stopTv()
	tvToken += 1
	Noise.tvUntil = 0
	workspace:SetAttribute("TVUntil", 0)
	local tv = World.tv
	if tv then
		tv.Color = Color3.fromRGB(16, 16, 20)
		tv.Material = Enum.Material.SmoothPlastic
		local light = tv:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 0
		end
	end
end

local function startTv()
	local tv = World.tv
	if not tv then
		return
	end
	tvToken += 1
	local token = tvToken
	local now = os.clock()
	Noise.tvUntil = now + Config.Noise.TvDuration
	tvCooldownUntil = now + Config.Noise.TvDuration + Config.Noise.TvCooldown
	workspace:SetAttribute("TVUntil", workspace:GetServerTimeNow() + Config.Noise.TvDuration)
	local light = tv:FindFirstChildOfClass("PointLight")
	tv.Material = Enum.Material.Neon
	task.spawn(function()
		local rng = Random.new()
		while tvToken == token and os.clock() < Noise.tvUntil do
			tv.Color = Color3.fromHSV(rng:NextNumber(0.5, 0.7), 0.5, rng:NextNumber(0.6, 1))
			if light then
				light.Brightness = rng:NextNumber(0.8, 1.6)
			end
			task.wait(0.45)
		end
		if tvToken == token then
			stopTv()
		end
	end)
end

local function onUse(player: Player, objectId: any)
	local s = Session.get(player)
	if not s or s.status ~= "playing" then
		return
	end
	local now = os.clock()
	if objectId == "tv" and World.tv then
		if not AntiExploit.distanceOk(player, World.tv.Position, Config.Player.InteractDistance) then
			return
		end
		if now < Noise.tvUntil then
			PlayerData.notify(player, Text.TvAlready, "info")
		elseif now < tvCooldownUntil then
			PlayerData.notify(player, Text.TvCooldown, "bad")
		else
			startTv()
			Remotes.Notify:FireAllClients(Text.TvStarted, "good")
		end
	elseif objectId == "tap" and World.tap then
		local tap = World.tap
		if not AntiExploit.distanceOk(player, tap.Position, Config.Player.InteractDistance) then
			return
		end
		if now < tapCooldownUntil then
			PlayerData.notify(player, Text.TapCooldown, "bad")
			return
		end
		tapCooldownUntil = now + Config.Noise.TapCooldown
		Remotes.Notify:FireAllClients(Text.TapStarted, "info")
		task.spawn(function()
			for _ = 1, Config.Noise.TapDuration do
				if Session.phase ~= "round" then
					break
				end
				Noise.emit(tap.Position, Config.Noise.Tap, "tap")
				Remotes.Effect:FireAllClients("tap", tap.Position)
				task.wait(1)
			end
		end)
	end
end

-- Called by RoundManager between rounds.
function InteractService.resetAll()
	for _, item in items do
		sendHome(item)
	end
	for _, s in Session.players do
		s.holding = nil
	end
	stopTv()
	tvCooldownUntil = 0
	tapCooldownUntil = 0
end

function InteractService.init()
	for itemId, part in World.itemParts do
		local kind = string.match(itemId, "^Item_(%a+)%d*$")
		local info = kind and Config.Items[kind]
		if kind and info then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ItemPrompt"
			prompt.ObjectText = info.name
			prompt.ActionText = Text.PromptGrab
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("ItemId", itemId)
			prompt.Parent = part
			items[itemId] = {
				id = itemId, kind = kind, name = info.name, part = part, prompt = prompt,
				home = part.CFrame, state = "home", token = 0,
			}
		end
	end
	-- an item must not vanish with a player who leaves while holding it
	Players.PlayerRemoving:Connect(function(player)
		for _, item in items do
			if item.state == "held" and item.holder == player then
				sendHome(item)
			end
		end
	end)
	AntiExploit.connect(Remotes.GrabItem, 2, 4, onGrab)
	AntiExploit.connect(Remotes.Throw, 2, 4, onThrow)
	AntiExploit.connect(Remotes.UseObject, 2, 4, onUse)
end

return InteractService
