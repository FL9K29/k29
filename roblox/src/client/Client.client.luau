--[[
	Client — entry point of the Russian UI. Loads the UI modules in order.
	The ScreenGui (MainGui) itself is the container for everything they build.
]]

local folder = script.Parent

local State = require(folder:WaitForChild("ClientState"))
require(folder:WaitForChild("UIKit"))
local Effects = require(folder:WaitForChild("Effects"))
local Windows = require(folder:WaitForChild("Windows"))
local Hud = require(folder:WaitForChild("Hud"))
local Controller = require(folder:WaitForChild("Controller"))

Effects.init()
Windows.init()
Hud.init()
Controller.init()
State.init() -- last: asks the server for the first state snapshot
