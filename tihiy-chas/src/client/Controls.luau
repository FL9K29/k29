--[[
	Controls — player input:
	  E            use the prompt in front of you (take a snack — hold 4 s, hide, pick up, TV, tap)
	  E            climb out of a hiding spot
	  Ctrl / C     toggle crouch (slow and quiet)
	  F            throw the item in your hand where the camera looks
	  G (hold)     lie down in bed
	Every action is only a request: the server checks distance, timing and state.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Text = Config.Text

local Controls = {}
local lastHideRequest = 0
local baseHipHeight: number? = nil

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function status(): string
	return attr("Status", "lobby")
end

-- ---------------------------------------------------------------- actions
local function toggleCrouch()
	if status() == "playing" then
		Remotes.Crouch:FireServer(not attr("Crouched", false))
	end
end

-- Hiding and climbing out share one debounce, so a single key press never does both.
local function requestHide(spotId: string?)
	local now = os.clock()
	if now - lastHideRequest < 0.5 then
		return
	end
	lastHideRequest = now
	Remotes.Hide:FireServer(spotId)
end

local function throwItem()
	local camera = workspace.CurrentCamera
	if camera and status() == "playing" and attr("Holding", "") ~= "" then
		Remotes.Throw:FireServer(camera.CFrame.LookVector)
	end
end

-- Why one more snack cannot be taken right now (nil = it can).
local function pickupBlock(): string?
	local carried = attr("Carried", "")
	local count = carried == "" and 0 or #string.split(carried, ",")
	if attr("Delivered", 0) + count >= Config.Round.SnacksNeeded then
		return Text.AlreadyEnough
	elseif count >= attr("Capacity", 1) then
		return Text.HandsFull
	end
	return nil
end

-- ---------------------------------------------------------------- crouch look
-- The server owns the speed; here the character is only lowered so the crouch is visible.
local function applyCrouchLook()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if not baseHipHeight then
		baseHipHeight = humanoid.HipHeight
	end
	local crouched = attr("Crouched", false) and status() == "playing"
	humanoid.HipHeight = (baseHipHeight :: number) - (crouched and 1 or 0)
	humanoid.CameraOffset = Vector3.new(0, crouched and -1 or 0, 0)
end

-- «Удача»: the hold shown on the prompt is 20% shorter (the server uses the same number).
local function applyLuck()
	local lucky = string.find(attr("Upgrades", ""), "luck", 1, true) ~= nil
	local duration = Config.Player.PickupTime * (lucky and Config.Player.LuckMultiplier or 1)
	local sources = workspace:WaitForChild("Map"):WaitForChild("Sources")
	for _, source in sources:GetChildren() do
		local prompt = source:FindFirstChild("PickupPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.HoldDuration = duration
		end
	end
end

-- ---------------------------------------------------------------- prompts
local function onHoldBegan(prompt: ProximityPrompt)
	if prompt.Name == "PickupPrompt" then
		local reason = pickupBlock()
		if reason then
			Hud.notify(reason, "bad")
		else
			Remotes.Pickup:FireServer("start", prompt:GetAttribute("SnackId"))
		end
	end
end

local function onTriggered(prompt: ProximityPrompt)
	local name = prompt.Name
	if name == "PickupPrompt" then
		if not pickupBlock() then
			Remotes.Pickup:FireServer("finish", prompt:GetAttribute("SnackId"))
		end
	elseif name == "DeliverPrompt" then
		Remotes.Deliver:FireServer()
	elseif name == "SleepPrompt" then
		Remotes.Sleep:FireServer()
	elseif name == "HidePrompt" then
		requestHide(prompt:GetAttribute("SpotId") :: any)
	elseif name == "ItemPrompt" then
		Remotes.GrabItem:FireServer(prompt:GetAttribute("ItemId"))
	elseif name == "UsePrompt" then
		Remotes.UseObject:FireServer(prompt:GetAttribute("ObjectId"))
	end
end

function Controls.init()
	Hud.callbacks.crouch = toggleCrouch
	Hud.callbacks.throw = throwItem
	Hud.callbacks.exit = function()
		requestHide(nil)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl or key == Enum.KeyCode.C then
			toggleCrouch()
		elseif key == Enum.KeyCode.F then
			throwItem()
		elseif key == Enum.KeyCode.E and status() == "hidden" then
			requestHide(nil)
		end
	end)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
		if who == player then
			onHoldBegan(prompt)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player then
			onTriggered(prompt)
		end
	end)

	player:GetAttributeChangedSignal("Crouched"):Connect(applyCrouchLook)
	player:GetAttributeChangedSignal("Status"):Connect(applyCrouchLook)
	player.CharacterAdded:Connect(function()
		baseHipHeight = nil
	end)
	player:GetAttributeChangedSignal("Upgrades"):Connect(applyLuck)
	task.spawn(applyLuck)
end

return Controls
