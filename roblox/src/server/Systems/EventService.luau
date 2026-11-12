--[[
	EventService — random server-wide events every 5–8 minutes.
	  night   «Ночь Большого Побега» — every ripe crop mutates (20 s)
	  rain    «Золотой Дождь»        — mutation chances x3 (60 s)
	  silence «Тишина»               — no mutations (60 s)
	Clients read the timers from Workspace attributes: NextEventAt, ActiveEvent, ActiveEventEnds.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameData = require(ReplicatedStorage.Shared.GameData)
local GrowthService = require(script.Parent.GrowthService)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local EventService = {}
local forced: string? = nil -- Studio debug: start this event right away
local rng = Random.new()

local DAY_CLOCK = 14
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "EventTint"
tint.Parent = Lighting

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Sine), goal):Play()
end

local function apply(id: string)
	if id == "night" then
		tween(Lighting, 2, { ClockTime = 0 })
		tween(tint, 2, { TintColor = Color3.fromRGB(190, 190, 255) })
		GrowthService.forceMutation = true
		GrowthService.tick(0) -- mutate everything that is already ripe, right now
	elseif id == "rain" then
		tween(tint, 2, { TintColor = Color3.fromRGB(255, 236, 170) })
		GrowthService.multiplier = 3
	elseif id == "silence" then
		tween(tint, 2, { Saturation = -0.35 })
		GrowthService.multiplier = 0
	end
end

local function revert()
	GrowthService.forceMutation = false
	GrowthService.multiplier = 1
	tween(Lighting, 2, { ClockTime = DAY_CLOCK })
	tween(tint, 2, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
end

local function run(id: string)
	local event = GameData.Events[id]
	workspace:SetAttribute("ActiveEvent", id)
	workspace:SetAttribute("ActiveEventEnds", workspace:GetServerTimeNow() + event.duration)
	Remotes.EventAnnounce:FireAllClients(id, event.duration)
	apply(id)
	task.wait(event.duration)
	revert()
	workspace:SetAttribute("ActiveEvent", nil)
	workspace:SetAttribute("ActiveEventEnds", nil)
end

function EventService.force(id: string)
	if GameData.Events[id] then
		forced = id
	end
end

function EventService.init()
	task.spawn(function()
		while true do
			local delay = rng:NextInteger(Config.EventMinDelay, Config.EventMaxDelay)
			workspace:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + delay)
			local deadline = os.clock() + delay
			while os.clock() < deadline and not forced do
				task.wait(0.5)
			end
			local id = forced or GameData.EventOrder[rng:NextInteger(1, #GameData.EventOrder)]
			forced = nil
			run(id)
		end
	end)
end

return EventService
