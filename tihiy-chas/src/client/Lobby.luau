--[[
	Lobby — everything outside the round, all in Russian:
	  * lobby panel: room code, player list with «готов» marks, Звёздочки, «Готов» and «Магазин»
	  * lift countdown text
	  * results screen: «Победа!» / «Вас поймали...»
	  * the shop window: пижамы and upgrades
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Text = Config.Text
local Colors = UIKit.Colors
local Needed = Config.Round.SnacksNeeded

local Lobby = {}

local gui = script.Parent
local panel: Frame, roomLabel: TextLabel, playersLabel: TextLabel, playerList: Frame
local statsLabel: TextLabel, statusLabel: TextLabel, readyButton: TextButton
local results: Frame, resultTitle: TextLabel, resultSub: TextLabel, resultList: Frame, resultFooter: TextLabel
local shop: any
local shopOpen = false

local function attr(instance: Instance, name: string, default: any): any
	local value = instance:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function owns(listAttribute: string, id: string): boolean
	for _, owned in string.split(attr(player, listAttribute, ""), ",") do
		if owned == id then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- shop
local function shopRow(order: number, title: string, desc: string, buttonText: string, color: Color3, enabled: boolean, callback: () -> ())
	local row = UIKit.row(shop.content, 70, order)
	UIKit.label({
		Text = title, TextSize = 18, ZIndex = 13,
		Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -190, 0, 22), Parent = row,
	})
	UIKit.label({
		Text = desc, TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Colors.dim, ZIndex = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -190, 0, 34), Parent = row,
	})
	local button = UIKit.button(buttonText, color, callback, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 50), TextSize = 15, ZIndex = 13, Parent = row,
	})
	if not enabled then
		UIKit.setEnabled(button, false)
	end
end

local function shopHeader(order: number, text: string)
	UIKit.label({
		Text = text, TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = Colors.accent,
		Size = UDim2.new(1, -12, 0, 26), LayoutOrder = order, ZIndex = 12, Parent = shop.content,
	})
end

local function renderShop()
	if not shopOpen then
		return
	end
	UIKit.clear(shop.content)
	local stars = attr(player, "Stars", 0)
	local equipped = attr(player, "Skin", "default")
	local order = 1
	shopHeader(order, string.format(Text.ShopBalance, stars))

	order += 1
	shopHeader(order, Text.ShopSkins)
	for _, id in Config.SkinOrder do
		local skin = Config.Skins[id]
		order += 1
		if equipped == id then
			shopRow(order, skin.name, "", Text.BtnEquipped, Colors.grey, false, function() end)
		elseif owns("Skins", id) then
			shopRow(order, skin.name, "", Text.BtnEquip, Colors.blue, true, function()
				Remotes.Equip:FireServer(id)
			end)
		else
			shopRow(order, skin.name, "", string.format(Text.BtnBuy, skin.price), Colors.green, stars >= skin.price, function()
				Remotes.Buy:FireServer("skin", id)
			end)
		end
	end

	order += 1
	shopHeader(order, Text.ShopUpgrades)
	for _, id in Config.UpgradeOrder do
		local upgrade = Config.Upgrades[id]
		order += 1
		if owns("Upgrades", id) then
			shopRow(order, upgrade.name, upgrade.desc, Text.BtnOwned, Colors.grey, false, function() end)
		else
			shopRow(order, upgrade.name, upgrade.desc, string.format(Text.BtnBuy, upgrade.price), Colors.green,
				stars >= upgrade.price, function()
					Remotes.Buy:FireServer("upgrade", id)
				end)
		end
	end
end

local function setShop(open: boolean)
	shopOpen = open
	shop.frame.Visible = open
	renderShop()
end

