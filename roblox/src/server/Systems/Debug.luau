--[[
	Debug — test switches that work ONLY in Roblox Studio (never on a published server).
	Set them on Workspace from the server command bar or the Properties panel:

	  workspace:SetAttribute("DebugGrowSpeed", 20)    -- crops grow 20x faster
	  workspace:SetAttribute("DebugMoney", 300000)    -- give this much money to every player
	  workspace:SetAttribute("DebugEvent", "night")   -- start an event: night | rain | silence
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EventService = require(script.Parent.EventService)
local GrowthService = require(script.Parent.GrowthService)
local PlayerData = require(script.Parent.PlayerData)

local Debug = {}

function Debug.init()
	if not RunService:IsStudio() then
		return
	end
	workspace:GetAttributeChangedSignal("DebugGrowSpeed"):Connect(function()
		local speed = workspace:GetAttribute("DebugGrowSpeed")
		GrowthService.speed = type(speed) == "number" and math.clamp(speed, 1, 100) or 1
	end)
	workspace:GetAttributeChangedSignal("DebugMoney"):Connect(function()
		local amount = workspace:GetAttribute("DebugMoney")
		if type(amount) == "number" and amount > 0 then
			for _, player in Players:GetPlayers() do
				PlayerData.addMoney(player, amount, false)
			end
			workspace:SetAttribute("DebugMoney", nil)
		end
	end)
	workspace:GetAttributeChangedSignal("DebugEvent"):Connect(function()
		local id = workspace:GetAttribute("DebugEvent")
		if type(id) == "string" then
			EventService.force(id)
			workspace:SetAttribute("DebugEvent", nil)
		end
	end)
end

return Debug
