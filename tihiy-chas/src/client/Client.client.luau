--[[
	Client — entry point of the Russian UI. Loads the client modules in order.
	MainGui (the ScreenGui) is the container for everything they build.
]]

local folder = script.Parent

require(folder:WaitForChild("UIKit"))
local Sounds = require(folder:WaitForChild("Sounds"))
local ParentVisual = require(folder:WaitForChild("ParentVisual"))
local Hud = require(folder:WaitForChild("Hud"))
local Lobby = require(folder:WaitForChild("Lobby"))
local Controls = require(folder:WaitForChild("Controls"))

Sounds.init()
ParentVisual.init()
Hud.init()
Lobby.init()
Controls.init()
