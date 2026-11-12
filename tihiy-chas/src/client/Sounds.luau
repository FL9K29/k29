--[[
	Sounds — plays the sounds listed in Config.Sounds (2D, or quieter with distance).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local HEAR_DISTANCE = 90

local Sounds = {}
local templates = {} -- [name] = Sound

function Sounds.play(name: string, volumeScale: number?)
	local template = templates[name]
	local info = Config.Sounds[name]
	if not template or not info then
		return
	end
	local function once(pitch: number)
		local sound = template:Clone()
		sound.PlaybackSpeed = pitch
		sound.Volume = info.volume * (volumeScale or 1)
		sound.Parent = SoundService
		sound:Play()
		task.delay(6, function()
			sound:Destroy()
		end)
	end
	once(info.pitch)
	if info.double then
		task.delay(0.16, once, info.pitch * 1.25)
	end
end

-- Quieter the further the camera is from the position.
function Sounds.playAt(name: string, position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < HEAR_DISTANCE then
		Sounds.play(name, 1 - distance / HEAR_DISTANCE * 0.8)
	end
end

function Sounds.init()
	for name, info in Config.Sounds do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = info.id
		sound.Parent = script
		templates[name] = sound
	end
	UIKit.onClick = function()
		Sounds.play("click")
	end
end

return Sounds
