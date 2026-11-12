--[[
	Noise — a tiny message bus for sounds Родитель can hear.
	Anything noisy calls Noise.emit(position, radius, kind); NpcBrain listens.
	While the TV plays, every radius is halved.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Noise = {}
Noise.tvUntil = 0 -- os.clock() time until which the TV masks noise
local listeners = {}

function Noise.factor(): number
	return os.clock() < Noise.tvUntil and Config.Noise.TvFactor or 1
end

-- kind: "step" | "throw" | "tap" | "cat"
function Noise.emit(position: Vector3, radius: number, kind: string)
	local effective = radius * Noise.factor()
	for _, listener in listeners do
		listener(position, effective, kind)
	end
end

function Noise.listen(listener: (Vector3, number, string) -> ())
	table.insert(listeners, listener)
end

return Noise
