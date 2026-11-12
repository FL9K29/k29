"""Generates src/workspace/Map.model.json — the apartment and the lobby — for Rojo.

Run from the tihiy-chas/ folder:  python3 tools/gen_map.py

Axes: X = east, Z = south, floor top at y = 0. Rooms:
  Bedroom  x -50..-14  z -40..-8      Bathroom x -14..6   z -40..-8     Kitchen x 6..50 z -40..-8
  Corridor x -50..50   z -8..8
  Living   x -50..14   z 8..40        Hall     x 14..50   z 8..40
The lobby («подъезд») is a separate room around z = 140.
"""
import json
import os

ROT = [1, 0, 0, 0, 1, 0, 0, 0, 1]  # identity rotation; Rojo reads a CFrame as 12 numbers
WALL_H = 12
DOOR_W = 7
DOOR_H = 8

WALL = (198, 184, 160)
WOOD = (150, 104, 62)
DARK_WOOD = (96, 66, 44)
WHITE = (236, 236, 240)
WARM = (255, 214, 150)
MOON = (150, 180, 255)


def part(name, size, pos, color, material="SmoothPlastic", shape=None, transparency=0, collide=True, children=None, **extra):
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
    node = {"Name": name, "ClassName": "Part", "Properties": props}
    if children:
        node["Children"] = children
    return node


def light(color, rng, brightness, shadows=True):
    return {"Name": "Light", "ClassName": "PointLight", "Properties": {
        "Color": [c / 255 for c in color], "Range": float(rng), "Brightness": float(brightness), "Shadows": shadows}}


def folder(name, children, cls="Folder"):
    return {"Name": name, "ClassName": cls, "Children": children}


def marker(name, pos):
    """Invisible, non-colliding point used by scripts."""
    return part(name, (1, 1, 1), pos, (255, 0, 255), transparency=1, collide=False, CanQuery=False, CanTouch=False)


def wall_x(z, x0, x1, doors=(), name="Wall"):
    """Wall along X at the given z, with door openings centred at the given x values."""
    out, cur = [], x0
    for d in sorted(doors):
        a, b = d - DOOR_W / 2, d + DOOR_W / 2
        if a > cur:
            out.append(part(name, (a - cur, WALL_H, 1), ((a + cur) / 2, WALL_H / 2, z), WALL))
        out.append(part("Lintel", (DOOR_W, WALL_H - DOOR_H, 1), (d, (WALL_H + DOOR_H) / 2, z), WALL))
        cur = b
    if x1 > cur:
        out.append(part(name, (x1 - cur, WALL_H, 1), ((x1 + cur) / 2, WALL_H / 2, z), WALL))
    return out


def wall_z(x, z0, z1, doors=(), name="Wall"):
    out, cur = [], z0
    for d in sorted(doors):
        a, b = d - DOOR_W / 2, d + DOOR_W / 2
        if a > cur:
            out.append(part(name, (1, WALL_H, a - cur), (x, WALL_H / 2, (a + cur) / 2), WALL))
        out.append(part("Lintel", (1, WALL_H - DOOR_H, DOOR_W), (x, (WALL_H + DOOR_H) / 2, d), WALL))
        cur = b
    if z1 > cur:
        out.append(part(name, (1, WALL_H, z1 - cur), (x, WALL_H / 2, (z1 + cur) / 2), WALL))
    return out


def overlay(name, x0, x1, z0, z1, color, material, y=0.05):
    """Thin decorative floor layer (players walk on the base floor underneath)."""
    return part(name, (x1 - x0, 0.1, z1 - z0), ((x0 + x1) / 2, y, (z0 + z1) / 2), color, material, collide=False)


