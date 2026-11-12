--[[
	Config — balance, data and EVERY player-facing string of «Тихий Час».
	Shared by server and client. All text shown to players lives in Config.Text and is Russian.
]]

local Config = {}

-- ---------------------------------------------------------------- rounds
Config.Round = {
	Duration = 360, -- 6 minutes «до рассвета»
	Countdown = 10,
	Results = 12,
	SnacksNeeded = 5,
	GraceTime = 6, -- seconds before Родитель starts patrolling
	MaxPlayers = 4,
	EventMinDelay = 40,
	EventMaxDelay = 70,
}

Config.Player = {
	RunSpeed = 16,
	CrouchSpeed = 7,
	PickupTime = 4,
	LuckMultiplier = 0.8, -- «Удача»: 20% faster pickup
	BaseCapacity = 1,
	BackpackCapacity = 3,
	StunTime = 10,
	InteractDistance = 11,
}

Config.Parent = {
	PatrolSpeed = 8,
	InvestigateSpeed = 10,
	ChaseSpeed = 16.5, -- player sprint speed
	CarrySpeed = 12,
	VisionAngle = 70, -- full cone, degrees
	VisionRange = 30,
	FlickerVisionRange = 12,
	ChaseVisionRange = 45, -- while chasing he keeps you in sight further
	TouchRange = 3.5, -- notices you at this distance even behind his back
	ReactionTime = 1,
	LoseSightTime = 5,
	CatchDistance = 4.5,
	SleepWakeChance = 0.35,
	SleepWakeRadius = 20,
}

-- Hearing radii in studs.
Config.Noise = {
	Run = 20,
	Crouch = 6,
	Creak = 35,
	Throw = 40,
	Tap = 32,
	Cat = 60,
	TvFactor = 0.5, -- TV halves everything
	TvDuration = 30,
	TvCooldown = 45,
	TapDuration = 6,
	TapCooldown = 30,
}

Config.Rewards = { PerSnack = 2, Win = 15, Complete = 10 }

-- ---------------------------------------------------------------- content
Config.SnackOrder = { "sandwich", "yogurt", "juice", "cookie", "icecream" }
Config.Snacks = {
	sandwich = { name = "Бутерброд", icon = "🥪", color = Color3.fromRGB(230, 190, 120) },
	yogurt = { name = "Йогурт", icon = "🥛", color = Color3.fromRGB(240, 240, 250) },
	juice = { name = "Сок", icon = "🧃", color = Color3.fromRGB(255, 170, 60) },
	cookie = { name = "Печенька", icon = "🍪", color = Color3.fromRGB(190, 130, 80) },
	icecream = { name = "Мороженое", icon = "🍦", color = Color3.fromRGB(250, 200, 220) },
}

-- Throwable items; the map parts are named Item_<kind><number>.
Config.Items = {
	slipper = { name = "Тапок" },
	ball = { name = "Мячик" },
}

Config.SkinOrder = { "default", "dots", "dino", "space", "gold" }
Config.Skins = {
	default = { name = "Своя одежда", price = 0 },
	dots = { name = "Пижама в горошек", price = 30, top = Color3.fromRGB(240, 120, 150), bottom = Color3.fromRGB(250, 220, 230) },
	dino = { name = "Пижама-динозавр", price = 80, top = Color3.fromRGB(90, 180, 90), bottom = Color3.fromRGB(60, 140, 70) },
	space = { name = "Пижама-космонавт", price = 150, top = Color3.fromRGB(235, 240, 250), bottom = Color3.fromRGB(70, 110, 200) },
	gold = { name = "Золотая пижама", price = 400, top = Color3.fromRGB(255, 205, 70), bottom = Color3.fromRGB(230, 170, 40) },
}

Config.UpgradeOrder = { "luck", "soles", "backpack" }
Config.Upgrades = {
	luck = { name = "Удача", price = 60, desc = "Берёшь перекус на 20% быстрее." },
	soles = { name = "Тапок-подошва", price = 90, desc = "Скрипучие половицы тебя больше не выдают." },
	backpack = { name = "Рюкзак", price = 120, desc = "Носи сразу 3 перекуса вместо одного." },
}

Config.EventOrder = { "cat", "sleep", "flicker" }
Config.Events = {
	cat = { name = "Кот пробежал!", desc = "Родитель идёт проверить коридор." },
	sleep = { name = "Родитель уснул на диване", desc = "20 секунд он ничего не видит. Но не бегай рядом!", duration = 20 },
	flicker = { name = "Свет мигнул", desc = "10 секунд темно: фонарик светит совсем близко.", duration = 10 },
}

