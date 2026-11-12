--[[
	CreatureService — escaped crops: blocky creatures with vegetable heads, and their escape AI.

	Creatures are simulated entirely on the server (position, direction, timers). The model is an
	anchored root with welded parts, moved every Heartbeat; the client only swings the legs.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameData = require(ReplicatedStorage.Shared.GameData)
local AntiExploit = require(script.Parent.AntiExploit)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local FLY_HEIGHT = 16
local FLY_TIME = 2.5
local FLEE_DISTANCE = 22
local STOMP_INTERVAL = 4
local STOMP_RADIUS = 16
local KNOCKDOWN_TIME = 1.5

local CreatureService = {}
local creatures = {} -- [id] = creature
CreatureService.creatures = creatures
CreatureService.traps = {} -- [userId] = { part, position, ownerId }
CreatureService.knockedUntil = {} -- [player] = os.clock() time; knocked players cannot catch

local rng = Random.new()
local nextId = 0

-- ---------------------------------------------------------------- model
local function makePart(model: Model, name: string, size: Vector3, color: Color3, cframe: CFrame, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = cframe
	part.Parent = model
	return part
end

local function weld(root: BasePart, part: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = part
end

local function makeLabel(parent: Instance, text: string, color: Color3, size: number, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.Position = UDim2.fromScale(0, order * 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = parent
	return label
end

-- Builds the creature at the origin; the caller moves it by setting root.CFrame.
local function buildModel(seedId: string, mutationId: string)
	local seed = GameData.Seeds[seedId]
	local mutation = GameData.Mutations[mutationId]
	local s = mutation.scale
	local black = Color3.fromRGB(20, 20, 24)

	local model = Instance.new("Model")
	model.Name = "Creature"

	local rootHeight = 2.4 * s -- legs 1.6 + half of the body
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 1) * s
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, rootHeight, 0)
	root.Parent = model
	model.PrimaryPart = root
	local origin = root.CFrame

	local headSize = seed.head.size * s
	local headColor = seed.head.color
	if mutationId == "infected" then
		headColor = headColor:Lerp(Color3.fromRGB(110, 210, 80), 0.45)
	end
	local headY = 0.8 * s + headSize.Y / 2
	local static = {}

	table.insert(static, makePart(model, "Body", Vector3.new(2, 1.6, 1.2) * s, seed.bodyColor, origin))
	local head = makePart(model, "Head", headSize, headColor, origin * CFrame.new(0, headY, 0), (Enum.PartType :: any)[seed.head.shape])
	if seedId == "golden" then
		head.Material = Enum.Material.Neon
	end
	table.insert(static, head)
	table.insert(static, makePart(model, "Leaf", Vector3.new(0.5, 0.9, 0.5) * s, seed.leafColor,
		origin * CFrame.new(0, headY + headSize.Y / 2 + 0.35 * s, 0)))

	-- face (the creature looks along -Z)
	local faceZ = -headSize.Z / 2
	for _, side in { -1, 1 } do
		table.insert(static, makePart(model, "Eye", Vector3.new(0.5, 0.5, 0.16) * s, Color3.new(1, 1, 1),
			origin * CFrame.new(side * 0.42 * s, headY + headSize.Y * 0.12, faceZ)))
		local pupil = makePart(model, "Pupil", Vector3.new(0.22, 0.22, 0.12) * s,
			mutationId == "infected" and Color3.fromRGB(255, 40, 40) or black,
			origin * CFrame.new(side * 0.42 * s, headY + headSize.Y * 0.12, faceZ - 0.08 * s))
		if mutationId == "infected" then
			pupil.Material = Enum.Material.Neon
		end
		table.insert(static, pupil)
		table.insert(static, makePart(model, "Arm", Vector3.new(0.5, 1.4, 0.5) * s, seed.bodyColor,
			origin * CFrame.new(side * 1.25 * s, 0.05 * s, 0)))
	end
	table.insert(static, makePart(model, "Mouth", Vector3.new(0.7, 0.16, 0.12) * s, black,
		origin * CFrame.new(0, headY - headSize.Y * 0.2, faceZ)))

	-- mutation details
	if mutationId == "sentient" then
		table.insert(static, makePart(model, "BowTie", Vector3.new(0.9, 0.4, 0.2) * s, Color3.fromRGB(220, 50, 60),
			origin * CFrame.new(0, 0.5 * s, -0.65 * s)))
		table.insert(static, makePart(model, "Glasses", Vector3.new(1.5, 0.12, 0.1) * s, black,
			origin * CFrame.new(0, headY + headSize.Y * 0.12 + 0.3 * s, faceZ - 0.05 * s)))
	elseif mutationId == "flying" then
		for _, side in { -1, 1 } do
			table.insert(static, makePart(model, "Wing", Vector3.new(1.8, 1.1, 0.2) * s, Color3.fromRGB(245, 245, 255),
				origin * CFrame.new(side * 1.7 * s, 0.6 * s, 0.5 * s) * CFrame.Angles(0, 0, side * -0.5)))
		end
	elseif mutationId == "royal" then
		local crown = makePart(model, "Crown", Vector3.new(1.3, 0.55, 1.3) * s, Color3.fromRGB(255, 208, 60),
			origin * CFrame.new(0, headY + headSize.Y / 2 + 0.95 * s, 0))
		crown.Material = Enum.Material.Neon
		table.insert(static, crown)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 214, 80)
		sparkles.Parent = head
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 208, 60)
		light.Range = 16
		light.Brightness = 2
		light.Parent = head
	elseif mutationId == "titan" then
		for _, side in { -1, 1 } do
			table.insert(static, makePart(model, "Brow", Vector3.new(0.6, 0.14, 0.12) * s, black,
				origin * CFrame.new(side * 0.42 * s, headY + headSize.Y * 0.12 + 0.36 * s, faceZ - 0.04 * s)
					* CFrame.Angles(0, 0, side * 0.35)))
		end
	end
	for _, part in static do
		weld(root, part)
	end

	-- legs hang on Motor6Ds so the client can swing them (see client Effects)
	for _, side in { -1, 1 } do
		local leg = makePart(model, side < 0 and "LeftLeg" or "RightLeg", Vector3.new(0.7, 1.6, 0.7) * s,
			seed.bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), origin * CFrame.new(side * 0.5 * s, -1.6 * s, 0))
		local hip = Instance.new("Motor6D")
		hip.Name = side < 0 and "LeftHip" or "RightHip"
		hip.Part0 = root
		hip.Part1 = leg
		hip.C0 = CFrame.new(side * 0.5 * s, -0.8 * s, 0)
		hip.C1 = CFrame.new(0, 0.8 * s, 0)
		hip.Parent = root
	end

	-- name tag
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(260, 48)
	tag.StudsOffset = Vector3.new(0, headSize.Y / 2 + 1.6 * s, 0)
	tag.MaxDistance = 140
	tag.LightInfluence = 0
	tag.Adornee = head
	makeLabel(tag, GameData.itemName(seedId, mutationId), mutation.color, 18, 0)
	local info = makeLabel(tag, "", Color3.new(1, 1, 1), 14, 1)
	tag.Parent = head

	return model, root, head, info, rootHeight
end

local function shout(creature)
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromOffset(190, 46)
	bubble.StudsOffset = Vector3.new(0, creature.head.Size.Y / 2 + 4.2 * creature.mutation.scale, 0)
	bubble.MaxDistance = 120
	bubble.LightInfluence = 0
	bubble.Adornee = creature.head
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(30, 30, 36)
	label.Text = GameData.Phrases[rng:NextInteger(1, #GameData.Phrases)]
	label.Parent = frame
	bubble.Parent = creature.head
	Debris:AddItem(bubble, 3)
end

-- ---------------------------------------------------------------- public API
function CreatureService.catchRadius(creature): number
	return Config.CatchRadius + (creature.mutation.scale - 1) * 4
end

function CreatureService.position(creature): Vector3
	return creature.root.Position
end

function CreatureService.countOwned(userId: number): number
	local count = 0
	for _, creature in creatures do
		if creature.ownerId == userId then
			count += 1
		end
	end
	return count
end

-- reason: "caught" | "escaped" | "removed"
function CreatureService.despawn(creature, reason: string)
	if not creatures[creature.id] then
		return
	end
	creatures[creature.id] = nil
	creature.model:Destroy()
	if reason == "escaped" then
		PlayerData.notifyUserId(creature.ownerId,
			"Урожай убежал навсегда: " .. GameData.itemName(creature.seedId, creature.mutationId), "bad")
	end
end

function CreatureService.spawn(owner: Player, seedId: string, mutationId: string, position: Vector3, plot: any, fenced: boolean)
	local mutation = GameData.Mutations[mutationId]
	local model, root, head, info, rootHeight = buildModel(seedId, mutationId)
	local now = os.clock()
	local angle = rng:NextNumber() * math.pi * 2
	nextId += 1
	local creature = {
		id = nextId,
		seedId = seedId,
		mutationId = mutationId,
		mutation = mutation,
		ownerId = owner.UserId,
		ownerName = owner.DisplayName,
		model = model,
		root = root,
		head = head,
		info = info,
		rootHeight = rootHeight,
		pos = Vector3.new(position.X, 0, position.Z), -- ground position
		dir = Vector3.new(math.cos(angle), 0, math.sin(angle)),
		altitude = 0,
		nextTurn = now + rng:NextNumber(2, 4),
		expiresAt = now + Config.EscapeTime,
		stunnedUntil = 0,
		fencePlot = fenced and plot or nil,
		fenceUntil = now + Config.FenceTime,
		flyUntil = 0,
		nextFly = now + rng:NextNumber(3, 6),
		nextStomp = now + STOMP_INTERVAL,
		nextShout = now + rng:NextNumber(9, 16),
		infoText = "",
	}
	model:SetAttribute("CreatureId", creature.id)
	model:SetAttribute("OwnerId", creature.ownerId)
	model:SetAttribute("Scale", mutation.scale)
	model:SetAttribute("Speed", mutation.speed)
	model:SetAttribute("Stunned", false)
	root.CFrame = CFrame.lookAt(creature.pos + Vector3.new(0, rootHeight, 0), creature.pos + Vector3.new(0, rootHeight, 0) + creature.dir)
	model.Parent = World.Creatures
	creatures[creature.id] = creature

	shout(creature)
	Remotes.Effect:FireAllClients("scream", root.Position)
	PlayerData.notify(owner, "Твой урожай ожил: " .. GameData.itemName(seedId, mutationId) .. "! Лови!", "info")
	return creature
end

-- Whistle: brings every creature of this owner to a point. Returns how many moved.
function CreatureService.teleportOwned(userId: number, position: Vector3): number
	local count = 0
	for _, creature in creatures do
		if creature.ownerId == userId then
			creature.pos = Vector3.new(position.X + rng:NextNumber(-4, 4), 0, position.Z + rng:NextNumber(-4, 4))
			creature.altitude = 0
			creature.flyUntil = 0
			count += 1
		end
	end
	return count
end

function CreatureService.removeTrap(userId: number)
	local trap = CreatureService.traps[userId]
	if trap then
		trap.part:Destroy()
		CreatureService.traps[userId] = nil
		local owner = Players:GetPlayerByUserId(userId)
		local profile = owner and PlayerData.get(owner)
		if owner and profile then
			profile.trapPlaced = false
			PlayerData.markDirty(owner)
		end
	end
end

-- ---------------------------------------------------------------- AI
local function pickDirection(creature, now: number)
	local nearest, nearestDistance = nil, FLEE_DISTANCE
	for _, player in Players:GetPlayers() do
		local playerRoot = AntiExploit.getRoot(player)
		if playerRoot then
			local offset = creature.pos - playerRoot.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = Vector3.new(offset.X, 0, offset.Z), distance
			end
		end
	end
	local angle
	if nearest and nearest.Magnitude > 0.1 then
		-- run away from the closest player, with some randomness
		angle = math.atan2(nearest.Z, nearest.X) + rng:NextNumber(-1, 1)
	elseif rng:NextNumber() < 0.3 then
		-- crops love to hide in the forest
		local toForest = World.ForestCenter - creature.pos
		angle = math.atan2(toForest.Z, toForest.X) + rng:NextNumber(-0.6, 0.6)
	else
		angle = rng:NextNumber() * math.pi * 2
	end
	creature.dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	creature.nextTurn = now + rng:NextNumber(2, 4)
end

local function stomp(creature)
	local position = creature.pos
	Remotes.Effect:FireAllClients("stomp", position)
	for _, player in Players:GetPlayers() do
		local playerRoot = AntiExploit.getRoot(player)
		if playerRoot and (playerRoot.Position - position).Magnitude <= STOMP_RADIUS then
			CreatureService.knockedUntil[player] = os.clock() + KNOCKDOWN_TIME
			Remotes.Effect:FireClient(player, "knockdown", position)
		end
	end
end

local function checkTraps(creature, now: number)
	for userId, trap in CreatureService.traps do
		local offset = creature.pos - trap.position
		if offset.Magnitude <= Config.TrapRadius then
			creature.stunnedUntil = now + Config.TrapStun
			creature.altitude = 0
			creature.model:SetAttribute("Stunned", true)
			Remotes.Effect:FireAllClients("trap", trap.position)
			PlayerData.notifyUserId(userId,
				"Ловушка сработала! Прилип: " .. GameData.itemName(creature.seedId, creature.mutationId), "good")
			CreatureService.removeTrap(userId)
			return
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, creature in creatures do
		if now >= creature.expiresAt then
			CreatureService.despawn(creature, "escaped")
			continue
		end

		local stunned = now < creature.stunnedUntil
		if not stunned then
			if creature.model:GetAttribute("Stunned") then
				creature.model:SetAttribute("Stunned", false)
			end
			if now >= creature.nextTurn then
				pickDirection(creature, now)
			end

			local minX, maxX, minZ, maxZ = -World.Bounds, World.Bounds, -World.Bounds, World.Bounds
			local plot = creature.fencePlot
			if plot and now < creature.fenceUntil then
				minX, maxX, minZ, maxZ = plot.minX + 2, plot.maxX - 2, plot.minZ + 2, plot.maxZ - 2
			end
			local target = creature.pos + creature.dir * creature.mutation.speed * dt
			local x, z = target.X, target.Z
			if x < minX or x > maxX then
				creature.dir = Vector3.new(-creature.dir.X, 0, creature.dir.Z)
				x = math.clamp(x, minX, maxX)
			end
			if z < minZ or z > maxZ then
				creature.dir = Vector3.new(creature.dir.X, 0, -creature.dir.Z)
				z = math.clamp(z, minZ, maxZ)
			end
			creature.pos = Vector3.new(x, 0, z)

			if creature.mutation.canFly then
				if now >= creature.nextFly then
					creature.flyUntil = now + FLY_TIME
					creature.nextFly = now + FLY_TIME + rng:NextNumber(5, 8)
				end
				local targetAltitude = now < creature.flyUntil and FLY_HEIGHT or 0
				creature.altitude += (targetAltitude - creature.altitude) * math.min(1, dt * 4)
			end
			if creature.mutation.stomp and now >= creature.nextStomp then
				creature.nextStomp = now + STOMP_INTERVAL
				stomp(creature)
			end
			if now >= creature.nextShout then
				creature.nextShout = now + rng:NextNumber(10, 18)
				shout(creature)
			end
			if creature.altitude < 3 and next(CreatureService.traps) ~= nil then
				checkTraps(creature, now)
			end
		end

		local base = creature.pos + Vector3.new(0, creature.rootHeight + creature.altitude, 0)
		creature.root.CFrame = CFrame.lookAt(base, base + creature.dir)

		local left = math.ceil(creature.expiresAt - now)
		local text = stunned and string.format("Прилип! · %dс", left) or string.format("%s · %dс", creature.ownerName, left)
		if text ~= creature.infoText then
			creature.infoText = text
			creature.info.Text = text
		end
	end
end

function CreatureService.init()
	RunService.Heartbeat:Connect(step)
	PlayerData.onLeaving(function(player)
		CreatureService.removeTrap(player.UserId)
		CreatureService.knockedUntil[player] = nil
	end)
end

return CreatureService