# ---------------------------------------------------------------- shell
ground = [
    part("Ground", (600, 1, 600), (0, -0.7, 60), (20, 22, 30), "Slate", Locked=True),
    part("FloorBase", (101, 1, 81), (0, -0.5, 0), (120, 90, 60), "WoodPlanks"),
]
floors = [
    overlay("BedroomFloor", -49.5, -14.5, -39.5, -8.5, (176, 140, 100), "WoodPlanks"),
    overlay("BathFloor", -13.5, 5.5, -39.5, -8.5, (200, 214, 222), "Marble"),
    overlay("KitchenFloor", 6.5, 49.5, -39.5, -8.5, (188, 176, 156), "Slate"),
    overlay("CorridorFloor", -49.5, 49.5, -7.5, 7.5, (150, 112, 76), "WoodPlanks"),
    overlay("LivingFloor", -49.5, 13.5, 8.5, 39.5, (160, 122, 84), "WoodPlanks"),
    overlay("HallFloor", 14.5, 49.5, 8.5, 39.5, (142, 108, 78), "WoodPlanks"),
    overlay("BedroomRug", -39, -25, -24.5, -15.5, (110, 140, 200), "Fabric", 0.1),
    overlay("CorridorRug", -15, 15, -3, 3, (150, 60, 60), "Fabric", 0.1),
    overlay("LivingRug", -45, -36, 17, 31, (120, 90, 140), "Fabric", 0.1),
    overlay("BathMat", -8, 0, -32, -28, (120, 190, 200), "Fabric", 0.1),
]
# slightly darker floorboards that creak
creaks = [
    overlay("Creak", -25.5, -18.5, -4.5, 4.5, (104, 76, 50), "WoodPlanks", 0.12),
    overlay("Creak", 5.5, 14.5, -4.5, 2.5, (104, 76, 50), "WoodPlanks", 0.12),
    overlay("Creak", 36.5, 43.5, -3, 5, (104, 76, 50), "WoodPlanks", 0.12),
    overlay("Creak", 24.5, 31.5, -14.5, -9.5, (130, 120, 104), "Slate", 0.12),
    overlay("Creak", -21.5, -14.5, 10, 16, (112, 84, 56), "WoodPlanks", 0.12),
    overlay("Creak", 28.5, 35.5, 11.5, 16.5, (100, 74, 52), "WoodPlanks", 0.12),
]

walls = []
walls += wall_x(-40, -50.5, 50.5)
walls += wall_x(40, -50.5, 50.5)
walls += wall_z(-50, -39.5, 39.5)
walls += wall_z(50, -39.5, 39.5)
walls += wall_z(-14, -39.5, -8.5)
walls += wall_z(6, -39.5, -8.5)
walls += wall_x(-8, -49.5, 49.5, doors=(-32, -4, 28))
walls += wall_x(8, -49.5, 49.5, doors=(-18, 32))
walls += wall_z(14, 8.5, 39.5, doors=(26,))

windows = [
    part("Window", (10, 4, 0.3), (-33, 8.5, -39.35), (120, 150, 220), "Neon", collide=False, children=[light(MOON, 22, 0.9)]),
    part("Window", (0.3, 4, 8), (49.35, 8.5, -28), (120, 150, 220), "Neon", collide=False, children=[light(MOON, 22, 0.9)]),
    part("Window", (12, 4, 0.3), (-22, 8.5, 39.35), (120, 150, 220), "Neon", collide=False, children=[light(MOON, 24, 0.9)]),
    part("Window", (5, 3, 0.3), (-4, 9, -39.35), (120, 150, 220), "Neon", collide=False, children=[light(MOON, 14, 0.7)]),
]


def lamp(pos, rng=18, brightness=1.1):
    return part("Lamp", (1.2, 1.2, 1.2), pos, WARM, "Neon", shape="Ball", collide=False, children=[light(WARM, rng, brightness)])


lights = [
    lamp((-24.75, 3.9, -38.4), 14, 0.9),  # bedroom nightlight
    lamp((-13.1, 8, -22), 16),  # bathroom mirror
    lamp((20, 8, -39), 22, 1.2),  # kitchen hood
    lamp((0, 8.5, -7.2), 20),  # corridor
    lamp((-40, 8.5, 7.2), 16, 0.9),
    lamp((40, 8.5, -7.2), 16, 0.9),
    lamp((10, 7.4, 12), 20),  # living floor lamp
    lamp((49.1, 8.5, 18), 18),  # hall
]

