--[[
	GameData — единый источник баланса и текстов игры «Сбежавший Урожай».
	Shared by server and client: seeds, rarities, mutations, upgrades, pets, events, sounds.
	All player-facing strings here are Russian.
]]

local GameData = {}

-- ---------------------------------------------------------------- config
GameData.Config = {
	StartMoney = 50,
	StartSeeds = { carrot = 2 },
	BaseSlots = 6,
	ExpansionSlots = 6,
	MutationTick = 5, -- seconds between mutation rolls on a ripe crop
	EscapeTime = 90, -- a creature that is not caught in this time is gone
	CatchTime = 3, -- seconds of holding E
	CatchRadius = 12,
	OwnershipTag = 20, -- seconds before a caught crop can be sold
	FenceTime = 15,
	TrapStun = 10,
	TrapRadius = 5,
	MaxTraps = 5,
	WhistleCooldown = 120,
	ExpansionRequirement = 250000,
	RebirthRequirement = 1000000,
	RebirthBonus = 0.25,
	PetRadius = 10,
	PetCooldown = 20,
	InventoryLimit = 150,
	MaxSeedStack = 999,
	EventMinDelay = 300,
	EventMaxDelay = 480,
	SellDistance = 20,
	PlantDistance = 16,
}

-- ---------------------------------------------------------------- rarities
GameData.Rarities = {
	common = { name = "Обычный", color = Color3.fromRGB(200, 200, 200), mutationChance = 0.05 },
	rare = { name = "Редкий", color = Color3.fromRGB(90, 170, 255), mutationChance = 0.15 },
	epic = { name = "Эпический", color = Color3.fromRGB(190, 110, 255), mutationChance = 0.35 },
	legendary = { name = "Легендарный", color = Color3.fromRGB(255, 176, 46), mutationChance = 0.60 },
	secret = { name = "Секретный", color = Color3.fromRGB(255, 92, 132), mutationChance = 1.00 },
}

-- ---------------------------------------------------------------- seeds
-- gender ("m"/"f") is used to agree the mutation adjective with the crop name.
GameData.SeedOrder = { "carrot", "potato", "tomato", "watermelon", "corn", "pumpkin", "golden" }
GameData.Seeds = {
	carrot = {
		name = "Морковь", crop = "Морковь", gender = "f", rarity = "common",
		price = 10, growTime = 60, sellPrice = 25,
		head = { shape = "Block", size = Vector3.new(1.2, 2.2, 1.2), color = Color3.fromRGB(245, 140, 40) },
		bodyColor = Color3.fromRGB(230, 120, 30), leafColor = Color3.fromRGB(80, 180, 70),
	},
	potato = {
		name = "Картошка", crop = "Картошка", gender = "f", rarity = "common",
		price = 20, growTime = 75, sellPrice = 45,
		head = { shape = "Block", size = Vector3.new(2, 1.5, 1.6), color = Color3.fromRGB(176, 136, 86) },
		bodyColor = Color3.fromRGB(150, 112, 70), leafColor = Color3.fromRGB(96, 160, 70),
	},
	tomato = {
		name = "Помидор", crop = "Помидор", gender = "m", rarity = "rare",
		price = 100, growTime = 100, sellPrice = 220,
		head = { shape = "Ball", size = Vector3.new(2, 2, 2), color = Color3.fromRGB(226, 60, 50) },
		bodyColor = Color3.fromRGB(190, 44, 40), leafColor = Color3.fromRGB(60, 150, 60),
	},
	watermelon = {
		name = "Арбуз", crop = "Арбуз", gender = "m", rarity = "rare",
		price = 250, growTime = 120, sellPrice = 520,
		head = { shape = "Ball", size = Vector3.new(2.6, 2.6, 2.6), color = Color3.fromRGB(64, 150, 70) },
		bodyColor = Color3.fromRGB(40, 110, 54), leafColor = Color3.fromRGB(30, 90, 40),
	},
	corn = {
		name = "Кукуруза", crop = "Кукуруза", gender = "f", rarity = "epic",
		price = 1000, growTime = 150, sellPrice = 2200,
		head = { shape = "Block", size = Vector3.new(1.3, 2.5, 1.3), color = Color3.fromRGB(250, 214, 70) },
		bodyColor = Color3.fromRGB(120, 180, 70), leafColor = Color3.fromRGB(110, 190, 80),
	},
	pumpkin = {
		name = "Тыква", crop = "Тыква", gender = "f", rarity = "legendary",
		price = 5000, growTime = 180, sellPrice = 11000,
		head = { shape = "Ball", size = Vector3.new(2.8, 2.8, 2.8), color = Color3.fromRGB(240, 130, 30) },
		bodyColor = Color3.fromRGB(200, 100, 24), leafColor = Color3.fromRGB(70, 130, 50),
	},
	golden = {
		name = "Золотое Семя", crop = "Золотой Плод", gender = "m", rarity = "secret",
		price = 50000, growTime = 180, sellPrice = 120000, requiresRebirth = 1,
		head = { shape = "Ball", size = Vector3.new(2.3, 2.3, 2.3), color = Color3.fromRGB(255, 214, 60) },
		bodyColor = Color3.fromRGB(230, 180, 40), leafColor = Color3.fromRGB(255, 240, 150),
	},
}

