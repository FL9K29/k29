--[[
	Hud — the in-round interface, all in Russian:
	objective tracker, «До рассвета» timer, snack icons, team list, crouch/noise indicator,
	«Тебя заметили!» red vignette, event banners, notifications and the big centre messages.
	It reads the round state from Player and Workspace attributes set by the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Text = Config.Text
local Colors = UIKit.Colors
local Needed = Config.Round.SnacksNeeded

local Hud = {}
-- Set by Controls: what the touch buttons do.
Hud.callbacks = {
	crouch = function() end,
	throw = function() end,
	exit = function() end,
}

local gui = script.Parent
local container: Frame
local objectiveLabel, timerLabel, handsLabel, noiseLabel, noisePill, contextLabel, centerLabel
local teamList: Frame
local vignette: Frame
local notifications: Frame
local banner: Frame, bannerTitle: TextLabel, bannerSub: TextLabel
local crouchButton, throwButton, exitButton
local bannerToken = 0
local wasOnCreak = false
local creakParts: { BasePart } = {}

local function attr(instance: Instance, name: string, default: any): any
	local value = instance:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

-- ---------------------------------------------------------------- notifications & banner
local KIND_COLORS = { good = Colors.green, bad = Colors.red, info = Colors.blue }

function Hud.notify(text: string, kind: string?)
	local frames = {}
	for _, child in notifications:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames >= 4 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	local frame = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.1,
		LayoutOrder = math.floor(os.clock() * 100), Parent = notifications,
	}, { UIKit.corner(10), UIKit.stroke(KIND_COLORS[kind or "info"] or Colors.blue, 2), UIKit.padding(10) })
	local label = UIKit.label({
		Text = text, TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame,
	})
	if kind == "bad" then
		Sounds.play("error")
	end
	task.delay(5, function()
		if frame.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			task.wait(0.45)
			frame:Destroy()
		end
	end)
end

function Hud.showBanner(title: string, subtitle: string)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerSub.Text = subtitle
	banner.Visible = true
	banner.Size = UDim2.fromOffset(560, 96)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(760, 126) }):Play()
	Sounds.play("event")
	task.delay(6, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------- rendering
local function onCreak(position: Vector3): boolean
	for _, zone in creakParts do
		local offset = position - zone.Position
		if math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Z) <= zone.Size.Z / 2 then
			return true
		end
	end
	return false
end

