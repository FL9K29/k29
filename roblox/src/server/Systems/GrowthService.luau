--[[
	GrowthService — growth stages (Росток → Растёт → Созрел) and mutation rolls.
	Everything is timed on the server; clients only see the result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local CreatureService = require(script.Parent.CreatureService)
local PlayerData = require(script.Parent.PlayerData)
local PlotService = require(script.Parent.PlotService)

local Remotes = ReplicatedStorage.Remotes
local Config = GameData.Config

local GrowthService = {}
GrowthService.multiplier = 1 -- mutation chance multiplier, set by events (0 = no mutations)
GrowthService.forceMutation = false -- "Ночь Большого Побега": every ripe crop mutates
GrowthService.speed = 1 -- growth speed (Studio debug only)

local rng = Random.new()

local function mutate(plot, slot)
	local crop = slot.crop
	local owner = plot.owner
	local profile = owner and PlayerData.get(owner)
	if not crop or not owner or not profile then
		return
	end
	local position = slot.part.Position
	local seedId = crop.seedId
	PlotService.removeCrop(plot, slot)
	CreatureService.spawn(owner, seedId, GameData.rollMutation(rng), position, plot, profile.data.upgrades.fence)
end

local function setLabel(crop, text: string)
	if crop.label.Text ~= text then
		crop.label.Text = text
	end
end

function GrowthService.tick(dt: number)
	local now = os.clock()
	for _, plot in PlotService.plots do
		if not plot.owner then
			continue
		end
		for _, slot in plot.slots do
			local crop = slot.crop
			if not crop then
				continue
			end
			if crop.stage < 3 then
				crop.progress += dt * GrowthService.speed
				local fraction = crop.progress / crop.growTime
				local stage = fraction >= 1 and 3 or (fraction >= 0.33 and 2 or 1)
				if stage ~= crop.stage then
					PlotService.setStage(plot, slot, stage)
					Remotes.Effect:FireClient(plot.owner, "sound", "grow")
					if stage == 3 then
						crop.nextRoll = now + Config.MutationTick
					end
				end
				if stage < 3 then
					setLabel(crop, string.format("%s · %dс", GameData.Stages[stage], math.ceil(crop.growTime - crop.progress)))
					continue
				end
			end

			-- ripe: roll for a mutation once per growth tick
			setLabel(crop, GameData.Stages[3] .. "!")
			if GrowthService.forceMutation then
				mutate(plot, slot)
			elseif now >= crop.nextRoll then
				crop.nextRoll = now + Config.MutationTick
				local rarity = GameData.Rarities[GameData.Seeds[crop.seedId].rarity]
				local chance = math.min(1, rarity.mutationChance * GrowthService.multiplier)
				if rng:NextNumber() < chance then
					mutate(plot, slot)
				end
			end
		end
	end
end

function GrowthService.init()
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			GrowthService.tick(dt)
		end
	end)
end

return GrowthService
