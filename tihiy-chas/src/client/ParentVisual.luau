--[[
	ParentVisual — draws «Родитель» on the client.

	The server only moves an invisible root part (Workspace.NPC.ParentRoot) and sets its
	attributes State / Emote / VisionRange. Here we build the visible blocky body, follow the
	root smoothly every frame, swing the legs, show the «!» / «?» / «Zzz» bubble and aim the
	flashlight (a SpotLight with the same angle and range as his server-side vision cone).
	Also plays the cat that dashes through the corridor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ROBE = Color3.fromRGB(86, 104, 150)
local SKIN = Color3.fromRGB(240, 200, 170)
local DARK = Color3.fromRGB(40, 40, 50)

local ParentVisual = {}

local model: Model
local root: Part
local leftHip: Motor6D, rightHip: Motor6D, leftShoulder: Motor6D, rightShoulder: Motor6D
local spot: SpotLight
local emoteLabel: TextLabel
local current: CFrame? = nil
local lastPosition = Vector3.zero
local walkPhase = 0
local speedSmooth = 0

local function newPart(name: string, size: Vector3, color: Color3, cframe: CFrame, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
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

local function weldTo(base: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
end

local function joint(name: string, part: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = root
	motor.Part1 = part
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = root
	return motor
end

-- The root's centre is 3 studs above the floor (same as the server part).
local function build()
	model = Instance.new("Model")
	model.Name = "ParentVisual"

	root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 6, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, -50, 0)
	root.Parent = model
	local origin = root.CFrame

	-- body: bathrobe, head, hair, face (he looks along -Z)
	weldTo(root, newPart("Robe", Vector3.new(2.6, 3, 1.4), ROBE, origin * CFrame.new(0, 1.5, 0), Enum.Material.Fabric))
	weldTo(root, newPart("Belt", Vector3.new(2.7, 0.3, 1.5), DARK, origin * CFrame.new(0, 0.9, 0), Enum.Material.Fabric))
	local head = newPart("Head", Vector3.new(1.6, 1.6, 1.6), SKIN, origin * CFrame.new(0, 3.8, 0))
	weldTo(root, head)
	weldTo(root, newPart("Hair", Vector3.new(1.7, 0.5, 1.7), Color3.fromRGB(90, 64, 44), origin * CFrame.new(0, 4.75, 0.05)))
	for _, side in { -1, 1 } do
		weldTo(root, newPart("Eye", Vector3.new(0.25, 0.25, 0.1), DARK, origin * CFrame.new(side * 0.35, 3.95, -0.82)))
	end
	weldTo(root, newPart("Mouth", Vector3.new(0.6, 0.12, 0.1), DARK, origin * CFrame.new(0, 3.45, -0.82)))

	-- limbs on joints so they can be animated
	local function limb(name: string, size: Vector3, color: Color3): Part
		return newPart(name, size, color, origin)
	end
	leftHip = joint("LeftHip", limb("LeftLeg", Vector3.new(1, 3, 1), Color3.fromRGB(70, 80, 110)), CFrame.new(-0.65, 0, 0), CFrame.new(0, 1.5, 0))
	rightHip = joint("RightHip", limb("RightLeg", Vector3.new(1, 3, 1), Color3.fromRGB(70, 80, 110)), CFrame.new(0.65, 0, 0), CFrame.new(0, 1.5, 0))
	leftShoulder = joint("LeftShoulder", limb("LeftArm", Vector3.new(0.8, 2.6, 0.8), ROBE), CFrame.new(-1.75, 2.8, 0), CFrame.new(0, 1.2, 0))
	rightShoulder = joint("RightShoulder", limb("RightArm", Vector3.new(0.8, 2.6, 0.8), ROBE), CFrame.new(1.75, 2.8, 0), CFrame.new(0, 1.2, 0))

	-- flashlight: welded to the root so the beam always matches the server-side cone
	local torch = newPart("Flashlight", Vector3.new(0.5, 0.5, 1.4), DARK, origin * CFrame.new(1.75, 2.1, -2.3), Enum.Material.Metal)
	weldTo(root, torch)
	local lens = newPart("Lens", Vector3.new(0.4, 0.4, 0.1), Color3.fromRGB(255, 244, 200), origin * CFrame.new(1.75, 2.1, -3.02), Enum.Material.Neon)
	weldTo(root, lens)
	spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = Config.Parent.VisionAngle
	spot.Range = Config.Parent.VisionRange
	spot.Brightness = 4
	spot.Color = Color3.fromRGB(255, 240, 200)
	spot.Shadows = true
	spot.Parent = torch

	-- emote bubble and name
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 90)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = head
	emoteLabel = Instance.new("TextLabel")
	emoteLabel.Size = UDim2.new(1, 0, 0.65, 0)
	emoteLabel.BackgroundTransparency = 1
	emoteLabel.Font = Enum.Font.GothamBlack
	emoteLabel.TextScaled = true
	emoteLabel.TextStrokeTransparency = 0
	emoteLabel.Text = ""
	emoteLabel.Parent = gui
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	nameLabel.Position = UDim2.fromScale(0, 0.7)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 200)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = Config.Text.ParentName
	nameLabel.Parent = gui
	gui.Parent = head

	model.Parent = workspace
end

local function update(dt: number)
	local folder = workspace:FindFirstChild("NPC")
	local serverRoot = folder and folder:FindFirstChild("ParentRoot")
	if not serverRoot or not serverRoot:IsA("BasePart") then
		return
	end
	local target = serverRoot.CFrame
	-- smooth out the network updates; snap when he is repositioned between rounds
	if not current or (current.Position - target.Position).Magnitude > 14 then
		current = target
	else
		current = current:Lerp(target, 1 - math.exp(-14 * dt))
	end
	local shown = current :: CFrame
	local state = serverRoot:GetAttribute("State") or "idle"

	local moved = (shown.Position - lastPosition).Magnitude
	lastPosition = shown.Position
	local speed = dt > 0 and moved / dt or 0
	speedSmooth += (speed - speedSmooth) * math.min(1, dt * 8)
	walkPhase += moved * 0.75
	local swing = math.sin(walkPhase) * 0.7 * math.clamp(speedSmooth / 4, 0, 1)

	if state == "sleep" or state == "idle" then
		-- sitting on the sofa behind him
		root.CFrame = shown * CFrame.new(0, -0.4, 3.6) * CFrame.Angles(0.2, 0, 0)
		leftHip.C0 = CFrame.new(-0.65, 0, 0) * CFrame.Angles(1.4, 0, 0)
		rightHip.C0 = CFrame.new(0.65, 0, 0) * CFrame.Angles(1.4, 0, 0)
	else
		root.CFrame = shown
		leftHip.C0 = CFrame.new(-0.65, 0, 0) * CFrame.Angles(swing, 0, 0)
		rightHip.C0 = CFrame.new(0.65, 0, 0) * CFrame.Angles(-swing, 0, 0)
	end

	local carrying = state == "grab" or state == "carry"
	local leftAngle = carrying and 1.5 or (state == "alert" and 2.6 or -swing * 0.8)
	leftShoulder.C0 = CFrame.new(-1.75, 2.8, 0) * CFrame.Angles(leftAngle, 0, 0)
	rightShoulder.C0 = CFrame.new(1.75, 2.8, 0) * CFrame.Angles(carrying and 1.5 or 1.25, 0, 0)

	local range = serverRoot:GetAttribute("VisionRange") or 0
	spot.Enabled = range > 0
	spot.Range = math.clamp(range, 0, 60)

	local emote = serverRoot:GetAttribute("Emote") or ""
	if emoteLabel.Text ~= emote then
		emoteLabel.Text = emote
		emoteLabel.TextColor3 = emote == Config.Text.EmoteSearch and Color3.fromRGB(255, 220, 90)
			or (emote == Config.Text.EmoteSleep and Color3.fromRGB(170, 200, 255) or Color3.fromRGB(255, 80, 70))
	end
end

-- «Кот пробежал!»: a small cat runs from one end of the corridor to the other.
local function runCat(from: Vector3, to: Vector3)
	local cat = Instance.new("Model")
	cat.Name = "Cat"
	local body = Instance.new("Part")
	body.Size = Vector3.new(1.2, 1.1, 2.6)
	body.Color = Color3.fromRGB(240, 150, 60)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = cat
	local function add(size: Vector3, offset: CFrame, color: Color3)
		local part = Instance.new("Part")
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.Massless = true
		part.CFrame = body.CFrame * offset
		part.Parent = cat
		weldTo(body, part)
	end
	add(Vector3.new(1.1, 1, 1), CFrame.new(0, 0.6, -1.6), Color3.fromRGB(240, 150, 60))
	add(Vector3.new(0.3, 0.5, 0.2), CFrame.new(-0.35, 1.3, -1.6), Color3.fromRGB(200, 110, 40))
	add(Vector3.new(0.3, 0.5, 0.2), CFrame.new(0.35, 1.3, -1.6), Color3.fromRGB(200, 110, 40))
	add(Vector3.new(0.3, 0.3, 1.6), CFrame.new(0, 0.7, 1.9) * CFrame.Angles(0.7, 0, 0), Color3.fromRGB(200, 110, 40))
	cat.Parent = workspace
	Sounds.playAt("cat", (from + to) / 2)

	local duration = 2.4
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.RenderStepped:Wait()
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local position = from:Lerp(to, alpha) + Vector3.new(0, 0.9 + math.abs(math.sin(elapsed * 14)) * 0.5, 0)
		body.CFrame = CFrame.lookAt(position, position + (to - from))
	end
	cat:Destroy()
end

function ParentVisual.init()
	build()
	RunService.RenderStepped:Connect(update)
	Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, a, b)
		if kind == "cat" and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			task.spawn(runCat, a, b)
		end
	end)
end

return ParentVisual
