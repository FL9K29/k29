--[[
	ClientState — the latest snapshot of the player's profile sent by the server,
	plus the seed currently selected for planting. UI modules listen to State.changed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = {}
State.data = nil :: any -- nil until the first snapshot arrives
State.receivedAt = 0 -- os.clock() of the last snapshot (for local countdowns)
State.selectedSeed = nil :: string?

local changedEvent = Instance.new("BindableEvent")
State.changed = changedEvent.Event

local function fixSelection()
	local seeds = State.data and State.data.seeds or {}
	if State.selectedSeed and (seeds[State.selectedSeed] or 0) > 0 then
		return
	end
	State.selectedSeed = nil
	for _, id in GameData.SeedOrder do
		if (seeds[id] or 0) > 0 then
			State.selectedSeed = id
			return
		end
	end
end

function State.select(seedId: string)
	State.selectedSeed = seedId
	changedEvent:Fire()
end

-- Seconds since the last snapshot; used to count server timers down locally.
function State.elapsed(): number
	return os.clock() - State.receivedAt
end

function State.sellMultiplier(): number
	local data = State.data
	if not data then
		return 1
	end
	return GameData.sellMultiplier(data.rebirths, data.pet)
end

function State.init()
	Remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(snapshot)
		State.data = snapshot
		State.receivedAt = os.clock()
		fixSelection()
		changedEvent:Fire()
	end)
	Remotes:WaitForChild("RequestState"):FireServer()
end

return State
