--[[
	Hud — always-visible interface: top bar (Деньги, Доход, таймер события), menu buttons,
	seed bar, action buttons, catch meter, notifications and the big event banner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local State = require(script.Parent:WaitForChild("ClientState"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Windows = require(script.Parent:WaitForChild("Windows"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Colors = UIKit.Colors
local money = GameData.formatMoney

local Hud = {}
-- Set by Controller: what the action buttons do.
Hud.callbacks = {
	catchHold = function(_holding: boolean) end,
	whistle = function() end,
	trap = function() end,
}

local gui = script.Parent
local moneyLabel, incomeLabel, eventLabel
local seedBar, seedHint
local whistleButton, trapButton
local meter, meterFill, meterLabel, catchHint
local notifications
local banner, bannerTitle, bannerSub
local bannerToken = 0

-- ---------------------------------------------------------------- notifications
local KIND_COLORS = { good = Colors.green, bad = Colors.red, info = Colors.blue }

function Hud.notify(text: string, kind: string?)
	local children = notifications:GetChildren()
	local frames = {}
	for _, child in children do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames >= 5 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end

	local frame = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.1,
		LayoutOrder = math.floor(os.clock() * 100), Parent = notifications,
	}, { UIKit.corner(10), UIKit.stroke(KIND_COLORS[kind or "info"] or Colors.blue, 2) })
	local label = UIKit.label({
		Text = text, TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame,
	})
	UIKit.padding(10).Parent = frame
	if kind == "bad" then
		Effects.play("error")
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

-- ---------------------------------------------------------------- event banner
function Hud.showBanner(title: string, subtitle: string, color: Color3)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSub.Text = subtitle
	banner.Visible = true
	bannerTitle.TextTransparency = 0
	bannerSub.TextTransparency = 0
	banner.Size = UDim2.fromOffset(600, 100)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(820, 136) }):Play()
	task.delay(6, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------- catch meter
-- fraction 0..1; 0 hides the meter.
function Hud.setCatch(fraction: number)
	meter.Visible = fraction > 0
	meterFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	meterLabel.Text = string.format("Ловлю… %d%%", math.floor(math.clamp(fraction, 0, 1) * 100))
end

function Hud.setCatchHint(visible: boolean)
	catchHint.Visible = visible and not meter.Visible
end

-- ---------------------------------------------------------------- state rendering
local function renderSeedBar()
	UIKit.clear(seedBar)
	local data = State.data
	local any = false
	if data then
		for order, id in GameData.SeedOrder do
			local count = data.seeds[id] or 0
			if count > 0 then
				any = true
				local seed = GameData.Seeds[id]
				local selected = State.selectedSeed == id
				local button = UIKit.button(string.format("%s\nx%d", seed.name, count), Colors.panel, function()
					State.select(id)
				end, { Size = UDim2.fromOffset(116, 54), TextSize = 14, LayoutOrder = order, Parent = seedBar })
				button.TextColor3 = GameData.Rarities[seed.rarity].color
				UIKit.stroke(selected and Colors.accent or Colors.bg, selected and 4 or 2).Parent = button
			end
		end
	end
	seedHint.Text = any and "Выбери семя и нажми F у своей грядки" or "Семян нет — загляни в Магазин"
end

local function render()
	local data = State.data
	if not data then
		return
	end
	moneyLabel.Text = "Деньги: " .. money(data.money)
	incomeLabel.Text = "Доход: " .. money(data.income) .. "/мин"
	renderSeedBar()
	whistleButton.Visible = data.upgrades.whistle
	trapButton.Visible = data.trapPlaced or data.upgrades.traps > 0
	trapButton.Text = string.format("Ловушка [T]\nв запасе: %d", data.upgrades.traps)
end

local function tick()
	local now = workspace:GetServerTimeNow()
	local active = workspace:GetAttribute("ActiveEvent")
	local event = active and GameData.Events[active]
	if event then
		local ends = workspace:GetAttribute("ActiveEventEnds") or now
		eventLabel.Text = string.format("%s: %s", event.name, GameData.formatTime(ends - now))
		eventLabel.TextColor3 = event.color
	else
		local nextAt = workspace:GetAttribute("NextEventAt")
		eventLabel.Text = nextAt and ("Событие через: " .. GameData.formatTime(nextAt - now)) or "Событие: скоро"
		eventLabel.TextColor3 = Colors.text
	end

	local data = State.data
	if data and data.upgrades.whistle then
		local left = math.ceil(data.whistleLeft - State.elapsed())
		whistleButton.Text = left > 0 and string.format("Свисток\n%dс", left) or "Свисток [Q]"
		UIKit.setEnabled(whistleButton, left <= 0, Colors.blue)
	end
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

function Hud.init()
	-- keep the layout readable on phones and big monitors alike
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

	-- top bar
	local topBar = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(760, 42),
		BackgroundTransparency = 1, Parent = gui,
	}, { UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	moneyLabel = pill(topBar, 1, 220)
	moneyLabel.TextColor3 = Colors.accent
	incomeLabel = pill(topBar, 2, 220)
	incomeLabel.TextColor3 = Colors.green
	eventLabel = pill(topBar, 3, 300)

	-- menu buttons (left)
	local menu = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(160, 170),
		BackgroundTransparency = 1, Parent = gui,
	}, { UIKit.list(Enum.FillDirection.Vertical, 8) })
	local menuItems = { { "Магазин", "shop", Colors.green }, { "Инвентарь", "inventory", Colors.blue }, { "Улучшения", "upgrades", Colors.accent } }
	for order, item in menuItems do
		local button = UIKit.button(item[1], item[3], function()
			Windows.toggle(item[2])
		end, { Size = UDim2.fromOffset(160, 50), TextSize = 18, LayoutOrder = order, Parent = menu })
		UIKit.stroke(Colors.bg, 2).Parent = button
	end

	-- action buttons (right)
	local actions = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 200),
		BackgroundTransparency = 1, Parent = gui,
	}, { UIKit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
	local catchButton = UIKit.button("ЛОВИТЬ", Colors.red, function() end, {
		Size = UDim2.fromOffset(160, 70), TextSize = 22, LayoutOrder = 1, Visible = UserInputService.TouchEnabled, Parent = actions,
	})
	catchButton.MouseButton1Down:Connect(function()
		Hud.callbacks.catchHold(true)
	end)
	catchButton.MouseButton1Up:Connect(function()
		Hud.callbacks.catchHold(false)
	end)
	catchButton.MouseLeave:Connect(function()
		Hud.callbacks.catchHold(false)
	end)
	whistleButton = UIKit.button("Свисток [Q]", Colors.blue, function()
		Hud.callbacks.whistle()
	end, { Size = UDim2.fromOffset(160, 50), LayoutOrder = 2, Visible = false, Parent = actions })
	trapButton = UIKit.button("Ловушка [T]", Colors.accent, function()
		Hud.callbacks.trap()
	end, { Size = UDim2.fromOffset(160, 50), LayoutOrder = 3, Visible = false, TextColor3 = Colors.bg, Parent = actions })

	-- seed bar (bottom)
	seedHint = UIKit.label({
		Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(600, 20), Parent = gui,
	})
	seedBar = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(0, 58),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = gui,
	}, { UIKit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })

	-- catch meter
	catchHint = UIKit.label({
		Text = UserInputService.TouchEnabled and "Удерживай кнопку «ЛОВИТЬ»" or "Удерживай E, чтобы поймать",
		TextSize = 18, TextColor3 = Colors.accent, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.fromOffset(500, 26),
		Visible = false, Parent = gui,
	})
	meter = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -108), Size = UDim2.fromOffset(360, 34),
		BackgroundColor3 = Colors.bg, Visible = false, Parent = gui,
	}, { UIKit.corner(10), UIKit.stroke(Colors.accent, 2) })
	meterFill = UIKit.new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.green, Parent = meter,
	}, { UIKit.corner(10) })
	meterLabel = UIKit.label({
		Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = meter,
	})

	-- notifications (right top)
	notifications = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 56), Size = UDim2.fromOffset(340, 300),
		BackgroundTransparency = 1, Parent = gui,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- event banner
	banner = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(820, 136),
		BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.2, Visible = false, ZIndex = 20, Parent = gui,
	}, { UIKit.corner(18), UIKit.stroke(Colors.accent, 3) })
	bannerTitle = UIKit.label({
		Text = "", TextSize = 46, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
		Position = UDim2.new(0.04, 0, 0.08, 0), Size = UDim2.new(0.92, 0, 0.52, 0), ZIndex = 21, Parent = banner,
	})
	bannerSub = UIKit.label({
		Text = "", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
		Position = UDim2.new(0.04, 0, 0.64, 0), Size = UDim2.new(0.92, 0, 0.26, 0), ZIndex = 21, Parent = banner,
	})

	-- wiring
	State.changed:Connect(render)
	Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			Hud.notify(text, kind)
		end
	end)
	Remotes:WaitForChild("EventAnnounce").OnClientEvent:Connect(function(id)
		local event = GameData.Events[id]
		if event then
			Effects.play("alarm")
			Hud.showBanner(event.name, event.desc, event.color)
		end
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.25)
		end
	end)
end

return Hud