# ---------------------------------------------------------------- furniture
furniture = []
beds = []
hide_spots = []
BLANKETS = ((90, 130, 220), (220, 110, 130), (110, 190, 120), (230, 190, 80))


def bed_parts(x, z, blanket):
    """Bed with its length along Z, head to the north; 3 studs of clearance underneath."""
    out = []
    for dx in (-2.2, 2.2):
        for dz in (-4.2, 4.2):
            out.append(part("Leg", (0.6, 3, 0.6), (x + dx, 1.5, z + dz), DARK_WOOD, "Wood"))
    out.append(part("Frame", (5, 0.6, 9), (x, 3.3, z), DARK_WOOD, "Wood"))
    out.append(part("Mattress", (4.6, 1, 8.6), (x, 4.1, z), WHITE, "Fabric"))
    out.append(part("Pillow", (3, 0.6, 2), (x, 4.9, z - 3), (250, 250, 255), "Fabric", collide=False))
    out.append(part("Blanket", (4.7, 0.3, 5), (x, 4.75, z + 1.6), blanket, "Fabric", collide=False))
    out.append(part("Headboard", (5, 3.4, 0.5), (x, 4.7, z - 4.6), DARK_WOOD, "Wood"))
    return out


def hide_spot(name, prompt_part, inside, exit_pos):
    return folder(name, [prompt_part, marker("Inside", inside), marker("Exit", exit_pos)], cls="Model")


BED_X = (-46, -37.5, -29, -20.5)
BED_Z = -34.5
for i, bx in enumerate(BED_X):
    beds.append(folder("Bed%d" % (i + 1), bed_parts(bx, BED_Z, BLANKETS[i]) + [marker("Stand", (bx, 3, -27))], cls="Model"))
# two of the kids' beds can be hidden under
for n, bx in ((1, BED_X[1]), (2, BED_X[3])):
    hide_spots.append(hide_spot("UnderBed%d" % n,
                                part("Prompt", (4, 0.4, 1), (bx, 2.6, -30.2), (40, 40, 60), "Fabric", collide=False),
                                (bx, 1.3, BED_Z + 0.5), (bx, 3, -27)))

furniture += [
    part("ToyBox", (4, 3, 4), (-47, 1.5, -12), (220, 90, 80), "WoodPlanks"),
    part("Nightstand", (2.4, 3, 2.4), (-24.75, 1.5, -38.2), DARK_WOOD, "Wood"),
    part("Bookshelf", (2, 8, 8), (-48.5, 4, -22), DARK_WOOD, "Wood"),
    part("Books", (1.6, 1.4, 7), (-48.3, 5.2, -22), (80, 120, 180), collide=False),
]

# bathroom
furniture += [
    part("Bathtub", (12, 2.5, 5), (-4, 1.25, -37), WHITE, "Marble"),
    part("TubRim", (12, 0.6, 0.6), (-4, 2.8, -34.8), WHITE, "Marble"),
    part("Sink", (2.4, 3.6, 4), (-12.3, 1.8, -22), WHITE, "Marble"),
    part("Mirror", (0.2, 3, 3.4), (-13.4, 6.4, -22), (170, 200, 220), "Glass", collide=False),
    part("Toilet", (2.6, 3, 3), (4.2, 1.5, -24), WHITE, "Marble"),
]
tap = part("Tap", (0.8, 0.8, 0.8), (-12.6, 4, -22), (190, 196, 204), "Metal", collide=False)
hide_spots.append(hide_spot("Bath",
                            part("Prompt", (12, 7.5, 0.3), (-4, 6.4, -34.6), (120, 190, 210), "Fabric", collide=False, transparency=0.15),
                            (-4, 5.6, -37.2), (-4, 3, -30)))