-- ---------------------------------------------------------------- navigation
-- Waypoint graph (parts in Workspace.Map.Waypoints). Used when PathfindingService finds no path.
Config.Graph = {
	{ "CorridorW", "BedroomDoor" }, { "BedroomDoor", "BedroomIn" }, { "BedroomIn", "Bedroom" },
	{ "BedroomDoor", "LivingDoor" }, { "BedroomDoor", "BathDoor" }, { "LivingDoor", "BathDoor" },
	{ "BathDoor", "Bath" }, { "BathDoor", "CorridorC" }, { "LivingDoor", "CorridorC" },
	{ "CorridorC", "KitchenDoor" }, { "KitchenDoor", "KitchenIn" }, { "KitchenIn", "Kitchen" },
	{ "KitchenIn", "KitchenFridge" }, { "Kitchen", "KitchenFridge" },
	{ "KitchenDoor", "HallDoor" }, { "KitchenDoor", "CorridorE" }, { "HallDoor", "CorridorE" },
	{ "HallDoor", "HallIn" }, { "HallIn", "Hall" }, { "Hall", "LivingHall" },
	{ "LivingHall", "LivingE" }, { "LivingE", "Living" }, { "Living", "LivingIn" },
	{ "LivingIn", "LivingDoor" }, { "LivingIn", "SofaSide" }, { "SofaSide", "Sofa" },
}

-- коридор → кухня → гостиная → дверь спальни
Config.PatrolRoute = {
	"CorridorC", "KitchenIn", "Kitchen", "KitchenFridge", "CorridorE", "HallIn", "Hall",
	"LivingE", "Living", "LivingIn", "BedroomDoor", "BedroomIn", "CorridorW", "BathDoor",
}

-- ---------------------------------------------------------------- sounds
-- Sounds built into the Roblox client, used as placeholders. Swap the ids for your own.
Config.Sounds = {
	click = { id = "rbxasset://sounds/clickfast.wav", pitch = 1, volume = 0.5 },
	error = { id = "rbxasset://sounds/button.wav", pitch = 0.7, volume = 0.5 },
	pickup = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 1.6, volume = 0.5 },
	deliver = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 2.2, volume = 0.6, double = true },
	spotted = { id = "rbxasset://sounds/bass.wav", pitch = 1.6, volume = 0.9 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", pitch = 0.8, volume = 0.9 },
	creak = { id = "rbxasset://sounds/switch.wav", pitch = 0.5, volume = 0.8 },
	thud = { id = "rbxasset://sounds/collide.wav", pitch = 0.8, volume = 0.8 },
	event = { id = "rbxasset://sounds/bass.wav", pitch = 0.8, volume = 0.8, double = true },
	win = { id = "rbxasset://sounds/victory.wav", pitch = 1, volume = 0.7 },
	lose = { id = "rbxasset://sounds/bass.wav", pitch = 0.5, volume = 0.9 },
	cat = { id = "rbxasset://sounds/uuhhh.mp3", pitch = 2.4, volume = 0.6 },
	tap = { id = "rbxasset://sounds/splat.wav", pitch = 1.4, volume = 0.5 },
	hide = { id = "rbxasset://sounds/unsheath.wav", pitch = 0.8, volume = 0.5 },
}