-- ---------------------------------------------------------------- mutations
GameData.MutationOrder = { "infected", "sentient", "flying", "royal", "titan" }
GameData.Mutations = {
	infected = {
		nameM = "Заражённый", nameF = "Заражённая", multiplier = 2, weight = 55,
		color = Color3.fromRGB(140, 220, 90), speed = 14, scale = 1,
	},
	sentient = {
		nameM = "Разумный", nameF = "Разумная", multiplier = 5, weight = 28,
		color = Color3.fromRGB(110, 190, 255), speed = 16, scale = 1,
	},
	flying = {
		nameM = "Летающий", nameF = "Летающая", multiplier = 15, weight = 12,
		color = Color3.fromRGB(200, 160, 255), speed = 17, scale = 1, canFly = true,
	},
	royal = {
		nameM = "Королевский", nameF = "Королевская", multiplier = 50, weight = 4,
		color = Color3.fromRGB(255, 208, 60), speed = 18, scale = 1.2, aura = true,
	},
	titan = {
		suffix = "Титан", multiplier = 200, weight = 1,
		color = Color3.fromRGB(255, 96, 80), speed = 11, scale = 3, stomp = true,
	},
}

GameData.Phrases = { "Я ЖИВОЙ!", "ЛОВИ МЕНЯ!", "НЕ ПОЙМАЕШЬ!" }
GameData.Stages = { "Росток", "Растёт", "Созрел" }

-- ---------------------------------------------------------------- upgrades & pets
GameData.UpgradeOrder = { "fence", "trap", "whistle" }
GameData.Upgrades = {
	fence = {
		name = "Забор", price = 5000,
		desc = "Сбежавший урожай с твоей грядки первые 15 секунд не может её покинуть.",
	},
	trap = {
		name = "Липкая Ловушка", price = 2500,
		desc = "Одна ловушка на карте. Первый урожай, который на неё наступит, прилипнет на 10 секунд.",
	},
	whistle = {
		name = "Свисток", price = 15000,
		desc = "Возвращает весь твой сбежавший урожай ко входу на грядку. Перезарядка 2 минуты.",
	},
}

GameData.PetOrder = { "dog", "cat", "fox" }
GameData.Pets = {
	dog = { name = "Пёс Шарик", price = 50000, bonus = 0, color = Color3.fromRGB(176, 124, 78) },
	cat = { name = "Кот Мурзик", price = 150000, bonus = 0.10, color = Color3.fromRGB(240, 150, 60) },
	fox = { name = "Лиса Алиса", price = 400000, bonus = 0.25, color = Color3.fromRGB(232, 96, 40) },
}