# kitchen
furniture += [
    part("Counter", (24, 3.5, 3), (20, 1.75, -38), (220, 214, 200), "Marble"),
    part("CounterTop", (24.4, 0.3, 3.3), (20, 3.65, -38), (90, 80, 76), "Slate"),
    part("Stove", (4, 0.2, 2.4), (21, 3.9, -38), (40, 40, 44), "Metal", collide=False),
    part("Cabinet", (2, 8, 10), (48.5, 4, -17), (220, 214, 200), "WoodPlanks"),
    part("TableTop", (9, 0.5, 5), (26, 3.25, -20), WOOD, "WoodPlanks"),
    part("Plate", (2.2, 0.2, 2.2), (26, 3.6, -20), WHITE, collide=False),
]
for dx in (-4, 4):
    for dz in (-2, 2):
        furniture.append(part("TableLeg", (0.5, 3, 0.5), (26 + dx, 1.5, -20 + dz), DARK_WOOD, "Wood"))
for sx, sz in ((26, -25), (26, -15), (19.5, -20), (32.5, -20)):
    furniture.append(part("Stool", (2, 2, 2), (sx, 1, sz), WOOD, "Wood"))
sources = [
    part("Source_yogurt", (5, 10, 4), (46.5, 5, -37.5), (226, 232, 238), "Metal"),  # the fridge
    part("Source_icecream", (6, 3.5, 3.5), (38.5, 1.75, -37.7), (200, 220, 240), "Metal"),  # freezer chest
    part("Source_juice", (1, 1.8, 1), (11, 4.7, -37.6), (255, 170, 60), collide=False),
    part("Source_cookie", (1.6, 1.8, 1.6), (29.5, 4.7, -37.6), (190, 130, 80), collide=False),
    part("Source_sandwich", (1.6, 0.7, 1.6), (26, 4.05, -20), (230, 190, 120), collide=False),
]
furniture.append(part("FridgeHandle", (0.3, 5, 0.3), (44.6, 5.5, -35.4), (120, 124, 130), "Metal", collide=False))

# corridor
furniture += [
    part("Console", (6, 3, 2), (-44, 1.5, 6.4), DARK_WOOD, "Wood"),
    part("Vase", (1, 1.6, 1), (-44, 3.8, 6.4), (90, 150, 200), collide=False),
]

# living room
furniture += [
    part("TvStand", (3, 3, 10), (-47.5, 1.5, 24), DARK_WOOD, "Wood"),
    part("SofaBase", (4, 2.5, 12), (-33, 1.25, 24), (90, 110, 150), "Fabric"),
    part("SofaBack", (1.2, 5, 12), (-30.9, 2.5, 24), (80, 100, 140), "Fabric"),
    part("SofaArm", (4, 3.6, 1), (-33, 1.8, 17.5), (80, 100, 140), "Fabric"),
    part("SofaArm", (4, 3.6, 1), (-33, 1.8, 30.5), (80, 100, 140), "Fabric"),
    part("CoffeeTable", (3, 2, 6), (-42, 1, 24), WOOD, "WoodPlanks"),
    part("LivingShelf", (10, 8, 2), (-32, 4, 9.6), DARK_WOOD, "Wood"),
    part("LampPole", (0.4, 7, 0.4), (10, 3.5, 12), (60, 60, 66), "Metal"),
    part("Armchair", (4, 2.6, 4), (-8, 1.3, 14), (150, 90, 80), "Fabric"),
    part("Plant", (2, 3, 2), (-47.5, 1.5, 37.5), (150, 104, 62), "Wood"),
    part("PlantLeaves", (4, 4, 4), (-47.5, 5, 37.5), (60, 140, 70), "Grass", shape="Ball", collide=False),
]
tv = part("TV", (0.5, 5, 8), (-46.4, 5.6, 24), (16, 16, 20), "SmoothPlastic", collide=False,
          children=[light((120, 170, 255), 18, 0)])