local function renderNoise(status: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if status ~= "playing" or not humanoid or not root or not root:IsA("BasePart") then
		noisePill.Visible = false
		wasOnCreak = false
		return
	end
	noisePill.Visible = true
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local soles = string.find(attr(player, "Upgrades", ""), "soles", 1, true) ~= nil
	local creaking = moving and not soles and onCreak(root.Position)
	if creaking and not wasOnCreak then
		Sounds.play("creak")
	end
	wasOnCreak = creaking
	if not moving then
		noiseLabel.Text = Text.Standing
		noiseLabel.TextColor3 = Colors.dim
	elseif creaking then
		noiseLabel.Text = Text.CrouchCreak
		noiseLabel.TextColor3 = Colors.red
	elseif attr(player, "Crouched", false) then
		noiseLabel.Text = Text.CrouchOn
		noiseLabel.TextColor3 = Colors.green
	else
		noiseLabel.Text = Text.CrouchOff
		noiseLabel.TextColor3 = Colors.accent
	end
end

local function renderTeam()
	UIKit.clear(teamList)
	local order = 0
	for _, other in Players:GetPlayers() do
		local status = attr(other, "Status", "lobby")
		if status ~= "lobby" then
			order += 1
			local complete = attr(other, "Complete", false)
			UIKit.label({
				Text = string.format("%s — %d/%d · %s", other.DisplayName, attr(other, "Delivered", 0), Needed,
					complete and status == "playing" and Text.Done or (Text.StatusNames[status] or "")),
				TextSize = 14, TextColor3 = complete and Colors.green or (status == "caught" and Colors.red or Colors.text),
				TextStrokeTransparency = 0.5, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order, Parent = teamList,
			})
		end
	end
end

local function render()
	local status = attr(player, "Status", "lobby")
	local phase = workspace:GetAttribute("Phase")
	local inRound = status ~= "lobby" and phase == "round"
	container.Visible = inRound
	if not inRound then
		vignette.Visible = false
		return
	end
	local now = workspace:GetServerTimeNow()

	-- objective, timer, hands
	objectiveLabel.Text = attr(player, "Complete", false) and Text.ObjectiveDone
		or string.format(Text.Objective, attr(player, "Delivered", 0), Needed)
	timerLabel.Text = string.format(Text.Timer, Config.formatTime((workspace:GetAttribute("PhaseEnds") or now) - now))
	local carried = attr(player, "Carried", "")
	if carried == "" then
		handsLabel.Text = string.format(Text.HandsEmpty, attr(player, "Capacity", 1))
	else
		local names = {}
		for _, id in string.split(carried, ",") do
			local snack = Config.Snacks[id]
			if snack then
				table.insert(names, snack.icon .. " " .. snack.name)
			end
		end
		handsLabel.Text = string.format(Text.Hands, table.concat(names, ", "))
	end

	renderTeam()
	renderNoise(status)

	-- context hint
	local holding = attr(player, "Holding", "")
	local tvLeft = (workspace:GetAttribute("TVUntil") or 0) - now
	if status == "hidden" then
		contextLabel.Text = Text.HiddenHint
	elseif holding ~= "" and Config.Items[holding] then
		contextLabel.Text = string.format(Text.HeldHint, Config.Items[holding].name)
	elseif tvLeft > 0 then
		contextLabel.Text = string.format(Text.TvOn, math.ceil(tvLeft))
	else
		contextLabel.Text = status == "playing" and Text.CrouchHint or ""
	end

	-- big centre message
	if status == "caught" then
		centerLabel.Text = Text.CaughtBig
	elseif status == "stunned" then
		centerLabel.Text = string.format(Text.StunnedHint, math.max(0, math.ceil(attr(player, "StunnedUntil", 0) - now)))
	elseif status == "sleeping" then
		centerLabel.Text = Text.SleepingHint
	else
		centerLabel.Text = ""
	end

	vignette.Visible = attr(player, "Chased", false)
	crouchButton.Visible = UserInputService.TouchEnabled and status == "playing"
	crouchButton.BackgroundColor3 = attr(player, "Crouched", false) and Colors.green or Colors.panel
	throwButton.Visible = UserInputService.TouchEnabled and status == "playing" and holding ~= ""
	exitButton.Visible = UserInputService.TouchEnabled and status == "hidden"
end

-- ---------------------------------------------------------------- build
local function pill(parent: Instance, order: number, width: number): TextLabel
	local frame = UIKit.new("Frame", {
		Size = UDim2.fromOffset(width, 42), BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.15,
		LayoutOrder = order, Parent = parent,
	}, { UIKit.corner(12), UIKit.stroke(Colors.panel, 2) })
	return UIKit.label({
		Text = "", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
		Size = UDim2.fromScale(1, 1), Parent = frame,
	})
end

local function vignetteEdge(position: UDim2, size: UDim2, anchor: Vector2, rotation: number)
	UIKit.new("Frame", {
		AnchorPoint = anchor, Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(230, 30, 30),
		BorderSizePixel = 0, Parent = vignette,
	}, {
		UIKit.new("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
end

function Hud.init()
	-- one scale for every screen size
	local scale = UIKit.new("UIScale", { Parent = gui })
	local function updateScale()
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1.3)
		end
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	-- red vignette (behind everything else)
	vignette = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	vignetteEdge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), Vector2.new(0, 0), 90)
	vignetteEdge(UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.2), Vector2.new(0, 1), 270)
	vignetteEdge(UDim2.fromScale(0, 0), UDim2.fromScale(0.14, 1), Vector2.new(0, 0), 0)
	vignetteEdge(UDim2.fromScale(1, 0), UDim2.fromScale(0.14, 1), Vector2.new(1, 0), 180)
	UIKit.label({
		Text = Text.Spotted, TextSize = 38, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 70, 60),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(700, 46), Parent = vignette,
	})

	container = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })

	-- top: objective and timer, then what is in the hands
	local topBar = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(640, 42),
		BackgroundTransparency = 1, Parent = container,
	}, { UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	objectiveLabel = pill(topBar, 1, 340)
	objectiveLabel.TextColor3 = Colors.accent
	timerLabel = pill(topBar, 2, 280)
	local handsBar = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.fromOffset(630, 42),
		BackgroundTransparency = 1, Parent = container,
	})
	handsLabel = pill(handsBar, 1, 630)

	-- left: the team
	local team = UIKit.new("Frame", {
		Position = UDim2.fromOffset(12, 110), Size = UDim2.fromOffset(300, 140), BackgroundTransparency = 1, Parent = container,
	})
	UIKit.label({
		Text = Text.Team, TextSize = 16, TextColor3 = Colors.accent, TextStrokeTransparency = 0.5,
		Size = UDim2.new(1, 0, 0, 22), Parent = team,
	})
	teamList = UIKit.new("Frame", {
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 1, Parent = team,
	}, { UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- bottom: noise indicator and context hint
	contextLabel = UIKit.label({
		Text = "", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(760, 24), Parent = container,
	})
	noisePill = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(300, 42),
		BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.15, Parent = container,
	}, { UIKit.corner(12), UIKit.stroke(Colors.panel, 2) })
	noiseLabel = UIKit.label({
		Text = "", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = noisePill,
	})

	-- centre: caught / in bed
	centerLabel = UIKit.label({
		Text = "", TextSize = 54, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(900, 70), Parent = container,
	})

	-- touch buttons
	local actions = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 200),
		BackgroundTransparency = 1, Parent = container,
	}, { UIKit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
	crouchButton = UIKit.button(Text.BtnCrouch, Colors.panel, function()
		Hud.callbacks.crouch()
	end, { Size = UDim2.fromOffset(160, 56), TextSize = 18, LayoutOrder = 1, Visible = false, Parent = actions })
	throwButton = UIKit.button(Text.BtnThrow, Colors.blue, function()
		Hud.callbacks.throw()
	end, { Size = UDim2.fromOffset(160, 56), TextSize = 18, LayoutOrder = 2, Visible = false, Parent = actions })
	exitButton = UIKit.button(Text.BtnExit, Colors.accent, function()
		Hud.callbacks.exit()
	end, { Size = UDim2.fromOffset(160, 56), TextSize = 18, LayoutOrder = 3, Visible = false, TextColor3 = Colors.bg, Parent = actions })

	-- notifications and banner (visible in the lobby too)
	notifications = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 56), Size = UDim2.fromOffset(340, 300),
		BackgroundTransparency = 1, Parent = gui,
	}, { UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	banner = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.27), Size = UDim2.fromOffset(760, 126),
		BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.2, Visible = false, ZIndex = 20, Parent = gui,
	}, { UIKit.corner(18), UIKit.stroke(Colors.accent, 3) })
	bannerTitle = UIKit.label({
		Text = "", Font = Enum.Font.GothamBlack, TextColor3 = Colors.accent, TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true, Position = UDim2.new(0.04, 0, 0.08, 0), Size = UDim2.new(0.92, 0, 0.5, 0), ZIndex = 21, Parent = banner,
	})
	bannerSub = UIKit.label({
		Text = "", TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
		Position = UDim2.new(0.04, 0, 0.62, 0), Size = UDim2.new(0.92, 0, 0.28, 0), ZIndex = 21, Parent = banner,
	})

	-- creaky floorboards, for the noise indicator
	task.spawn(function()
		local zones = workspace:WaitForChild("Map"):WaitForChild("CreakyZones")
		for _, zone in zones:GetChildren() do
			if zone:IsA("BasePart") then
				table.insert(creakParts, zone)
			end
		end
	end)

	-- server messages
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Hud.notify(text, kind)
		end
	end)
	Remotes:WaitForChild("Banner").OnClientEvent:Connect(function(title, subtitle)
		if type(title) == "string" then
			Hud.showBanner(title, type(subtitle) == "string" and subtitle or "")
		end
	end)
	Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, a)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if kind == "sound" and type(a) == "string" then
			Sounds.play(a)
		elseif kind == "spotted" then
			Sounds.play("spotted")
		elseif kind == "caught" then
			Sounds.play("caught")
			if humanoid then
				humanoid.PlatformStand = true
			end
		elseif kind == "stunned" or kind == "released" then
			if humanoid then
				humanoid.PlatformStand = false
			end
		elseif (kind == "thud" or kind == "tap") and typeof(a) == "Vector3" then
			Sounds.playAt(kind, a)
		end
	end)

	-- text refreshes a few times per second; the vignette pulses every frame
	task.spawn(function()
		while true do
			render()
			task.wait(0.2)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if vignette.Visible then
			local pulse = 0.25 + 0.2 * math.sin(os.clock() * 7)
			for _, edge in vignette:GetChildren() do
				if edge:IsA("Frame") then
					edge.BackgroundTransparency = pulse
				end
			end
		end
	end)
end

return Hud
