--[[
	PetService — pets follow their owner and auto-catch the owner's escaped crops
	within PetRadius studs, once every PetCooldown seconds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)
local CatchService = require(script.Parent.CatchService)
local CreatureService = require(script.Parent.CreatureService)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Config = GameData.Config

local FOLLOW_SPEED = 24
local ROOT_HEIGHT = 1.5

local PetService = {}
local pets = {} -- [player] = { model, root, pos, readyAt }

local function buildPet(petId: string)
	local pet = GameData.Pets[petId]
	local dark = pet.color:Lerp(Color3.new(0, 0, 0), 0.3)
	local model = Instance.new("Model")
	model.Name = "Pet"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.6, 1.2, 2.6)
	root.Color = pet.color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, ROOT_HEIGHT, 0)
	root.Parent = model
	model.PrimaryPart = root

	local function add(name: string, size: Vector3, offset: CFrame, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		part.Parent = model
		local constraint = Instance.new("WeldConstraint")
		constraint.Part0 = root
		constraint.Part1 = part
		constraint.Parent = part
	end
	add("Head", Vector3.new(1.4, 1.3, 1.3), CFrame.new(0, 0.8, -1.5), pet.color)
	add("Nose", Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 0.6, -2.3), Color3.fromRGB(30, 30, 34))
	add("Tail", Vector3.new(0.35, 0.35, 1.3), CFrame.new(0, 0.5, 1.8) * CFrame.Angles(0.6, 0, 0), dark)
	for _, side in { -1, 1 } do
		add("Ear", Vector3.new(0.4, 0.7, 0.3), CFrame.new(side * 0.5, 1.7, -1.4), dark)
		add("Eye", Vector3.new(0.22, 0.22, 0.1), CFrame.new(side * 0.35, 1, -2.16), Color3.fromRGB(20, 20, 24))
		add("FrontLeg", Vector3.new(0.4, 0.9, 0.4), CFrame.new(side * 0.5, -1.05, -0.9), dark)
		add("BackLeg", Vector3.new(0.4, 0.9, 0.4), CFrame.new(side * 0.5, -1.05, 0.9), dark)
	end

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(180, 24)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 60
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 240, 200)
	label.TextStrokeTransparency = 0.3
	label.Text = pet.name
	label.Parent = tag
	tag.Parent = root
	return model, root
end

-- Call after the equipped pet changes (or on load).
function PetService.refresh(player: Player)
	local existing = pets[player]
	if existing then
		existing.model:Destroy()
		pets[player] = nil
	end
	local profile = PlayerData.get(player)
	local petId = profile and profile.data.pet
	if not petId or not GameData.Pets[petId] then
		return
	end
	local model, root = buildPet(petId)
	local playerRoot = AntiExploit.getRoot(player)
	local start = playerRoot and playerRoot.Position or Vector3.zero
	pets[player] = {
		model = model,
		root = root,
		pos = Vector3.new(start.X, 0, start.Z),
		readyAt = os.clock() + 3,
	}
	model.Parent = World.Pets
end

local sinceCheck = 0

local function step(dt: number)
	sinceCheck += dt
	local check = sinceCheck >= 0.5
	if check then
		sinceCheck = 0
	end
	local now = os.clock()
	for player, pet in pets do
		local playerRoot = AntiExploit.getRoot(player)
		if not playerRoot then
			continue
		end
		local look = playerRoot.CFrame.LookVector
		local right = playerRoot.CFrame.RightVector
		local target = playerRoot.Position - look * 5 + right * 3
		target = Vector3.new(target.X, 0, target.Z)
		local delta = target - pet.pos
		local distance = delta.Magnitude
		local facing = Vector3.new(look.X, 0, look.Z)
		if distance > 80 then
			pet.pos = target -- owner respawned or teleported
		elseif distance > 0.6 then
			pet.pos += delta.Unit * math.min(distance, FOLLOW_SPEED * dt)
			facing = delta
		end
		if facing.Magnitude < 0.01 then
			facing = Vector3.new(0, 0, -1)
		end
		local hop = distance > 0.6 and math.abs(math.sin(now * 10)) * 0.35 or 0
		local base = pet.pos + Vector3.new(0, ROOT_HEIGHT + hop, 0)
		pet.root.CFrame = CFrame.lookAt(base, base + facing.Unit)

		if check and now >= pet.readyAt then
			for _, creature in CreatureService.creatures do
				if creature.ownerId == player.UserId then
					local offset = CreatureService.position(creature) - pet.root.Position
					if offset.Magnitude <= Config.PetRadius then
						if CatchService.capture(player, creature, true) then
							pet.readyAt = now + Config.PetCooldown
						end
						break
					end
				end
			end
		end
	end
end

function PetService.init()
	PlayerData.onLoaded(function(player)
		PetService.refresh(player)
	end)
	PlayerData.onLeaving(function(player)
		local pet = pets[player]
		if pet then
			pet.model:Destroy()
			pets[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return PetService