def wardrobe(name, x, z, along_x):
    """Hollow wardrobe the player stands inside. along_x: doors face -Z (True) or -X (False)."""
    c = (112, 78, 52)
    if along_x:  # 8 wide in X, 4 deep in Z, back against the south wall
        shell = [
            part("Back", (8, 10, 0.5), (x, 5, z + 1.75), c, "Wood"),
            part("Side", (0.5, 10, 4), (x - 3.75, 5, z), c, "Wood"),
            part("Side", (0.5, 10, 4), (x + 3.75, 5, z), c, "Wood"),
            part("Top", (8, 0.5, 4), (x, 9.75, z), c, "Wood"),
            part("Door", (3.45, 9.4, 0.4), (x + 1.78, 4.8, z - 1.8), (126, 90, 60), "WoodPlanks"),
        ]
        prompt = part("Prompt", (3.45, 9.4, 0.4), (x - 1.78, 4.8, z - 1.8), (126, 90, 60), "WoodPlanks")
        exit_pos = (x, 3, z - 6)
    else:  # 4 deep in X, 8 wide in Z, back against the east wall
        shell = [
            part("Back", (0.5, 10, 8), (x + 1.75, 5, z), c, "Wood"),
            part("Side", (4, 10, 0.5), (x, 5, z - 3.75), c, "Wood"),
            part("Side", (4, 10, 0.5), (x, 5, z + 3.75), c, "Wood"),
            part("Top", (4, 0.5, 8), (x, 9.75, z), c, "Wood"),
            part("Door", (0.4, 9.4, 3.45), (x - 1.8, 4.8, z + 1.78), (126, 90, 60), "WoodPlanks"),
        ]
        prompt = part("Prompt", (0.4, 9.4, 3.45), (x - 1.8, 4.8, z - 1.78), (126, 90, 60), "WoodPlanks")
        exit_pos = (x - 6, 3, z)
    spot = hide_spot(name, prompt, (x, 3.1, z), exit_pos)
    spot["Children"] += shell
    return spot


hide_spots.append(wardrobe("Wardrobe1", 0, 37.4, True))
hide_spots.append(wardrobe("Wardrobe2", 47.4, 28, False))

# hall: cot along the dividing wall (third «под кроватью»), shoes, front door
cot = bed_parts(18.5, 34, (150, 150, 170))
furniture += cot
hide_spots.append(hide_spot("UnderBed3",
                            part("Prompt", (1, 0.4, 4), (21.3, 2.6, 34), (40, 40, 60), "Fabric", collide=False),
                            (18.5, 1.3, 34.5), (25, 3, 34)))
furniture += [
    part("ShoeRack", (6, 2, 1.6), (20, 1, 9.6), DARK_WOOD, "Wood"),
    part("FrontDoor", (6, 10, 0.4), (36, 5, 39.3), (70, 50, 40), "Wood", collide=False),
    part("CoatRack", (0.5, 8, 0.5), (48.6, 4, 12), DARK_WOOD, "Wood"),
    part("Coat", (1.4, 4, 2), (48.3, 5.6, 12), (60, 80, 110), "Fabric", collide=False),
]

# throwable items (kept anchored at home until someone picks them up)
items = [
    part("Item_slipper1", (1, 0.6, 2), (19, 0.3, 12), (220, 120, 140), "Fabric"),
    part("Item_slipper2", (1, 0.6, 2), (22.5, 0.3, 12.5), (220, 120, 140), "Fabric"),
    part("Item_ball1", (1.6, 1.6, 1.6), (-42, 0.8, -13), (240, 90, 70), shape="Ball"),
    part("Item_ball2", (1.6, 1.6, 1.6), (-10, 0.8, 21), (90, 170, 240), shape="Ball"),
]

# ---------------------------------------------------------------- waypoints for Родитель
NODES = {
    "Bedroom": (-32, -20), "BedroomIn": (-32, -12), "BedroomDoor": (-32, -4),
    "Bath": (-4, -24), "BathDoor": (-4, -4),
    "KitchenDoor": (28, -4), "KitchenIn": (28, -12), "Kitchen": (14, -24), "KitchenFridge": (40, -30),
    "CorridorW": (-42, 0), "CorridorC": (0, 0), "CorridorE": (44, 0),
    "LivingDoor": (-18, 4), "LivingIn": (-18, 13), "Living": (-14, 26), "LivingE": (6, 24),
    "SofaSide": (-38, 14), "Sofa": (-37.75, 24),
    "HallDoor": (32, 4), "HallIn": (32, 13), "Hall": (32, 24), "LivingHall": (14, 26),
}
waypoints = [marker(name, (x, 1, z)) for name, (x, z) in NODES.items()]

