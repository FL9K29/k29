"""Generates src/workspace/Map.model.json (the static map) for Rojo.

Run from the roblox/ folder:  python3 tools/gen_map.py
Layout (top of the ground is y = 0): plaza at the centre, gardens to the south (+Z),
forest to the north (-Z), wild fields around.
"""
import json
import os
import random

rnd = random.Random(42)
ROT = [1, 0, 0, 0, 1, 0, 0, 0, 1]  # identity rotation; Rojo reads a CFrame as 12 numbers


def part(name, size, pos, color, material="SmoothPlastic", shape=None, transparency=0, collide=True, cls="Part", **extra):
    props = {
        "Anchored": True,
        "Size": [float(v) for v in size],
        "CFrame": [float(v) for v in pos] + ROT,
        "Color": [c / 255 for c in color],
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
        "CanCollide": collide,
    }
    if transparency:
        props["Transparency"] = transparency
    if shape:
        props["Shape"] = shape
    props.update(extra)
    return {"Name": name, "ClassName": cls, "Properties": props}


def folder(name, children, cls="Folder"):
    return {"Name": name, "ClassName": cls, "Children": children}


def ball(name, d, pos, color, material="SmoothPlastic", collide=False, **extra):
    return part(name, (d, d, d), pos, color, material, shape="Ball", collide=collide, **extra)


WOOD = (150, 104, 62)
SAND = (214, 190, 140)

# ---------------------------------------------------------------- ground
ground = [
    part("Baseplate", (560, 4, 560), (0, -2, 0), (104, 168, 76), "Grass", Locked=True),
    part("ForestFloor", (520, 0.2, 150), (0, 0.1, -190), (66, 118, 60), "Grass", collide=False),
]
walls = []
for name, size, pos in (
    ("WallN", (560, 60, 2), (0, 30, -279)), ("WallS", (560, 60, 2), (0, 30, 279)),
    ("WallW", (2, 60, 560), (-279, 30, 0)), ("WallE", (2, 60, 560), (279, 30, 0)),
):
    walls.append(part(name, size, pos, (255, 255, 255), transparency=1))

paths = [
    part("PathSouth", (10, 0.2, 152), (0, 0.1, 116), SAND, "Sand", collide=False),
    part("PathNorth", (10, 0.2, 70), (0, 0.1, -75), SAND, "Sand", collide=False),
    part("PathWest", (110, 0.2, 10), (-95, 0.1, 0), SAND, "Sand", collide=False),
    part("PathEast", (110, 0.2, 10), (95, 0.1, 0), SAND, "Sand", collide=False),
    part("LaneRow1", (264, 0.2, 8), (0, 0.1, 68), SAND, "Sand", collide=False),
    part("LaneRow2", (264, 0.2, 8), (0, 0.1, 128), SAND, "Sand", collide=False),
]

# ---------------------------------------------------------------- plaza
plaza = [
    part("Floor", (80, 0.4, 80), (0, 0.2, 0), (176, 168, 156), "Cobblestone"),
    part("StatueBase", (18, 3, 18), (0, 1.9, 0), (226, 222, 212), "Marble"),
    part("StatueStep", (22, 1, 22), (0, 0.9, 0), (200, 196, 186), "Marble"),
    ball("StatuePumpkin", 15, (0, 10.4, 0), (240, 130, 30), collide=True),
    part("StatueStem", (2, 3, 2), (0, 18.6, 0), (90, 130, 50)),
    part("StatueLeaf", (5, 0.5, 2.4), (2.6, 19.4, 0), (80, 170, 70)),
    ball("StatueTomato", 6, (-6.5, 6.2, 6), (226, 60, 50), collide=True),
    ball("StatueMelon", 7, (6.5, 6.7, 6.5), (64, 150, 70), collide=True),
    {"Name": "SpawnLocation", "ClassName": "SpawnLocation", "Properties": {
        "Anchored": True, "Size": [10.0, 1.0, 10.0],
        "CFrame": [0.0, 0.9, 30.0] + ROT,
        "Color": [0.95, 0.8, 0.3], "Material": "SmoothPlastic", "TopSurface": "Smooth",
        "BottomSurface": "Smooth", "Neutral": True, "Duration": 0}},
]


