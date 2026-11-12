--[[
	Main — server entry point. Loads every system module in dependency order.
	Each system lives in its own ModuleScript under Systems and exposes init().
]]

local Systems = script.Parent:WaitForChild("Systems")

local ORDER = {
	"World", -- map references, signs, prompts
	"PlayerData", -- profiles, saving, state replication
	"PlotService", -- garden plots, planting, harvesting
	"CreatureService", -- escaped crops and their AI
	"GrowthService", -- growth stages and mutation rolls
	"CatchService", -- catch meter
	"PetService", -- pets that auto-catch
	"SellService", -- sell stand
	"ShopService", -- seeds, upgrades, pets, expansion, rebirth
	"EventService", -- random server events
	"Debug", -- Studio-only test switches
}

for _, name in ORDER do
	local module = require(Systems:WaitForChild(name)) :: any
	if module.init then
		module.init()
	end
end

print("[Сбежавший Урожай] сервер запущен")