-- ---------------------------------------------------------------- lobby panel & results
local function renderLobby(phase: string, now: number)
	local everyone = Players:GetPlayers()
	roomLabel.Text = string.format(Text.Room, workspace:GetAttribute("RoomCode") or "")
	playersLabel.Text = string.format(Text.Players, #everyone, Config.Round.MaxPlayers)
	UIKit.clear(playerList)
	for order, other in everyone do
		local status = attr(other, "Status", "lobby")
		local ready = attr(other, "Ready", false)
		local mark = status ~= "lobby" and (Text.StatusNames[status] or "") or (ready and Text.ReadyMark or Text.NotReadyMark)
		UIKit.label({
			Text = string.format("%s — %s", other.DisplayName, mark), TextSize = 16,
			TextColor3 = (status == "lobby" and ready) and Colors.green or Colors.text,
			Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, Parent = playerList,
		})
	end
	statsLabel.Text = string.format(Text.Stars, attr(player, "Stars", 0)) .. "   " .. string.format(Text.Wins, attr(player, "Wins", 0))

	local left = (workspace:GetAttribute("PhaseEnds") or now) - now
	if phase == "countdown" then
		statusLabel.Text = string.format(Text.Countdown, math.max(0, math.ceil(left)))
		statusLabel.TextColor3 = Colors.accent
	elseif phase == "round" or phase == "results" then
		statusLabel.Text = string.format(Text.RoundRunning, Config.formatTime(phase == "round" and left or 0))
		statusLabel.TextColor3 = Colors.dim
	else
		statusLabel.Text = Text.LobbyHint
		statusLabel.TextColor3 = Colors.dim
	end

	local ready = attr(player, "Ready", false)
	readyButton.Text = ready and Text.BtnNotReady or Text.BtnReady
	readyButton.BackgroundColor3 = ready and Colors.red or Colors.green
	readyButton.Visible = phase == "lobby" or phase == "countdown"
end

local function renderResults(now: number)
	local win = workspace:GetAttribute("Result") == "win"
	resultTitle.Text = win and Text.Win or Text.Lose
	resultTitle.TextColor3 = win and Colors.green or Colors.red
	resultSub.Text = win and Text.WinSub or Text.LoseSub
	UIKit.clear(resultList)
	local order = 0
	for _, other in Players:GetPlayers() do
		if attr(other, "Status", "lobby") ~= "lobby" then
			order += 1
			UIKit.label({
				Text = string.format(Text.ResultRow, other.DisplayName, attr(other, "Delivered", 0), Needed, attr(other, "RoundStars", 0)),
				TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = attr(other, "Complete", false) and Colors.accent or Colors.text,
				Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, Parent = resultList,
			})
		end
	end
	local left = (workspace:GetAttribute("PhaseEnds") or now) - now
	resultFooter.Text = string.format(Text.BackToLobby, math.max(0, math.ceil(left)))
end

local function render()
	local status = attr(player, "Status", "lobby")
	local phase = workspace:GetAttribute("Phase") or "lobby"
	local now = workspace:GetServerTimeNow()
	local showResults = phase == "results" and status ~= "lobby"

	results.Visible = showResults
	if showResults then
		renderResults(now)
	end
	panel.Visible = status == "lobby"
	if status == "lobby" then
		renderLobby(phase, now)
	elseif shopOpen then
		setShop(false) -- the shop is only for the lobby
	end
end

-- ---------------------------------------------------------------- build
function Lobby.init()
	panel = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(400, 500),
		BackgroundColor3 = Colors.bg, BackgroundTransparency = 0.08, Visible = false, Parent = gui,
	}, { UIKit.corner(16), UIKit.stroke(Colors.accent, 3) })
	UIKit.label({
		Text = Text.Title, TextSize = 36, Font = Enum.Font.GothamBlack, TextColor3 = Colors.accent,
		Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 42), Parent = panel,
	})
	UIKit.label({
		Text = Text.Subtitle, TextSize = 15, TextColor3 = Colors.dim,
		Position = UDim2.fromOffset(20, 54), Size = UDim2.new(1, -40, 0, 20), Parent = panel,
	})
	roomLabel = UIKit.label({ Text = "", TextSize = 18, Position = UDim2.fromOffset(20, 86), Size = UDim2.new(1, -40, 0, 24), Parent = panel })
	playersLabel = UIKit.label({
		Text = "", TextSize = 16, TextColor3 = Colors.accent,
		Position = UDim2.fromOffset(20, 120), Size = UDim2.new(1, -40, 0, 22), Parent = panel,
	})
	playerList = UIKit.new("Frame", {
		Position = UDim2.fromOffset(20, 146), Size = UDim2.new(1, -40, 0, 110), BackgroundTransparency = 1, Parent = panel,
	}, { UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	statsLabel = UIKit.label({
		Text = "", TextSize = 16, TextColor3 = Colors.accent,
		Position = UDim2.fromOffset(20, 264), Size = UDim2.new(1, -40, 0, 22), Parent = panel,
	})
	statusLabel = UIKit.label({
		Text = "", TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(20, 296), Size = UDim2.new(1, -40, 0, 62), Parent = panel,
	})
	readyButton = UIKit.button(Text.BtnReady, Colors.green, function()
		Remotes.Ready:FireServer(not attr(player, "Ready", false))
	end, { Position = UDim2.fromOffset(20, 368), Size = UDim2.new(1, -40, 0, 54), TextSize = 22, Parent = panel })
	UIKit.button(Text.BtnShop, Colors.blue, function()
		setShop(not shopOpen)
	end, { Position = UDim2.fromOffset(20, 432), Size = UDim2.new(1, -40, 0, 48), TextSize = 19, Parent = panel })

	-- results
	results = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 16), BackgroundTransparency = 0.25,
		Visible = false, ZIndex = 30, Parent = gui,
	})
	resultTitle = UIKit.label({
		Text = "", TextSize = 84, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.fromOffset(1000, 96), ZIndex = 31, Parent = results,
	})
	resultSub = UIKit.label({
		Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 104), Size = UDim2.fromOffset(1000, 32),
		ZIndex = 31, Parent = results,
	})
	resultList = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 160), Size = UDim2.fromOffset(800, 150),
		BackgroundTransparency = 1, ZIndex = 31, Parent = results,
	}, { UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	resultFooter = UIKit.label({
		Text = "", TextSize = 18, TextColor3 = Colors.dim, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(800, 26),
		ZIndex = 31, Parent = results,
	})

	-- shop window
	shop = UIKit.window(gui, Text.ShopTitle, 0, function()
		setShop(false)
	end)
	for _, name in { "Stars", "Skin", "Skins", "Upgrades" } do
		player:GetAttributeChangedSignal(name):Connect(renderShop)
	end

	task.spawn(function()
		while true do
			render()
			task.wait(0.2)
		end
	end)
end

return Lobby
