--[[
	EventService — random events during a round, announced with a banner:
	  cat     «Кот пробежал!» — noise in the corridor, Родитель goes to check it
	  sleep   «Родитель уснул на диване» — 20 s without vision (running nearby may wake him)
	  flicker «Свет мигнул» — lamps off for 10 s, his flashlight only reaches 12 studs
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(script.Parent.Noise)
local NpcBrain = require(script.Parent.NpcBrain)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes

local EventService = {}
local token = 0 -- changes whenever the round starts or stops; old loops then exit
local rng = Random.new()
local lampsOn = true

local function announce(id: string)
	local event = Config.Events[id]
	Remotes.Banner:FireAllClients(event.name, event.desc)
end

local function setLamps(on: boolean)
	lampsOn = on
	for _, lamp in World.lamps do
		lamp.light.Enabled = on
		lamp.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

local function runCat()
	announce("cat")
	local from = World.nodes.CorridorW
	local to = World.nodes.CorridorE
	Remotes.Effect:FireAllClients("cat", from, to)
	local centre = World.nodes.CorridorC
	Noise.emit(centre, Config.Noise.Cat, "cat")
	NpcBrain.lure(centre)
end

local function runFlicker(myToken: number)
	announce("flicker")
	setLamps(false)
	NpcBrain.setVisionRange(Config.Parent.FlickerVisionRange)
	task.wait(Config.Events.flicker.duration)
	-- a newer round may have started meanwhile; it restores the lamps itself
	if token == myToken then
		setLamps(true)
		NpcBrain.setVisionRange(nil)
	end
end

local function run(id: string, myToken: number)
	if id == "cat" then
		runCat()
	elseif id == "sleep" then
		local started = NpcBrain.goSleep(Config.Events.sleep.duration, function()
			if token == myToken then
				announce("sleep")
			end
		end)
		if not started then
			runCat() -- he is busy chasing somebody: the cat comes instead
		end
	elseif id == "flicker" then
		runFlicker(myToken)
	end
end

function EventService.start()
	token += 1
	local myToken = token
	task.spawn(function()
		local last = nil
		while token == myToken do
			task.wait(rng:NextInteger(Config.Round.EventMinDelay, Config.Round.EventMaxDelay))
			if token ~= myToken then
				break
			end
			local id
			repeat
				id = Config.EventOrder[rng:NextInteger(1, #Config.EventOrder)]
			until id ~= last
			last = id
			run(id, myToken)
		end
	end)
end

function EventService.stop()
	token += 1
	if not lampsOn then
		setLamps(true)
	end
	NpcBrain.setVisionRange(nil)
end

return EventService
