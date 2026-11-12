# Сбежавший Урожай (Runaway Harvest)

A multiplayer farming-chase game for Roblox, written in Luau. Players plant seeds, crops grow,
and some of them mutate, come alive and run away across the map. Catch them (yours or anybody
else's) and sell them. All player-facing text is in Russian.

> Status: the project builds with Rojo and passes static type-checking against the Roblox API,
> but it was written outside Roblox Studio and has **not been play-tested in the engine yet**.
> Expect to tune balance and fix small things on the first Studio run.

## Open in Roblox Studio

**Option A — just open the place file (no tools needed)**

1. Open `RunawayHarvest.rbxlx` in Roblox Studio (File → Open from File).
2. Press **Play** (F5).

**Option B — live sync with Rojo (for editing the code in this folder)**

1. Install [Rojo 7](https://rojo.space/docs/v7/getting-started/installation/) and its Studio plugin.
2. In this folder run `rojo serve`.
3. In Studio open an empty Baseplate, delete the default `Baseplate` and `SpawnLocation`,
   then press **Connect** in the Rojo plugin.

To rebuild the place file after changing code: `rojo build -o RunawayHarvest.rbxlx`.
To regenerate the map after editing `tools/gen_map.py`: `python3 tools/gen_map.py`.

## Structure

```
ReplicatedStorage
  Shared/GameData          seeds, rarities, mutations, upgrades, pets, events, sounds, balance
  Remotes/                 RemoteEvents (Plant, Harvest, CatchStart, CatchStop, CatchProgress, Sell,
                           Buy, EquipPet, PlaceTrap, Whistle, Rebirth, StateUpdate, Notify, ...)
ServerScriptService
  Main                     loads the systems in order
  Systems/World            map references, Russian signs, stand prompts
  Systems/PlayerData       profiles, DataStore saving, leaderstats, state sync
  Systems/PlotService      garden plots, planting, harvesting
  Systems/GrowthService    growth stages and mutation rolls
  Systems/CreatureService  escaped crops: models and escape AI, traps, titan stomp
  Systems/CatchService     catch meter (hold E for 3 s)
  Systems/SellService      sell stand
  Systems/ShopService      seeds, Забор, Липкая Ловушка, Свисток, Расширение, pets, Перерождение
  Systems/PetService       pets that follow and auto-catch
  Systems/EventService     random events
  Systems/AntiExploit      rate limits, argument and distance checks
  Systems/Debug            Studio-only test switches
StarterGui
  MainGui                  Russian UI: Hud, Windows (shop / inventory / upgrades), Controller, Effects
Workspace
  Map                      Ground, Plaza (statue, stands, spawn), Plots (8 gardens), Forest, Fields, Signs
```

Source files live in `src/`; `default.project.json` maps them to the tree above.

## How to play

| Action | Control |
| --- | --- |
| Plant the selected seed / harvest a ripe crop | **F** at a soil slot on your plot |
| Catch an escaped crop | get close and **hold E** for 3 seconds (button «ЛОВИТЬ» on phones) |
| Sell | **F** at the «ПРОДАЖА УРОЖАЯ» stand, then «Продать Урожай» |
| Buy seeds | button «Магазин», or **F** at the «МАГАЗИН СЕМЯН» stand |
| Whistle / place trap | **Q** / **T** (after buying them in «Улучшения») |

Design decisions worth knowing:

- A ripe crop rolls for mutation every 5 seconds. Harvest it before that for the base price, or
  wait and gamble on a mutation (x2 … x200) that you then have to catch.
- A creature that is not caught within 90 seconds is gone for good.
- «Расширение» becomes available at 250 000 and costs 250 000.
- «Перерождение» needs 1 000 000. It resets money, seeds, inventory and growing crops; upgrades,
  expansion and pets stay.
- Pets all catch within 10 studs every 20 seconds; the more expensive ones also add a sell bonus.
- The seed you called "Golden Seed" is named «Золотое Семя» in the game, to keep the UI fully Russian.
- Crops that are still growing are not saved when a player leaves.

All numbers are in `src/shared/GameData.luau` (`Config`, `Seeds`, `Mutations`, `Upgrades`, `Pets`, `Events`).

## Testing

**Solo**

1. Press **Play**. You spawn at your plot; pick «Морковь» in the bottom bar and press F at a slot.
2. Speed things up with the Studio-only switches. In the **Command Bar**, with the view switched
   to **Server** (Test tab → Current: Client/Server):

   ```lua
   workspace:SetAttribute("DebugGrowSpeed", 20)   -- crops grow 20x faster
   workspace:SetAttribute("DebugMoney", 300000)   -- money for every player
   workspace:SetAttribute("DebugEvent", "night")  -- night | rain | silence
   ```

3. Checklist: plant → stages change → harvest → sell; leave a crop ripe until it runs away →
   hold E to catch → wait out the 20 s tag → sell; buy Забор / Ловушка / Свисток and try each;
   give yourself 300 000 → buy «Расширение» and a pet; give 1 000 000 → «Перерождение» →
   «Золотое Семя» appears in the shop; start each event with `DebugEvent`.

**Two players**

1. Test tab → **Clients and Servers** → Local Server, 2 Players → **Start**.
2. Check that each player gets their own plot, that player 2 can catch (steal) a crop that escaped
   from player 1, that player 1 gets the «украл твой урожай» message, and that a trap placed by
   one player stops a crop owned by the other.

**Saving** works only in a published place: publish first, then enable
Home → Game Settings → Security → **Enable Studio Access to API Services**. Without it the game
shows «Сохранение сейчас недоступно» and runs without saving.

## Publishing

1. File → **Publish to Roblox As…**, create a new experience.
2. Game Settings → Security: enable API Services (needed for DataStore saving).
3. Game Settings → Places → set **Maximum Players to 8** (there are 8 garden plots; extra players
   can still chase crops but get no plot).
4. Game Settings → Permissions → set the experience to **Public**.

## Sounds

`GameData.Sounds` uses sounds built into the Roblox client (`rbxasset://sounds/...`) as
placeholders, so no assets have to be uploaded. Replace the ids with your own `rbxassetid://`
sounds for a proper mutation scream and a cha-ching.

## Anti-exploit summary

- Growth, mutation rolls, creature movement, catch progress, prices and purchases all live on the server.
- Every RemoteEvent goes through `AntiExploit.connect`: per-player rate limit, type checks, and a
  kick after sustained flooding.
- Planting, harvesting and selling check the distance from the character to the slot or stand;
  the trap is placed at the character's own position, never at a position sent by the client.
- Loaded save data is rebuilt field by field, and a profile that failed to load is never saved over.