def stand(prefix, x, awning):
    out = [
        part(prefix + "Stand", (5, 4, 14), (x, 2.4, 0), WOOD, "WoodPlanks"),
        part(prefix + "Counter", (6, 0.5, 15), (x, 4.65, 0), (196, 150, 96), "Wood"),
        part(prefix + "Roof", (9, 0.6, 17), (x, 11.3, 0), awning, "Fabric"),
        part(prefix + "Sign", (0.6, 2.6, 12), (x, 13.2, 0), (60, 44, 34), "Wood"),
    ]
    for dz in (-7.5, 7.5):
        for dx in (-3.5, 3.5):
            out.append(part(prefix + "Post", (0.6, 11, 0.6), (x + dx, 5.9, dz), WOOD, "Wood"))
    return out


plaza += stand("Sell", -28, (220, 70, 60))
plaza += stand("Shop", 28, (70, 140, 220))
for i, (lx, lz) in enumerate(((-36, -36), (36, -36), (-36, 36), (36, 36))):
    plaza.append(part("LampPost", (0.8, 12, 0.8), (lx, 6.4, lz), (60, 60, 70), "Metal"))
    plaza.append(ball("LampGlow", 2.4, (lx, 13, lz), (255, 226, 150), "Neon"))
for bx, bz in ((-14, 22), (14, 22), (-14, -22), (14, -22)):
    plaza.append(part("Bench", (8, 1, 2.4), (bx, 1.5, bz), WOOD, "WoodPlanks"))
    plaza.append(part("BenchLeg", (0.6, 1, 2), (bx - 3, 0.9, bz), (70, 70, 80), "Metal"))
    plaza.append(part("BenchLeg", (0.6, 1, 2), (bx + 3, 0.9, bz), (70, 70, 80), "Metal"))

