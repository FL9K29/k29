--[[
	NpcBrain — «Родитель», the threat. Everything here runs on the server.

	States:
	  idle        no round is running
	  wait        short grace period at the start of a round
	  patrol      walks Config.PatrolRoute, stops and looks around at each waypoint
	  investigate goes to a noise, looks around, returns to patrol
	  alert       saw a player: 1 second «!» reaction
	  chase       runs after the target; gives up 5 s after losing sight
	  grab/carry  «Ага! Спать!» — carries the caught player to their bed
	  gotoSleep   walking to the sofa (event)
	  sleep       asleep on the sofa: no vision, running nearby may wake him

	He is kinematic: an invisible anchored root part moved along paths from Navigation
	(PathfindingService with the waypoint graph as fallback). Clients draw the visible body.
	Vision is a server-side cone check plus a raycast; hearing comes from the Noise bus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HideService = require(script.Parent.HideService)
local Navigation = require(script.Parent.Navigation)
local Noise = require(script.Parent.Noise)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local World = require(script.Parent.World)

local Remotes = ReplicatedStorage.Remotes
local Text = Config.Text
local P = Config.Parent

local ROOT_HEIGHT = 3
local EYE_HEIGHT = 5
local TURN_RATE = 7 -- radians per second
local COS_HALF_CONE = math.cos(math.rad(P.VisionAngle / 2))
-- the caught kid is carried lying across his arms
local CARRY_OFFSET = CFrame.new(0, 0.6, -2.2) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0)

local NpcBrain = {}
local rng = Random.new()
local root: Part
local rayParams = RaycastParams.new()

local npc = {
	state = "idle",
	emote = "",
	pos = Vector3.zero, -- floor position
	facing = Vector3.new(-1, 0, 0),
	path = nil :: { Vector3 }?,
	pathIndex = 1,
	request = 0, -- increases with every path request; stale results are dropped
	destination = nil :: Vector3?,
	visionRange = P.VisionRange,
	shownRange = -1,
	seen = nil :: any, -- player session currently inside the vision cone
	nextSense = 0,
	target = nil :: any,
	lastSeenAt = 0,
	lastKnown = Vector3.zero,
	nextRepath = 0,
	stateUntil = 0,
	patrolIndex = 1,
	scanning = false,
	scanStart = 0,
	scanUntil = 0,
	scanBase = 0,
	carried = nil :: any,
	weld = nil :: Weld?,
	carryDeadline = 0,
	sleepDuration = 0,
	sleepUntil = 0,
	nextSnoreCheck = 0,
	onAsleep = nil :: (() -> ())?,
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function setEmote(emote: string)
	if npc.emote ~= emote then
		npc.emote = emote
		root:SetAttribute("Emote", emote)
	end
end

local function setState(state: string, emote: string?)
	npc.state = state
	root:SetAttribute("State", state)
	setEmote(emote or "")
end

local function playerRoot(s): BasePart?
	local character = s.player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- ---------------------------------------------------------------- movement
local function cancelPath()
	npc.request += 1
	npc.path = nil
	npc.destination = nil
end

-- Requests a path; the old one stays in use until the new one is ready.
local function goTo(destination: Vector3)
	npc.request += 1
	npc.destination = destination
	local request = npc.request
	task.spawn(function()
		local points = Navigation.compute(npc.pos, destination)
		if request ~= npc.request then
			return
		end
		-- skip points we are already standing on, so he never steps backwards
		local index = 1
		while index < #points and (points[index] - npc.pos).Magnitude < 2 do
			index += 1
		end
		npc.path = points
		npc.pathIndex = index
	end)
end

local function face(direction: Vector3, dt: number)
	if direction.Magnitude < 0.01 then
		return
	end
	local current = math.atan2(npc.facing.Z, npc.facing.X)
	local target = math.atan2(direction.Z, direction.X)
	local difference = (target - current + math.pi) % (2 * math.pi) - math.pi
	local angle = current + math.clamp(difference, -TURN_RATE * dt, TURN_RATE * dt)
	npc.facing = Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- Walks along the current path. Returns true once the end is reached.
local function follow(dt: number, speed: number): boolean
	local path = npc.path
	if not path then
		return false
	end
	local budget = speed * dt
	while budget > 0 and npc.pathIndex <= #path do
		local delta = flat(path[npc.pathIndex] - npc.pos)
		local distance = delta.Magnitude
		if distance <= budget then
			npc.pos = flat(path[npc.pathIndex])
			budget -= distance
			npc.pathIndex += 1
		else
			local direction = delta / distance
			npc.pos += direction * budget
			face(direction, dt)
			budget = 0
		end
	end
	return npc.pathIndex > #path
end

local function startScan(now: number, seconds: number)
	npc.scanning = true
	npc.scanStart = now
	npc.scanUntil = now + seconds
	npc.scanBase = math.atan2(npc.facing.Z, npc.facing.X)
end

-- Looks left and right. Returns true while still scanning.
local function scan(now: number): boolean
	if now < npc.scanUntil then
		local angle = npc.scanBase + math.sin((now - npc.scanStart) * 2.2) * 1.1
		npc.facing = Vector3.new(math.cos(angle), 0, math.sin(angle))
		return true
	end
	return false
end

-- ---------------------------------------------------------------- senses
-- Server-side vision: range, 70° cone, then a raycast that walls and furniture block.
local function canSee(s, range: number, ignoreCone: boolean): boolean
	local part = playerRoot(s)
	if not part then
		return false
	end
	local eye = npc.pos + Vector3.new(0, EYE_HEIGHT, 0)
	local offset = part.Position - eye
	if offset.Magnitude > range then
		return false
	end
	local flatOffset = flat(offset)
	if not ignoreCone and flatOffset.Magnitude > P.TouchRange and flatOffset.Unit:Dot(npc.facing) < COS_HALF_CONE then
		return false
	end
	local hit = workspace:Raycast(eye, offset, rayParams)
	return hit == nil or hit.Instance:IsDescendantOf(part.Parent :: Instance)
end

local function sense(now: number)
	if now < npc.nextSense then
		return
	end
	npc.nextSense = now + 0.1
	local best, bestDistance = nil, math.huge
	for _, s in Session.players do
		if s.status == "playing" and canSee(s, npc.visionRange, false) then
			local part = playerRoot(s)
			local distance = part and (flat(part.Position) - npc.pos).Magnitude or math.huge
			if distance < bestDistance then
				best, bestDistance = s, distance
			end
		end
	end
	npc.seen = best
end

-- ---------------------------------------------------------------- state changes
local function endChase()
	local target = npc.target
	if target then
		target.chased = false
		if Session.players[target.player] then
			Session.sync(target)
		end
	end
	npc.target = nil
end

local function resumePatrol()
	endChase()
	-- continue from the closest waypoint of the route
	local best, bestDistance = 1, math.huge
	for index, name in Config.PatrolRoute do
		local node = World.nodes[name]
		if node and (node - npc.pos).Magnitude < bestDistance then
			best, bestDistance = index, (node - npc.pos).Magnitude
		end
	end
	npc.patrolIndex = best
	npc.scanning = false
	npc.scanUntil = 0
	setState("patrol")
	goTo(World.nodes[Config.PatrolRoute[best]])
end

local function investigate(position: Vector3)
	endChase()
	npc.scanning = false
	npc.scanUntil = 0
	setState("investigate", Text.EmoteSearch)
	goTo(flat(position))
end

local function startAlert(s, now: number)
	local part = playerRoot(s)
	npc.target = s
	npc.lastSeenAt = now
	npc.lastKnown = part and flat(part.Position) or npc.pos
	npc.stateUntil = now + P.ReactionTime
	cancelPath()
	setState("alert", Text.EmoteAlert)
	s.chased = true
	Session.sync(s)
	Remotes.Effect:FireClient(s.player, "spotted")
end

local function catch(s, now: number)
	if s.status == "hidden" then
		HideService.release(s, false)
	end
	s.status = "caught"
	s.chased = false
	s.crouched = false
	s.pickup = nil
	if #s.carried > 0 then
		local lost = table.remove(s.carried, rng:NextInteger(1, #s.carried)) :: string
		PlayerData.notify(s.player, string.format(Text.LostSnack, Config.Snacks[lost].name), "bad")
	end
	Session.sync(s)
	PlayerData.notify(s.player, Text.Caught, "bad")
	Remotes.Effect:FireClient(s.player, "caught")

	-- weld the kid to the (anchored) root: the character now moves with Родитель
	local part = playerRoot(s)
	local character = s.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if part then
		if humanoid then
			humanoid.PlatformStand = true
		end
		part.Anchored = false
		local weld = Instance.new("Weld")
		weld.Name = "CarryWeld"
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = CARRY_OFFSET
		weld.Parent = root
		npc.weld = weld
	end
	npc.carried = s
	npc.target = nil
	npc.stateUntil = now + 1.4
	cancelPath()
	setState("grab", Text.EmoteCatch)
end

local function finishCarry(now: number)
	local s = npc.carried
	npc.carried = nil
	if npc.weld then
		npc.weld:Destroy()
		npc.weld = nil
	end
	if s and Session.players[s.player] and s.status == "caught" then
		local character = s.player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
		if character then
			World.layInBed(character, s.bed)
		end
		s.status = "stunned"
		s.stunnedUntil = now + Config.Player.StunTime
		s.stunnedUntilServer = workspace:GetServerTimeNow() + Config.Player.StunTime
		Session.sync(s)
		Remotes.Effect:FireClient(s.player, "stunned")
	end
end

-- ---------------------------------------------------------------- per-state updates
local function updatePatrol(dt: number, now: number)
	if npc.seen then
		startAlert(npc.seen, now)
		return
	end
	if npc.scanning then
		if scan(now) then
			return
		end
		npc.scanning = false
		npc.patrolIndex = npc.patrolIndex % #Config.PatrolRoute + 1
		goTo(World.nodes[Config.PatrolRoute[npc.patrolIndex]])
		return
	end
	if follow(dt, P.PatrolSpeed) then
		startScan(now, rng:NextNumber(1.5, 3))
	end
end

local function updateInvestigate(dt: number, now: number)
	if npc.seen then
		startAlert(npc.seen, now)
		return
	end
	if npc.scanning then
		if not scan(now) then
			resumePatrol()
		end
		return
	end
	if follow(dt, P.InvestigateSpeed) then
		startScan(now, 3)
	end
end

local function updateAlert(dt: number, now: number)
	local target = npc.target
	local part = target and playerRoot(target)
	if part then
		face(flat(part.Position) - npc.pos, dt)
	end
	if now >= npc.stateUntil then
		if target and Session.players[target.player] and (target.status == "playing" or target.status == "hidden") then
			npc.nextRepath = 0
			setState("chase", Text.EmoteAlert)
		else
			resumePatrol()
		end
	end
end

local function updateChase(dt: number, now: number)
	local target = npc.target
	if not target or not Session.players[target.player] or (target.status ~= "playing" and target.status ~= "hidden") then
		resumePatrol()
		return
	end
	local part = playerRoot(target)
	if not part then
		resumePatrol()
		return
	end

	local goal = npc.lastKnown
	local visible = false
	if target.status == "hidden" then
		if target.spotSeen and target.spot then
			-- he watched you climb in: walks up and pulls you out
			goal = flat(target.spot.exit)
			npc.lastSeenAt = now
			if (goal - npc.pos).Magnitude <= P.CatchDistance + 1.5 then
				catch(target, now)
				return
			end
		end
	else
		visible = canSee(target, P.ChaseVisionRange, true)
		if visible then
			npc.lastSeenAt = now
			npc.lastKnown = flat(part.Position)
			goal = npc.lastKnown
		end
		local reach = (flat(part.Position) - npc.pos).Magnitude
		-- catch validation: close enough, on the same floor level, and actually in sight
		if reach <= P.CatchDistance and math.abs(part.Position.Y - ROOT_HEIGHT) < 7 and now - npc.lastSeenAt < 1 then
			catch(target, now)
			return
		end
	end

	if now - npc.lastSeenAt > P.LoseSightTime then
		resumePatrol()
		return
	end
	if now >= npc.nextRepath then
		npc.nextRepath = now + 0.35
		goTo(goal)
	end
	local direct = goal - npc.pos
	if visible and direct.Magnitude < 9 and direct.Magnitude > 0.05 then
		-- nothing between them: run straight at the player
		local direction = direct.Unit
		npc.pos += direction * math.min(direct.Magnitude, P.ChaseSpeed * dt)
		face(direction, dt)
	else
		follow(dt, P.ChaseSpeed)
	end
end

local function updateCarry(dt: number, now: number)
	local s = npc.carried
	local valid = s and Session.players[s.player] and s.status == "caught"
	if npc.state == "grab" then
		if not valid then
			finishCarry(now)
			resumePatrol()
		elseif now >= npc.stateUntil then
			npc.carryDeadline = now + 20
			setState("carry", Text.EmoteCatch)
			goTo(flat(World.beds[s.bed].standPosition))
		end
		return
	end
	if not valid or follow(dt, P.CarrySpeed) or now >= npc.carryDeadline then
		finishCarry(now)
		resumePatrol()
	end
end

local function updateSleep(dt: number, now: number)
	if npc.state == "gotoSleep" then
		if npc.seen then
			startAlert(npc.seen, now)
		elseif follow(dt, P.PatrolSpeed) then
			npc.facing = Vector3.new(-1, 0, 0) -- towards the TV
			npc.sleepUntil = now + npc.sleepDuration
			npc.nextSnoreCheck = now + 2
			setState("sleep", Text.EmoteSleep)
			if npc.onAsleep then
				npc.onAsleep()
			end
		end
		return
	end
	if now >= npc.sleepUntil then
		resumePatrol()
		return
	end
	-- snoring: every 2 seconds, somebody running nearby may wake him up
	if now >= npc.nextSnoreCheck then
		npc.nextSnoreCheck = now + 2
		for _, s in Session.players do
			local part = playerRoot(s)
			if part and s.status == "playing" and s.noiseRadius >= Config.Noise.Run
				and (flat(part.Position) - npc.pos).Magnitude <= P.SleepWakeRadius
				and rng:NextNumber() < P.SleepWakeChance then
				investigate(part.Position)
				return
			end
		end
	end
end

local function update(dt: number)
	local now = os.clock()
	local state = npc.state
	if state ~= "idle" then
		if state ~= "sleep" and state ~= "grab" and state ~= "carry" and state ~= "wait" then
			sense(now)
		else
			npc.seen = nil
		end
		if state == "wait" then
			if now >= npc.stateUntil then
				resumePatrol()
			end
		elseif state == "patrol" then
			updatePatrol(dt, now)
		elseif state == "investigate" then
			updateInvestigate(dt, now)
		elseif state == "alert" then
			updateAlert(dt, now)
		elseif state == "chase" then
			updateChase(dt, now)
		elseif state == "grab" or state == "carry" then
			updateCarry(dt, now)
		elseif state == "gotoSleep" or state == "sleep" then
			updateSleep(dt, now)
		end
	end

	local base = npc.pos + Vector3.new(0, ROOT_HEIGHT, 0)
	root.CFrame = CFrame.lookAt(base, base + npc.facing)
	local range = (npc.state == "sleep" or npc.state == "idle") and 0 or npc.visionRange
	if range ~= npc.shownRange then
		npc.shownRange = range
		root:SetAttribute("VisionRange", range)
	end
end

-- ---------------------------------------------------------------- public API
function NpcBrain.start()
	npc.pos = World.sofa
	npc.facing = Vector3.new(-1, 0, 0)
	npc.visionRange = P.VisionRange
	npc.seen = nil
	npc.target = nil
	npc.stateUntil = os.clock() + Config.Round.GraceTime
	cancelPath()
	setState("wait")
end

function NpcBrain.stop()
	if npc.carried then
		local s = npc.carried
		local character = s.player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
	if npc.weld then
		npc.weld:Destroy()
		npc.weld = nil
	end
	npc.carried = nil
	endChase()
	cancelPath()
	npc.pos = World.sofa
	npc.facing = Vector3.new(-1, 0, 0)
	setState("idle")
end

-- Event «Свет мигнул»: nil restores the normal range.
function NpcBrain.setVisionRange(range: number?)
	npc.visionRange = range or P.VisionRange
end

-- Event «Кот пробежал!» and other scripted lures. Returns false if he is busy with a player.
function NpcBrain.lure(position: Vector3): boolean
	if npc.state == "patrol" or npc.state == "investigate" or npc.state == "gotoSleep" or npc.state == "sleep" then
		investigate(position)
		return true
	end
	return false
end

-- Event «Родитель уснул на диване». onAsleep fires when he actually sits down.
function NpcBrain.goSleep(duration: number, onAsleep: () -> ()): boolean
	if npc.state ~= "patrol" and npc.state ~= "investigate" then
		return false
	end
	npc.sleepDuration = duration
	npc.onAsleep = onAsleep
	npc.scanning = false
	setState("gotoSleep")
	goTo(World.sofa)
	return true
end

function NpcBrain.init()
	root = Instance.new("Part")
	root.Name = "ParentRoot"
	root.Size = Vector3.new(2, 6, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root:SetAttribute("State", "idle")
	root:SetAttribute("Emote", "")
	root:SetAttribute("VisionRange", 0)
	npc.pos = World.sofa
	root.CFrame = CFrame.new(npc.pos + Vector3.new(0, ROOT_HEIGHT, 0))
	root.Parent = World.npcFolder

	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { World.npcFolder, World.map:WaitForChild("Items") }

	-- Did he watch this player climb into a hiding spot?
	HideService.watchCheck = function(s): boolean
		local now = os.clock()
		if (npc.state == "chase" or npc.state == "alert") and npc.target == s and now - npc.lastSeenAt < 1 then
			return true
		end
		if (npc.state == "patrol" or npc.state == "investigate" or npc.state == "gotoSleep") and canSee(s, npc.visionRange, false) then
			startAlert(s, now)
			return true
		end
		return false
	end

	-- hearing
	Noise.listen(function(position, radius, kind)
		local state = npc.state
		if (flat(position) - npc.pos).Magnitude > radius then
			return
		end
		if state == "patrol" or state == "investigate" or state == "gotoSleep" then
			-- do not restart the search for every single footstep in the same place
			if state == "investigate" and npc.destination and (npc.destination - flat(position)).Magnitude < 4 then
				return
			end
			investigate(position)
		elseif state == "sleep" and kind ~= "step" then
			investigate(position) -- loud things wake him; footsteps go through the snore check
		end
	end)

	RunService.Heartbeat:Connect(update)
end

return NpcBrain
