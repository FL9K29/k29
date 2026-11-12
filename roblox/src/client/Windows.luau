--[[
	Windows — the three windows of the game, all in Russian:
	  shop      «Магазин семян»
	  inventory «Инвентарь» (also the sell window)
	  upgrades  «Улучшения» (defense, expansion, pets, rebirth)
	Buttons only send requests; the server decides and sends the new state back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local State = require(script.Parent:WaitForChild("ClientState"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Config = GameData.Config
local Colors = UIKit.Colors
local money = GameData.formatMoney

local Windows = {}
local windows: { [string]: any } = {} -- [name] = { frame, content, footer, render }
local current: string? = nil
local rebirthArmedAt = 0 -- the rebirth button must be pressed twice

function Windows.close()
	if current then
		windows[current].frame.Visible = false
		current = nil
	end
end

function Windows.open(name: string)
	if current == name then
		return
	end
	Windows.close()
	current = name
	windows[name].frame.Visible = true
	windows[name].render()
end

function Windows.toggle(name: string)
	if current == name then
		Windows.close()
	else
		Windows.open(name)
	end
end

-- Row with a title, a description and up to two buttons on the right.
local function actionRow(parent: Instance, order: number, title: string, titleColor: Color3, desc: string, buttons)
	local row = UIKit.row(parent, 76, order)
	local buttonsWidth = #buttons * 150
	UIKit.label({
		Text = title, TextSize = 18, TextColor3 = titleColor, ZIndex = 13,
		Position = UDim2.fromOffset(22, 8), Size = UDim2.new(1, -(buttonsWidth + 36), 0, 22), Parent = row,
	})
	UIKit.label({
		Text = desc, TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Colors.dim, ZIndex = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(22, 32), Size = UDim2.new(1, -(buttonsWidth + 36), 0, 40), Parent = row,
	})
	for index, info in buttons do
		local button = UIKit.button(info.text, info.color or Colors.green, info.callback or function() end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10 - (#buttons - index) * 150, 0.5, 0),
			Size = UDim2.fromOffset(142, 54), TextSize = 14, ZIndex = 13, Parent = row,
		})
		if info.enabled == false then
			UIKit.setEnabled(button, false)
		end
	end
	return row
end

local function header(parent: Instance, order: number, text: string)
	UIKit.label({
		Text = text, TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = Colors.accent,
		Size = UDim2.new(1, -12, 0, 26), LayoutOrder = order, ZIndex = 12, Parent = parent,
	})
end

-- ---------------------------------------------------------------- shop
local function renderShop()
	local window = windows.shop
	local data = State.data
	UIKit.clear(window.content)
	if not data then
		return
	end
	for order, id in GameData.SeedOrder do
		local seed = GameData.Seeds[id]
		local rarity = GameData.Rarities[seed.rarity]
		local locked = seed.requiresRebirth ~= nil and data.rebirths < seed.requiresRebirth
		local desc = string.format("Рост: %dс · Шанс мутации: %d%% · Продажа: %s\nУ тебя семян: %d",
			seed.growTime, math.floor(rarity.mutationChance * 100 + 0.5),
			money(GameData.itemPrice(id, nil, State.sellMultiplier())), data.seeds[id] or 0)
		local buttons
		if locked then
			buttons = { { text = "Откроется после Перерождения", enabled = false } }
		else
			buttons = {
				{
					text = "Купить 1\n" .. money(seed.price), enabled = data.money >= seed.price,
					callback = function()
						Remotes.Buy:FireServer("seed", id, 1)
					end,
				},
				{
					text = "Купить 10\n" .. money(seed.price * 10), color = Colors.blue, enabled = data.money >= seed.price * 10,
					callback = function()
						Remotes.Buy:FireServer("seed", id, 10)
					end,
				},
			}
		end
		local row = actionRow(window.content, order, seed.name .. " — " .. rarity.name, rarity.color, desc, buttons)
		UIKit.new("Frame", {
			Position = UDim2.fromOffset(6, 8), Size = UDim2.new(0, 8, 1, -16), BackgroundColor3 = rarity.color,
			BorderSizePixel = 0, ZIndex = 13, Parent = row,
		}, { UIKit.corner(4) })
	end
end

-- ---------------------------------------------------------------- inventory / selling
local function renderInventory()
	local window = windows.inventory
	local data = State.data
	UIKit.clear(window.content)
	if not data then
		return
	end
	local elapsed = State.elapsed()
	local multiplier = State.sellMultiplier()

	-- group identical crops into one row
	local groups, order = {}, {}
	local total, sellable = 0, 0
	for _, item in data.inventory do
		local key = item.s .. "|" .. (item.m or "")
		local group = groups[key]
		if not group then
			group = { s = item.s, m = item.m, count = 0, locked = 0, lockLeft = 0, price = GameData.itemPrice(item.s, item.m, multiplier) }
			groups[key] = group
			table.insert(order, group)
		end
		group.count += 1
		local left = item.l - elapsed
		if left > 0 then
			group.locked += 1
			group.lockLeft = math.max(group.lockLeft, left)
		else
			total += group.price
			sellable += 1
		end
	end
	table.sort(order, function(a, b)
		return a.price > b.price
	end)

	if #order == 0 then
		UIKit.label({
			Text = "Пока пусто. Собери созревший урожай или поймай сбежавший!", TextSize = 16, TextColor3 = Colors.dim,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -12, 0, 80), ZIndex = 12, Parent = window.content,
		})
	end
	for index, group in order do
		local mutation = group.m and GameData.Mutations[group.m]
		local row = UIKit.row(window.content, 58, index)
		UIKit.label({
			Text = string.format("%s  x%d", GameData.itemName(group.s, group.m), group.count), TextSize = 17,
			TextColor3 = mutation and mutation.color or Colors.text, ZIndex = 13,
			Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -220, 0, 24), Parent = row,
		})
		local note = mutation and string.format("Мутация: цена x%d", mutation.multiplier) or "Обычный урожай"
		if group.locked > 0 then
			note = string.format("Метка владения: %dс (%d шт.)", math.ceil(group.lockLeft), group.locked)
		end
		UIKit.label({
			Text = note, TextSize = 13, Font = Enum.Font.GothamMedium, ZIndex = 13,
			TextColor3 = group.locked > 0 and Colors.red or Colors.dim,
			Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -220, 0, 20), Parent = row,
		})
		UIKit.label({
			Text = money(group.price) .. " за шт.", TextSize = 16, TextColor3 = Colors.accent, ZIndex = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(190, 24), Parent = row,
		})
	end

	window.totalLabel.Text = string.format("Итого к продаже: %s  (%d шт.)\nМест в инвентаре: %d из %d",
		money(total), sellable, #data.inventory, Config.InventoryLimit)
	UIKit.setEnabled(window.sellButton, sellable > 0, Colors.green)
end

-- ---------------------------------------------------------------- upgrades
local function renderUpgrades()
	local window = windows.upgrades
	local data = State.data
	UIKit.clear(window.content)
	if not data then
		return
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function buy(kind: string, id: string)
		return function()
			Remotes.Buy:FireServer(kind, id)
		end
	end

	header(window.content, nextOrder(), "Защита грядки")
	local fence = GameData.Upgrades.fence
	actionRow(window.content, nextOrder(), fence.name, Colors.text, fence.desc, {
		data.upgrades.fence and { text = "Куплено", enabled = false }
			or { text = "Купить\n" .. money(fence.price), enabled = data.money >= fence.price, callback = buy("upgrade", "fence") },
	})

	local trap = GameData.Upgrades.trap
	actionRow(window.content, nextOrder(), string.format("%s (в запасе: %d)", trap.name, data.upgrades.traps), Colors.text,
		trap.desc .. (data.trapPlaced and " Сейчас одна стоит на карте." or ""), {
			{
				text = "Купить\n" .. money(trap.price), callback = buy("upgrade", "trap"),
				enabled = data.money >= trap.price and data.upgrades.traps < Config.MaxTraps,
			},
			{
				text = data.trapPlaced and "Переставить\n[T]" or "Поставить\n[T]", color = Colors.blue,
				enabled = data.trapPlaced or data.upgrades.traps > 0,
				callback = function()
					Remotes.PlaceTrap:FireServer()
				end,
			},
		})

	local whistle = GameData.Upgrades.whistle
	local whistleLeft = math.ceil(data.whistleLeft - State.elapsed())
	local whistleButton
	if not data.upgrades.whistle then
		whistleButton = { text = "Купить\n" .. money(whistle.price), enabled = data.money >= whistle.price, callback = buy("upgrade", "whistle") }
	elseif whistleLeft > 0 then
		whistleButton = { text = string.format("Перезарядка\n%dс", whistleLeft), enabled = false }
	else
		whistleButton = {
			text = "Свистнуть\n[Q]", color = Colors.blue,
			callback = function()
				Remotes.Whistle:FireServer()
			end,
		}
	end
	actionRow(window.content, nextOrder(), whistle.name, Colors.text, whistle.desc, { whistleButton })

	header(window.content, nextOrder(), "Развитие")
	local expansionButton
	if data.expanded then
		expansionButton = { text = "Куплено", enabled = false }
	elseif data.money < Config.ExpansionRequirement then
		expansionButton = { text = "Нужно\n" .. money(Config.ExpansionRequirement), enabled = false }
	else
		expansionButton = { text = "Купить\n" .. money(Config.ExpansionRequirement), callback = buy("upgrade", "expansion") }
	end
	actionRow(window.content, nextOrder(), "Расширение", Colors.text,
		"+6 лунок на грядке и место для питомца. Открывается, когда накопишь " .. money(Config.ExpansionRequirement) .. ".",
		{ expansionButton })

	header(window.content, nextOrder(), "Питомцы")
	for _, id in GameData.PetOrder do
		local pet = GameData.Pets[id]
		local desc = string.format("Сам ловит твой сбежавший урожай в %d шагах раз в %d секунд.", Config.PetRadius, Config.PetCooldown)
		if pet.bonus > 0 then
			desc ..= string.format(" Цены продажи +%d%%.", math.floor(pet.bonus * 100 + 0.5))
		end
		local button
		if not data.expanded then
			button = { text = "Нужно\n«Расширение»", enabled = false }
		elseif data.pet == id then
			button = { text = "Выбран", enabled = false }
		elseif data.pets[id] then
			button = {
				text = "Выбрать", color = Colors.blue,
				callback = function()
					Remotes.EquipPet:FireServer(id)
				end,
			}
		else
			button = { text = "Купить\n" .. money(pet.price), enabled = data.money >= pet.price, callback = buy("pet", id) }
		end
		actionRow(window.content, nextOrder(), pet.name, pet.color, desc, { button })
	end

	header(window.content, nextOrder(), "Перерождение")
	local armed = os.clock() - rebirthArmedAt < 5
	local rebirthButton
	if data.money < Config.RebirthRequirement then
		rebirthButton = { text = "Нужно\n" .. money(Config.RebirthRequirement), enabled = false }
	else
		rebirthButton = {
			text = armed and "Точно?\nНажми ещё раз" or "Переродиться", color = armed and Colors.red or Colors.accent,
			callback = function()
				if os.clock() - rebirthArmedAt < 5 then
					rebirthArmedAt = 0
					Remotes.Rebirth:FireServer()
				else
					rebirthArmedAt = os.clock()
					renderUpgrades()
				end
			end,
		}
	end
	actionRow(window.content, nextOrder(),
		string.format("Перерождение (сейчас: %d, бонус +%d%%)", data.rebirths, math.floor(data.rebirths * Config.RebirthBonus * 100 + 0.5)),
		Colors.accent,
		"Сбрасывает деньги, семена и урожай. Взамен: навсегда +25% к ценам продажи и «Золотое Семя» в магазине. Улучшения и питомцы остаются.",
		{ rebirthButton })
end

-- ---------------------------------------------------------------- init
function Windows.init()
	local gui = script.Parent

	local shop = UIKit.window(gui, "Магазин семян", 0, Windows.close) :: any
	shop.render = renderShop
	windows.shop = shop

	local inventory = UIKit.window(gui, "Инвентарь", 66, Windows.close) :: any
	inventory.render = renderInventory
	inventory.totalLabel = UIKit.label({
		Text = "", TextSize = 15, ZIndex = 12,
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -230, 1, 0), Parent = inventory.footer,
	})
	inventory.sellButton = UIKit.button("Продать Урожай", Colors.green, function()
		Remotes.Sell:FireServer()
	end, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(200, 48), TextSize = 17, ZIndex = 12, Parent = inventory.footer,
	})
	windows.inventory = inventory

	local upgrades = UIKit.window(gui, "Улучшения", 0, Windows.close) :: any
	upgrades.render = renderUpgrades
	windows.upgrades = upgrades

	State.changed:Connect(function()
		if current then
			windows[current].render()
		end
	end)
	-- ownership tags and the whistle cooldown tick down while a window is open
	task.spawn(function()
		while true do
			task.wait(1)
			if current == "inventory" or current == "upgrades" then
				windows[current].render()
			end
		end
	end)
end

return Windows
