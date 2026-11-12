--[[
	Main — server entry point. Loads every system module in dependency order.
	Each system is a ModuleScript under Systems and exposes init().
]]

local Systems = script.Parent:WaitForChild("Systems")

local ORDER = {
	"World", -- map references, prompts, signs
	"PlayerData", -- Звёздочки, skins, upgrades, wins; DataStore
	"Session", -- per-round state of every player
	"StealthService", -- crouch, footstep noise, speed checks, stun timer
	"HideService", -- шкафы, под кроватью, за шторкой
	"NpcBrain", -- Родитель: patrol, senses, chase, carry
	"SnackService", -- pickup, delivery, going to bed
	"InteractService", -- throwables, TV, bathroom tap
	"EventService", -- кот, сон на диване, свет мигнул
	"ShopService", -- пижамы and upgrades
	"RoundManager", -- lobby → countdown → round → results
}

for _, name in ORDER do
	local module = require(Systems:WaitForChild(name)) :: any
	if module.init then
		module.init()
	end
end

print("[Тихий Час] сервер запущен")
