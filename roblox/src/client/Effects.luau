--[[
	Effects — sounds, the leg animation of escaped crops and the titan knockdown.
	The server only moves creatures; legs are swung here so it costs no network traffic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local HEAR_DISTANCE = 140

local Effects = {}
local templates = {} -- [name] = Sound

-- volumeScale lets distant sounds play quieter.
function Effects.play(name: string, volumeScale: number?)
	local template = templates[name]
	local info = GameData.Sounds[name]
	if not template or not info then
		return
	end
	local function once(pitch: number)
		local sound = template:Clone()
		sound.PlaybackSpeed = pitch
		sound.Volume = info.volume * (volumeScale or 1)
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
		task.delay(6, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	once(info.pitch)
	if info.double then
		task.delay(0.14, once, info.pitch * 1.25)
	end
end

local function playAt(name: string, position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < HEAR_DISTANCE then
		Effects.play(name, 1 - distance / HEAR_DISTANCE * 0.8)
	end
end

local function knockdown(from: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(1, 0, 0)
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = away.Unit * 38 + Vector3.new(0, 36, 0)
	task.delay(1.5, function()
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

local function animateLegs()
	local folder = workspace:FindFirstChild("Creatures")
	if not folder then
		return
	end
	local now = os.clock()
	for _, model in folder:GetChildren() do
		local root = model:FindFirstChild("Root")
		local left = root and root:FindFirstChild("LeftHip")
		local right = root and root:FindFirstChild("RightHip")
		if left and right and left:IsA("Motor6D") and right:IsA("Motor6D") then
			local scale = model:GetAttribute("Scale") or 1
			local speed = model:GetAttribute("Speed") or 14
			local swing = model:GetAttribute("Stunned") and 0 or math.sin(now * speed * 0.9 / math.sqrt(scale)) * 0.9
			left.C0 = CFrame.new(-0.5 * scale, -0.8 * scale, 0) * CFrame.Angles(swing, 0, 0)
			right.C0 = CFrame.new(0.5 * scale, -0.8 * scale, 0) * CFrame.Angles(-swing, 0, 0)
		end
	end
end

function Effects.init()
	for name, info in GameData.Sounds do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = info.id
		sound.Parent = script
		templates[name] = sound
	end
	UIKit.onClick = function()
		Effects.play("click")
	end

	Remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, a)
		if kind == "sound" and type(a) == "string" then
			Effects.play(a)
		elseif kind == "scream" and typeof(a) == "Vector3" then
			playAt("scream", a)
		elseif kind == "stomp" and typeof(a) == "Vector3" then
			playAt("stomp", a)
		elseif kind == "trap" and typeof(a) == "Vector3" then
			playAt("trap", a)
		elseif kind == "caught" and typeof(a) == "Vector3" then
			playAt("grow", a)
		elseif kind == "knockdown" and typeof(a) == "Vector3" then
			knockdown(a)
		end
	end)
	RunService.RenderStepped:Connect(animateLegs)
end

return Effects