-- ---------------------------------------------------------------- events
GameData.EventOrder = { "night", "rain", "silence" }
GameData.Events = {
	night = {
		name = "Ночь Большого Побега", duration = 20,
		desc = "Весь созревший урожай оживает! Лови, пока не разбежался!",
		color = Color3.fromRGB(150, 130, 255),
	},
	rain = {
		name = "Золотой Дождь", duration = 60,
		desc = "Шанс мутации увеличен в 3 раза!",
		color = Color3.fromRGB(255, 208, 60),
	},
	silence = {
		name = "Тишина", duration = 60,
		desc = "Мутаций нет. Можно спокойно выращивать урожай.",
		color = Color3.fromRGB(150, 220, 200),
	},
}

-- ---------------------------------------------------------------- sounds
-- Built-in client sounds used as placeholders, so the game has audio without uploading assets.
-- Replace the ids with your own rbxassetid:// sounds at any time.
GameData.Sounds = {
	plant = { id = "rbxasset://sounds/Kerplunk.wav", pitch = 1.2, volume = 0.6 },
	grow = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 1.6, volume = 0.4 },
	scream = { id = "rbxasset://sounds/uuhhh.mp3", pitch = 1.8, volume = 0.9 },
	catch = { id = "rbxasset://sounds/victory.wav", pitch = 1.2, volume = 0.6 },
	sell = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 2.2, volume = 0.7, double = true },
	alarm = { id = "rbxasset://sounds/bass.wav", pitch = 0.7, volume = 0.9, double = true },
	click = { id = "rbxasset://sounds/clickfast.wav", pitch = 1, volume = 0.5 },
	error = { id = "rbxasset://sounds/button.wav", pitch = 0.7, volume = 0.5 },
	stomp = { id = "rbxasset://sounds/collide.wav", pitch = 0.5, volume = 1 },
	whistle = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 3, volume = 0.7, double = true },
	trap = { id = "rbxasset://sounds/splat.wav", pitch = 1, volume = 0.7 },
}

-- ---------------------------------------------------------------- helpers
-- "$12 500", "$1.25 млн"
function GameData.formatMoney(amount: number): string
	local n = math.floor(amount + 0.5)
	if n >= 1e9 then
		return string.format("$%.2f млрд", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.2f млн", n / 1e6)
	end
	local reversed = string.reverse(tostring(n))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	local out = string.reverse(grouped)
	out = string.gsub(out, "^ ", "")
	return "$" .. out
end

-- "Морковь", "Королевская Тыква", "Арбуз-Титан"
function GameData.itemName(seedId: string, mutationId: string?): string
	local seed = GameData.Seeds[seedId]
	if not seed then
		return "?"
	end
	local mutation = mutationId and GameData.Mutations[mutationId]
	if not mutation then
		return seed.crop
	end
	if mutation.suffix then
		return seed.crop .. "-" .. mutation.suffix
	end
	return (seed.gender == "f" and mutation.nameF or mutation.nameM) .. " " .. seed.crop
end

-- sellMultiplier = rebirth bonus * pet bonus (see GameData.sellMultiplier)
function GameData.itemPrice(seedId: string, mutationId: string?, sellMultiplier: number?): number
	local seed = GameData.Seeds[seedId]
	if not seed then
		return 0
	end
	local mutation = mutationId and GameData.Mutations[mutationId]
	local price = seed.sellPrice * (mutation and mutation.multiplier or 1) * (sellMultiplier or 1)
	return math.floor(price + 0.5)
end

function GameData.sellMultiplier(rebirths: number, petId: string?): number
	local pet = petId and GameData.Pets[petId]
	return (1 + GameData.Config.RebirthBonus * rebirths) * (1 + (pet and pet.bonus or 0))
end

-- weighted random mutation id
function GameData.rollMutation(rng: Random): string
	local total = 0
	for _, id in GameData.MutationOrder do
		total += GameData.Mutations[id].weight
	end
	local roll = rng:NextNumber() * total
	for _, id in GameData.MutationOrder do
		roll -= GameData.Mutations[id].weight
		if roll <= 0 then
			return id
		end
	end
	return GameData.MutationOrder[1]
end

function GameData.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return GameData
