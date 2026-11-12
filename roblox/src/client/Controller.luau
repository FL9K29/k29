--[[
	Controller — player input:
	  hold E (or the «ЛОВИТЬ» button) near an escaped crop → catch meter
	  F at a soil slot → plant the selected seed / harvest; F at the stands → sell / shop
	  Q → whistle, T → place the sticky trap
	The client only asks; the server checks distance, ownership and progress.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local State = require(script.Parent:WaitForChild("ClientState"))
local Windows = require(script.Parent:WaitForChild("Windows"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Config = GameData.Config

local KEEP_TARGET_DISTANCE = 35 -- keep chasing the same creature while it is this close

local Controller = {}
local holding = false
local targetId: number? = nil

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- Nearest creature inside its catch radius (+margin), and the distance to the current target.
local function scan(position: Vector3, margin: number): (number?, number?)
	local folder = workspace:FindFirstChild("Creatures")
	if not folder then
		return nil, nil
	end
	local nearestId, nearestDistance = nil, math.huge
	local targetDistance = nil
	for _, model in folder:GetChildren() do
		local root = model:FindFirstChild("Root")
		local id = model:GetAttribute("CreatureId")
		if root and root:IsA("BasePart") and type(id) == "number" then
			local distance = (root.Position - position).Magnitude
			local radius = Config.CatchRadius + ((model:GetAttribute("Scale") or 1) - 1) * 4
			if id == targetId then
				targetDistance = distance
			end
			if distance <= radius + margin and distance < nearestDistance then
				nearestId, nearestDistance = id, distance
			end
		end
	end
	return nearestId, targetDistance
end

local function setHolding(value: boolean)
	if holding == value then
		return
	end
	holding = value
	if not holding then
		if targetId then
			Remotes.CatchStop:FireServer()
		end
		targetId = nil
		Hud.setCatch(0)
	end
end

local sinceScan = 0
local function step(dt: number)
	sinceScan += dt
	if sinceScan < 0.15 then
		return
	end
	sinceScan = 0
	local position = rootPosition()
	if not position then
		Hud.setCatchHint(false)
		return
	end
	local nearestId, targetDistance = scan(position, 2)
	Hud.setCatchHint(nearestId ~= nil and not holding)
	if not holding then
		return
	end
	local wanted = nearestId
	if targetId and targetDistance and targetDistance <= KEEP_TARGET_DISTANCE then
		wanted = targetId -- stay on the creature we started with
	end
	if wanted ~= targetId then
		targetId = wanted
		if wanted then
			Remotes.CatchStart:FireServer(wanted)
		else
			Remotes.CatchStop:FireServer()
			Hud.setCatch(0)
		end
	end
end

local function onPrompt(prompt: ProximityPrompt)
	if prompt.Name == "SellPrompt" then
		Windows.open("inventory")
	elseif prompt.Name == "ShopPrompt" then
		Windows.open("shop")
	elseif prompt.Name == "SlotPrompt" then
		if prompt:GetAttribute("OwnerId") ~= player.UserId then
			Hud.notify("Это чужая грядка!", "bad")
			return
		end
		local index = prompt:GetAttribute("SlotIndex")
		local state = prompt:GetAttribute("State")
		if state == "ripe" then
			Remotes.Harvest:FireServer(index)
		elseif state == "empty" then
			if State.selectedSeed then
				Remotes.Plant:FireServer(index, State.selectedSeed)
			else
				Hud.notify("Семян нет. Купи их в магазине.", "bad")
				Windows.open("shop")
			end
		end
	end
end

function Controller.init()
	Hud.callbacks.catchHold = setHolding
	Hud.callbacks.whistle = function()
		Remotes.Whistle:FireServer()
	end
	Hud.callbacks.trap = function()
		Remotes.PlaceTrap:FireServer()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			setHolding(true)
		elseif input.KeyCode == Enum.KeyCode.Q then
			Hud.callbacks.whistle()
		elseif input.KeyCode == Enum.KeyCode.T then
			Hud.callbacks.trap()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E then
			setHolding(false)
		end
	end)

	Remotes:WaitForChild("CatchProgress").OnClientEvent:Connect(function(_id, fraction)
		if holding and type(fraction) == "number" then
			Hud.setCatch(fraction)
		else
			Hud.setCatch(0)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player then
			onPrompt(prompt)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return Controller
