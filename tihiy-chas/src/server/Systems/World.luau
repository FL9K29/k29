--[[
	World — references to the static map (Workspace.Map) and everything scripts need from it:
	beds, snack sources, hiding spots, throwable items, creaky zones, lights, waypoints.
	Also creates the proximity prompts (their text comes from Config.Text).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Text = Config.Text

local World = {}

World.map = workspace:WaitForChild("Map")
World.beds = {} -- [index] = { mattress, layCFrame, standPosition }
World.sources = {} -- [snackId] = BasePart
World.spots = {} -- [spotId] = { id, kind, part, inside, exit, occupant }
World.itemParts = {} -- [itemId] = BasePart
World.creaks = {} -- array of BasePart
World.lamps = {} -- array of { part, light }
World.nodes = {} -- [name] = Vector3 (floor level)
World.tv = nil :: BasePart?
World.tap = nil :: BasePart?
World.sofa = Vector3.zero
World.lobbySpawn = Vector3.zero

-- Родитель's server-side root part lives here; raycasts ignore this folder.
World.npcFolder = Instance.new("Folder")
World.npcFolder.Name = "NPC"
World.npcFolder.Parent = workspace

-- A character lying on its back with the head to the north (towards the pillow).
local LYING = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.pi / 2, 0, 0)

local function addPrompt(part: BasePart, name: string, objectText: string, actionText: string, hold: number?, key: Enum.KeyCode?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = key or Enum.KeyCode.E
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function World.setSign(part: BasePart, text: string, color: Color3?, studsWide: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SignGui"
	gui.Size = UDim2.fromScale(studsWide or 10, 2.4)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = color or Color3.fromRGB(255, 232, 170)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

-- Is this position on a creaky floorboard?
function World.inCreak(position: Vector3): boolean
	for _, zone in World.creaks do
		local offset = position - zone.Position
		if math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Z) <= zone.Size.Z / 2 then
			return true
		end
	end
	return false
end

function World.spotCFrame(spot): CFrame
	if spot.kind == "bed" then
		return CFrame.new(spot.inside) * LYING
	end
	return CFrame.new(spot.inside)
end

local function freeze(character: Model, cframe: CFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

-- Puts a character somewhere and makes it stay there (anchored root).
World.freeze = freeze

function World.unfreeze(character: Model, position: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		character:PivotTo(CFrame.new(position))
		root.Anchored = false
	end
end

function World.layInBed(character: Model, bedIndex: number)
	freeze(character, World.beds[bedIndex].layCFrame)
end

function World.init()
	local map = World.map

	for _, model in map:WaitForChild("Beds"):GetChildren() do
		local index = tonumber(string.match(model.Name, "%d+"))
		local mattress = model:FindFirstChild("Mattress") :: BasePart
		local stand = model:FindFirstChild("Stand") :: BasePart
		if index then
			World.beds[index] = {
				mattress = mattress,
				layCFrame = CFrame.new(mattress.Position + Vector3.new(0, 1.5, 0)) * LYING,
				standPosition = stand.Position,
			}
			addPrompt(mattress, "DeliverPrompt", Text.PromptBed, Text.PromptDeliver)
			addPrompt(mattress, "SleepPrompt", Text.PromptBed, Text.PromptSleep, 1, Enum.KeyCode.G)
		end
	end

	for _, part in map:WaitForChild("Sources"):GetChildren() do
		local snackId = string.match(part.Name, "^Source_(%a+)$")
		if snackId and Config.Snacks[snackId] and part:IsA("BasePart") then
			World.sources[snackId] = part
			local prompt = addPrompt(part, "PickupPrompt", Config.Snacks[snackId].name, Text.PromptTake, Config.Player.PickupTime)
			prompt:SetAttribute("SnackId", snackId)
		end
	end

	for _, model in map:WaitForChild("HideSpots"):GetChildren() do
		local kind = "wardrobe"
		if string.find(model.Name, "UnderBed") then
			kind = "bed"
		elseif model.Name == "Bath" then
			kind = "bath"
		end
		local part = model:FindFirstChild("Prompt") :: BasePart
		local prompt = addPrompt(part, "HidePrompt", Text.SpotNames[kind], Text.PromptHide)
		prompt:SetAttribute("SpotId", model.Name)
		World.spots[model.Name] = {
			id = model.Name,
			kind = kind,
			part = part,
			inside = (model:FindFirstChild("Inside") :: BasePart).Position,
			exit = (model:FindFirstChild("Exit") :: BasePart).Position,
			occupant = nil,
		}
	end

	for _, part in map:WaitForChild("Items"):GetChildren() do
		if part:IsA("BasePart") then
			World.itemParts[part.Name] = part
		end
	end
	for _, part in map:WaitForChild("CreakyZones"):GetChildren() do
		if part:IsA("BasePart") then
			table.insert(World.creaks, part)
		end
	end
	for _, part in map:WaitForChild("Lights"):GetChildren() do
		local light = part:FindFirstChildOfClass("PointLight")
		if light and part:IsA("BasePart") then
			table.insert(World.lamps, { part = part, light = light })
		end
	end
	for _, part in map:WaitForChild("Waypoints"):GetChildren() do
		if part:IsA("BasePart") then
			World.nodes[part.Name] = Vector3.new(part.Position.X, 0, part.Position.Z)
		end
	end

	local interactables = map:WaitForChild("Interactables")
	local tv = interactables:WaitForChild("TV") :: BasePart
	local tap = interactables:WaitForChild("Tap") :: BasePart
	World.tv = tv
	World.tap = tap
	addPrompt(tv, "UsePrompt", Text.PromptTvName, Text.PromptTv):SetAttribute("ObjectId", "tv")
	addPrompt(tap, "UsePrompt", Text.PromptTapName, Text.PromptTap):SetAttribute("ObjectId", "tap")
	local sofa = (interactables:WaitForChild("SofaSeat") :: BasePart).Position
	World.sofa = Vector3.new(sofa.X, 0, sofa.Z)

	local lobby = map:WaitForChild("Lobby")
	World.lobbySpawn = (lobby:WaitForChild("SpawnLocation") :: BasePart).Position + Vector3.new(0, 4, 0)
	World.setSign(lobby:WaitForChild("LobbySign") :: BasePart, Text.LobbySign, nil, 10)
end

return World