# ---------------------------------------------------------------- lobby («подъезд»)
LZ = 140
lobby = [
    part("LobbyFloor", (47, 1, 33), (0, -0.5, LZ), (130, 134, 140), "Slate"),
    overlay("LobbyMat", -6, 6, LZ - 2, LZ + 10, (120, 60, 60), "Fabric", 0.08),
]
for wall_part in wall_x(LZ - 16, -23.5, 23.5) + wall_x(LZ + 16, -23.5, 23.5) + wall_z(-23, LZ - 15.5, LZ + 15.5) + wall_z(23, LZ - 15.5, LZ + 15.5):
    wall_part["Properties"]["Color"] = [c / 255 for c in (150, 170, 160)]
    lobby.append(wall_part)
lobby += [
    part("ElevatorFrame", (10, 10, 0.6), (0, 5, LZ - 15.3), (90, 94, 100), "Metal", collide=False),
    part("ElevatorDoor", (4.3, 9, 0.4), (-2.3, 4.5, LZ - 15), (170, 176, 186), "Metal", collide=False),
    part("ElevatorDoor", (4.3, 9, 0.4), (2.3, 4.5, LZ - 15), (170, 176, 186), "Metal", collide=False),
    part("LobbySign", (10, 2.4, 0.4), (0, 11.4, LZ - 15.2), (40, 44, 60), "Wood", collide=False),
    part("Bench", (10, 1, 3), (-16, 2, LZ + 8), WOOD, "WoodPlanks"),
    part("BenchLeg", (0.8, 1.5, 2.6), (-20, 0.75, LZ + 8), DARK_WOOD, "Wood"),
    part("BenchLeg", (0.8, 1.5, 2.6), (-12, 0.75, LZ + 8), DARK_WOOD, "Wood"),
    part("Mailboxes", (8, 5, 1), (16, 5, LZ + 15), (70, 100, 140), "Metal", collide=False),
    part("Pot", (2.4, 2.4, 2.4), (19, 1.2, LZ - 12), (150, 104, 62), "Wood"),
    part("PotLeaves", (4.4, 4.4, 4.4), (19, 4.4, LZ - 12), (60, 140, 70), "Grass", shape="Ball", collide=False),
    part("LobbyLamp", (1.4, 1.4, 1.4), (0, 10.4, LZ + 4), WARM, "Neon", shape="Ball", collide=False, children=[light(WARM, 36, 1.4, False)]),
    part("LobbyLamp", (1.2, 1.2, 1.2), (-21.8, 8, LZ - 6), WARM, "Neon", shape="Ball", collide=False, children=[light(WARM, 22, 1.0, False)]),
    {"Name": "SpawnLocation", "ClassName": "SpawnLocation", "Properties": {
        "Anchored": True, "Size": [10.0, 1.0, 10.0], "CFrame": [0.0, 0.3, LZ + 4.0] + ROT,
        "Color": [0.47, 0.24, 0.24], "Material": "Fabric", "TopSurface": "Smooth", "BottomSurface": "Smooth",
        "Neutral": True, "Duration": 0, "Transparency": 1, "CanCollide": False}},
]

model = {"ClassName": "Folder", "Children": [
    folder("Ground", ground),
    folder("Apartment", [
        folder("Floors", floors), folder("Walls", walls), folder("Windows", windows), folder("Furniture", furniture),
    ]),
    folder("Lights", lights),
    folder("CreakyZones", creaks),
    folder("Beds", beds),
    folder("HideSpots", hide_spots),
    folder("Sources", sources),
    folder("Items", items),
    folder("Interactables", [tv, tap, marker("SofaSeat", (-37.75, 1, 24))]),
    folder("Waypoints", waypoints),
    folder("Lobby", lobby),
]}

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "workspace", "Map.model.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as f:
    json.dump(model, f, separators=(",", ":"))


def count(node):
    return 1 + sum(count(c) for c in node.get("Children", []))


print("instances:", count(model))