# ---------------------------------------------------------------- gardens
PLOT_W, PLOT_D = 50, 34
plots = []
n = 0
for z in (90, 150):
    for x in (-102, -36, 36, 102):
        n += 1
        north = z - PLOT_D / 2
        slots = []
        for i in range(12):
            sx = x - 17.5 + 7 * (i % 6)
            sz = z - 6 + 12 * (i // 6)
            slots.append(part("Slot%d" % (i + 1), (5, 0.6, 5), (sx, 0.7, sz), (106, 72, 48), "Ground"))
        fence = []
        rail = dict(color=WOOD, material="WoodPlanks", transparency=1, collide=False)
        fence.append(part("Rail", (PLOT_W, 3, 0.5), (x, 1.9, z + PLOT_D / 2), **rail))
        fence.append(part("Rail", (0.5, 3, PLOT_D), (x - PLOT_W / 2, 1.9, z), **rail))
        fence.append(part("Rail", (0.5, 3, PLOT_D), (x + PLOT_W / 2, 1.9, z), **rail))
        fence.append(part("Rail", (PLOT_W / 2 - 5, 3, 0.5), (x - PLOT_W / 4 - 2.5, 1.9, north), **rail))
        fence.append(part("Rail", (PLOT_W / 2 - 5, 3, 0.5), (x + PLOT_W / 4 + 2.5, 1.9, north), **rail))
        plots.append(folder("Plot%d" % n, [
            part("Base", (PLOT_W, 0.4, PLOT_D), (x, 0.2, z), (84, 138, 64), "Grass"),
            part("Entrance", (10, 0.2, 5), (x, 0.1, north - 2.5), SAND, "Sand", collide=False),
            part("SignPost", (0.5, 6, 0.5), (x + 7, 3, north - 1), WOOD, "Wood"),
            part("Sign", (7, 2.6, 0.4), (x + 7, 6.6, north - 1), (60, 44, 34), "Wood"),
            folder("Slots", slots),
            folder("Fence", fence),
        ], cls="Model"))

# ---------------------------------------------------------------- forest
forest = []
placed = []
tries = 0
while len(placed) < 75 and tries < 5000:
    tries += 1
    x, z = rnd.uniform(-250, 250), rnd.uniform(-262, -122)
    if abs(x) < 9 and z > -150:
        continue
    if any((x - a) ** 2 + (z - b) ** 2 < 13 ** 2 for a, b in placed):
        continue
    placed.append((x, z))
    h = rnd.uniform(9, 15)
    d = rnd.uniform(10, 15)
    green = rnd.choice(((52, 128, 60), (64, 146, 66), (44, 110, 56), (80, 150, 60)))
    forest.append(part("Trunk", (2.4, h, 2.4), (x, h / 2, z), (110, 76, 48), "Wood"))
    forest.append(ball("Leaves", d, (x, h + d * 0.3, z), green, "Grass"))
    forest.append(ball("Leaves", d * 0.7, (x + rnd.uniform(-2, 2), h + d * 0.75, z + rnd.uniform(-2, 2)), green, "Grass"))
for i in range(34):
    x, z = rnd.uniform(-250, 250), rnd.uniform(-262, -118)
    d = rnd.uniform(4, 7)
    forest.append(ball("Bush", d, (x, d * 0.2, z), (58, 136, 62), "Grass"))
for i in range(14):
    x, z = rnd.uniform(-240, 240), rnd.uniform(-255, -125)
    forest.append(part("MushroomStem", (0.8, 1.4, 0.8), (x, 0.7, z), (240, 232, 214), collide=False))
    forest.append(ball("MushroomCap", 2.2, (x, 1.7, z), (214, 60, 52)))

# ---------------------------------------------------------------- wild fields
fields = []
REGIONS = ((-262, -150, -95, 262), (150, 262, -95, 262), (-140, 140, -104, -52), (-140, 140, 186, 262))


def spot():
    x0, x1, z0, z1 = rnd.choice(REGIONS)
    x, z = rnd.uniform(x0, x1), rnd.uniform(z0, z1)
    if abs(x) < 9 and z < 0:  # keep the north path clear
        x += 20
    return x, z


for i in range(30):
    x, z = spot()
    fields.append(part("Wheat", (rnd.uniform(9, 16), 2.4, rnd.uniform(7, 12)), (x, 1.2, z), (226, 194, 88), "Grass", collide=False))
for i in range(16):
    x, z = spot()
    fields.append(part("HayBale", (4.5, 3.2, 4.5), (x, 1.6, z), (222, 190, 96), "Fabric"))
for i in range(60):
    x, z = spot()
    col = rnd.choice(((255, 110, 140), (255, 220, 90), (190, 130, 255), (255, 255, 255), (255, 150, 70)))
    fields.append(ball("Flower", 0.9, (x, 0.5, z), col))
for i in range(18):
    x, z = spot()
    d = rnd.uniform(3, 6)
    fields.append(ball("Rock", d, (x, d * 0.15, z), (140, 140, 146), "Slate", collide=True))
fields.append(part("Pond", (34, 0.2, 24), (204, 0.12, 60), (70, 150, 220), "Glass", transparency=0.25, collide=False))
for sx, sz in ((-205, 40), (200, 170)):
    fields += [
        part("ScarecrowPost", (0.6, 8, 0.6), (sx, 4, sz), WOOD, "Wood"),
        part("ScarecrowArms", (6, 0.6, 0.6), (sx, 5.6, sz), WOOD, "Wood"),
        part("ScarecrowShirt", (2.4, 3, 1.4), (sx, 5, sz), (200, 70, 60), "Fabric"),
        ball("ScarecrowHead", 2.2, (sx, 8.4, sz), (232, 204, 150), "Fabric"),
        part("ScarecrowHat", (3.2, 0.4, 3.2), (sx, 9.5, sz), (90, 64, 40), "Fabric"),
        part("ScarecrowHatTop", (1.8, 1.2, 1.8), (sx, 10.2, sz), (90, 64, 40), "Fabric"),
    ]

# ---------------------------------------------------------------- zone signs
signs = []
for name, x, z in (("ZoneSignForest", 9, -106), ("ZoneSignGardens", 9, 56), ("ZoneSignFieldsW", -146, 9), ("ZoneSignFieldsE", 146, 9)):
    signs.append(part("ZonePost", (0.6, 7, 0.6), (x, 3.5, z), WOOD, "Wood"))
    signs.append(part(name, (8, 2.8, 0.5), (x, 7.6, z), (60, 44, 34), "Wood"))

model = folder("Map", [
    folder("Ground", ground), folder("Walls", walls), folder("Paths", paths), folder("Plaza", plaza),
    folder("Plots", plots), folder("Forest", forest), folder("Fields", fields), folder("Signs", signs),
])
del model["Name"]  # Rojo takes the name from the file name

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "workspace", "Map.model.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as f:
    json.dump(model, f, separators=(",", ":"))


def count(node):
    return 1 + sum(count(c) for c in node.get("Children", []))


print("instances:", count(model))