-- ---------------------------------------------------------------- strings (Russian)
Config.Text = {
	Title = "Тихий Час",
	Subtitle = "Ночной поход за перекусом",

	-- HUD
	Objective = "Собери перекусы: %d/%d",
	ObjectiveDone = "Всё собрано! Помоги друзьям",
	Timer = "До рассвета: %s",
	Hands = "В руках: %s",
	HandsEmpty = "В руках пусто (влезет: %d)",
	CrouchOn = "Крадёшься — тихо",
	CrouchOff = "Бежишь — шумно!",
	CrouchCreak = "СКРИП! Половица!",
	Standing = "Стоишь — тишина",
	CrouchHint = "Ctrl — красться",
	Spotted = "Тебя заметили!",
	HiddenHint = "Ты спрятался. Нажми E, чтобы вылезти",
	HeldHint = "В руке: %s. Нажми F, чтобы бросить",
	CaughtBig = "Ага! Спать!",
	StunnedHint = "Лежи тихо… %d",
	SleepingHint = "Ты в кровати. Ждём остальных…",
	TvOn = "Телевизор шумит ещё %dс — Родитель хуже слышит",
	Team = "Команда",
	StatusNames = {
		playing = "крадётся", hidden = "спрятался", caught = "пойман",
		stunned = "в кровати", sleeping = "спит", lobby = "в подъезде",
	},
	Done = "готово!",

	-- buttons
	BtnCrouch = "Красться",
	BtnThrow = "Бросить",
	BtnExit = "Вылезти",
	BtnReady = "Готов",
	BtnNotReady = "Не готов",
	BtnShop = "Магазин",
	BtnBuy = "Купить\n%d ★",
	BtnEquip = "Надеть",
	BtnEquipped = "Надето",
	BtnOwned = "Куплено",

	-- proximity prompts
	PromptTake = "Взять",
	PromptBed = "Кровать",
	PromptDeliver = "Спрятать перекус",
	PromptSleep = "Лечь спать",
	PromptHide = "Спрятаться",
	PromptGrab = "Подобрать",
	PromptTvName = "Телевизор",
	PromptTv = "Включить",
	PromptTapName = "Раковина",
	PromptTap = "Открыть кран",
	SpotNames = { wardrobe = "Шкаф", bed = "Под кроватью", bath = "За шторкой" },

	-- notifications
	RoundStart = "Тихий час начался! Принеси 5 перекусов из кухни в спальню.",
	PickedUp = "Взято: %s. Неси в спальню!",
	HandsFull = "Руки заняты! Сначала отнеси перекус в кровать.",
	AlreadyEnough = "У тебя уже все 5 перекусов.",
	NothingToDeliver = "Нечего прятать. Перекусы — на кухне.",
	Delivered = "Спрятано под одеялом: %d из %d. +%d ★",
	Completed = "Все 5 перекусов у тебя! Теперь помоги друзьям.",
	TeammateCompleted = "%s собрал все перекусы!",
	Caught = "Родитель поймал тебя и несёт в кровать.",
	LostSnack = "По дороге потерялось: %s.",
	Released = "Можно вставать. Только тихо!",
	Hidden = "Тсс… Тебя не видно.",
	HiddenSeen = "Родитель видел, куда ты спрятался!",
	SpotBusy = "Тут уже кто-то сидит.",
	ItemGrabbed = "Подобрано: %s. Бросай клавишей F — отвлеки Родителя.",
	HandsItemBusy = "В руке уже есть предмет.",
	TvStarted = "Телевизор включён на 30 секунд: Родитель слышит вдвое хуже.",
	TvAlready = "Телевизор уже работает.",
	TvCooldown = "Телевизор остывает. Подожди немного.",
	TapStarted = "Кран зашумел! Родитель пойдёт проверять ванную.",
	TapCooldown = "Кран пока не трогай — подожди.",
	SleepNeedComplete = "Ложиться можно, когда хотя бы один из вас собрал все 5 перекусов.",
	Sleeping = "Ты лёг спать. Дождись остальных.",
	SpeedWarning = "Слишком быстро! Тебя вернули назад.",
	NoMoney = "Не хватает звёздочек.",
	Bought = "Куплено: %s!",
	ShopOnlyLobby = "Переодеться можно только в подъезде.",
	SaveUnavailable = "Сохранение сейчас недоступно — прогресс этой игры не запишется.",
	TooManyRequests = "Слишком много запросов. Перезайди в игру.",

	-- lobby
	Room = "Комната: %s",
	Players = "Игроки (%d из %d)",
	ReadyMark = "готов",
	NotReadyMark = "не готов",
	Stars = "Звёздочки: %d ★",
	Wins = "Победы: %d",
	LobbyHint = "Нажмите «Готов» — когда готовы все, лифт поедет.",
	Countdown = "Лифт едет в квартиру… %d",
	RoundRunning = "Идёт тихий час. До рассвета: %s. Подожди следующий раунд.",
	LobbySign = "ПОДЪЕЗД",
	LeaderStars = "Звёздочки",
	LeaderWins = "Победы",

	-- results
	Win = "Победа!",
	WinSub = "Перекусы под одеялом, все в кроватях. Сладких снов!",
	Lose = "Вас поймали...",
	LoseSub = "Рассвело раньше, чем вы успели.",
	ResultRow = "%s — %d/%d перекусов, +%d ★",
	BackToLobby = "Возвращаемся в подъезд через %d…",

	-- shop
	ShopTitle = "Магазин",
	ShopSkins = "Пижамы",
	ShopUpgrades = "Улучшения",
	ShopBalance = "У тебя: %d ★",

	-- Родитель
	ParentName = "Родитель",
	EmoteAlert = "!",
	EmoteSearch = "?",
	EmoteSleep = "Хррр… Zzz",
	EmoteCatch = "Ага! Спать!",
}

function Config.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Config
