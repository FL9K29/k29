--[[
	Navigation — routes for Родитель.
	First choice is PathfindingService (navmesh). If it fails or finds no path, the hand-made
	waypoint graph (Config.Graph over Workspace.Map.Waypoints) is used instead.
]]

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)

local Navigation = {}

local AGENT = { AgentRadius = 2, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 6 }

local neighbours = nil :: { [string]: { string } }?
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include

local function buildGraph()
	local graph = {}
	for name in World.nodes do
		graph[name] = {}
	end
	for _, edge in Config.Graph do
		local a, b = edge[1], edge[2]
		if graph[a] and graph[b] then
			table.insert(graph[a], b)
			table.insert(graph[b], a)
		end
	end
	wallParams.FilterDescendantsInstances = { World.map:WaitForChild("Apartment"):WaitForChild("Walls") }
	return graph
end

local function wallBetween(a: Vector3, b: Vector3): boolean
	local from = Vector3.new(a.X, 3, a.Z)
	local to = Vector3.new(b.X, 3, b.Z)
	return workspace:Raycast(from, to - from, wallParams) ~= nil
end

-- Closest waypoint that is not behind a wall (or simply the closest one).
local function nearestNode(position: Vector3): string?
	local best, bestDistance = nil, math.huge
	local fallback, fallbackDistance = nil, math.huge
	for name, nodePosition in World.nodes do
		local distance = (nodePosition - position).Magnitude
		if distance < fallbackDistance then
			fallback, fallbackDistance = name, distance
		end
		if distance < bestDistance and not wallBetween(position, nodePosition) then
			best, bestDistance = name, distance
		end
	end
	return best or fallback
end

-- Dijkstra over the waypoint graph.
function Navigation.graphPath(from: Vector3, to: Vector3): { Vector3 }
	if not neighbours then
		neighbours = buildGraph()
	end
	local graph = neighbours :: { [string]: { string } }
	local start, goal = nearestNode(from), nearestNode(to)
	local points = {}
	if start and goal then
		local distances = { [start] = 0 }
		local previous = {}
		local open = { [start] = true }
		while next(open) do
			local current, currentDistance = nil, math.huge
			for name in open do
				if distances[name] < currentDistance then
					current, currentDistance = name, distances[name]
				end
			end
			if not current or current == goal then
				break
			end
			open[current] = nil
			for _, neighbour in graph[current] do
				local distance = currentDistance + (World.nodes[neighbour] - World.nodes[current]).Magnitude
				if distance < (distances[neighbour] or math.huge) then
					distances[neighbour] = distance
					previous[neighbour] = current
					open[neighbour] = true
				end
			end
		end
		local chain = {}
		local cursor = goal
		while cursor do
			table.insert(chain, 1, World.nodes[cursor])
			cursor = previous[cursor]
		end
		if previous[goal] or goal == start then
			points = chain
		end
	end
	table.insert(points, Vector3.new(to.X, 0, to.Z))
	return points
end

-- Returns a list of floor points from `from` to `to`. May yield.
function Navigation.compute(from: Vector3, to: Vector3): ({ Vector3 }, string)
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(function()
		path:ComputeAsync(Vector3.new(from.X, 1, from.Z), Vector3.new(to.X, 1, to.Z))
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local points = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, Vector3.new(waypoint.Position.X, 0, waypoint.Position.Z))
		end
		if #points > 0 then
			return points, "navmesh"
		end
	end
	return Navigation.graphPath(from, to), "graph"
end

return Navigation
