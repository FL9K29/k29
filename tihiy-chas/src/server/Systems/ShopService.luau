--[[
	ShopService — spending Звёздочки: пижамы (skins) and the three upgrades
	(Рюкзак, Тапок-подошва, Удача). Prices and ownership are checked on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AntiExploit = require(script.Parent.AntiExploit)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text

local ShopService = {}

-- Paints the character as a pajama: plain coloured top and bottom plus a nightcap.
local function applySkin(player: Player)
	local profile = PlayerData.get(player)
	local character = player.Character
	local skin = profile and Config.Skins[profile.data.skin]
	if not character or not skin or not skin.top then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	colors.TorsoColor3 = skin.top
	colors.LeftArmColor3 = skin.top
	colors.RightArmColor3 = skin.top
	colors.LeftLegColor3 = skin.bottom
	colors.RightLegColor3 = skin.bottom

	local head = character:FindFirstChild("Head")
	local cap = character:FindFirstChild("Nightcap")
	if head and head:IsA("BasePart") then
		if not cap then
			local part = Instance.new("Part")
			part.Name = "Nightcap"
			part.Size = Vector3.new(1.3, 0.7, 1.3)
			part.Material = Enum.Material.Fabric
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.3, 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
			part.Parent = character
			cap = part
		end
		(cap :: BasePart).Color = skin.top
	end
end

local function onCharacter(player: Player)
	task.spawn(function()
		local waited = 0
		while not player:HasAppearanceLoaded() and waited < 5 do
			waited += task.wait(0.2)
		end
		applySkin(player)
	end)
end

local function equip(player: Player, skinId: string)
	local profile = PlayerData.get(player)
	local s = Session.get(player)
	if not profile or not s or not profile.data.skins[skinId] or profile.data.skin == skinId then
		return
	end
	if s.status ~= "lobby" then
		PlayerData.notify(player, Text.ShopOnlyLobby, "bad")
		return
	end
	profile.data.skin = skinId
	PlayerData.sync(player)
	-- respawning restores the original clothes before the new pajama is painted on
	player:LoadCharacter()
end

local function onBuy(player: Player, kind: any, id: any)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if kind == "skin" and AntiExploit.isId(id, Config.Skins) then
		local skin = Config.Skins[id]
		if profile.data.skins[id] then
			return
		end
		if not PlayerData.spend(player, skin.price) then
			PlayerData.notify(player, Text.NoMoney, "bad")
			return
		end
		profile.data.skins[id] = true
		PlayerData.sync(player)
		PlayerData.notify(player, string.format(Text.Bought, skin.name), "good")
		equip(player, id)
	elseif kind == "upgrade" and AntiExploit.isId(id, Config.Upgrades) then
		local upgrade = Config.Upgrades[id]
		if profile.data.upgrades[id] then
			return
		end
		if not PlayerData.spend(player, upgrade.price) then
			PlayerData.notify(player, Text.NoMoney, "bad")
			return
		end
		profile.data.upgrades[id] = true
		PlayerData.sync(player)
		local s = Session.get(player)
		if s then
			Session.sync(s) -- carrying capacity may have changed
		end
		PlayerData.notify(player, string.format(Text.Bought, upgrade.name), "good")
	end
end

function ShopService.init()
	AntiExploit.connect(Remotes.Buy, 2, 4, onBuy)
	AntiExploit.connect(Remotes.Equip, 1, 2, function(player, skinId)
		if AntiExploit.isId(skinId, Config.Skins) then
			equip(player, skinId)
		end
	end)
	PlayerData.onLoaded(function(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			onCharacter(player)
		end
	end)
end

return ShopService
