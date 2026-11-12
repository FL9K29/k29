# Тихий Час (Night Snack Sneak)

A 1–4 player co-op stealth game for Roblox, written in Luau. Players are kids sneaking through
an apartment at night: take 5 snacks from the kitchen, hide them in the bedroom, and do not get
caught by «Родитель», who patrols with a flashlight and good hearing. All player-facing text is
in Russian and lives in one module (`src/shared/Config.luau`, table `Config.Text`).

> Status: the project builds with Rojo and passes static type-checking against the Roblox API,
> but it was written outside Roblox Studio and has **not been play-tested in the engine yet**.
> Expect to fix small things and tune balance and lighting on the first Studio run.

## Open in Roblox Studio

**Option A — open the place file (no tools needed)**

1. Open `TikhiyChas.rbxlx` in Roblox Studio (File → Open from File).
2. Press **Play** (F5). You start in the lobby («подъезд»); press «Готов».

**Option B — live sync with Rojo (for editing the code in this folder)**

1. Install [Rojo 7](https://rojo.space/docs/v7/getting-started/installation/) and its Studio plugin.
2. In this folder run `rojo serve`.
3. In Studio open an empty Baseplate, delete the default `Baseplate` and `SpawnLocation`,
   then press **Connect** in the Rojo plugin.

Rebuild the place file after changing code: `rojo build -o TikhiyChas.rbxlx`.
Regenerate the map after editing `tools/gen_map.py`: `python3 tools/gen_map.py`.

## Structure

```
ReplicatedStorage
  Shared/Config            balance, snacks, skins, upgrades, events, waypoint graph, sounds,
                           and Config.Text — every Russian string in the game
  Remotes/                 RemoteEvents: Pickup, Deliver, Sleep, Hide, GrabItem, Throw, UseObject,
                           Crouch, Ready, Buy, Equip (client → server); Notify, Banner, Effect
ServerScriptService
  Main                     loads the systems in order
  Systems/RoundManager     lobby → lift countdown → round → results → lobby; win/lose; rewards
  Systems/NpcBrain         Родитель: patrol, vision cone + raycasts, hearing, chase, carry, sleep
  Systems/Navigation       PathfindingService routes with the waypoint graph as fallback
  Systems/Noise            noise bus (footsteps, thrown items, tap, cat); TV halves all radii
  Systems/StealthService   crouch, footstep noise, speed check, stun timer
  Systems/SnackService     snack pickup (4 s hold), delivery, going to bed
  Systems/HideService      2 шкафа, 3 «под кроватью», bath curtain
  Systems/InteractService  throwable тапки / мячик, TV, bathroom tap
  Systems/EventService     «Кот пробежал!», «Родитель уснул на диване», «Свет мигнул»
  Systems/ShopService      пижамы and upgrades for Звёздочки
  Systems/PlayerData       DataStore: Звёздочки, owned skins, equipped skin, upgrades, wins
  Systems/Session          per-round state of every player, mirrored to Player attributes
  Systems/World            map references, proximity prompts
  Systems/AntiExploit      rate limits, argument and distance checks
StarterGui
  MainGui                  Russian UI: Hud, Lobby (lobby panel, results, shop), Controls,
                           ParentVisual (the visible Родитель and the cat), Sounds, UIKit
Workspace
  Map                      Apartment (bedroom, bathroom, kitchen, corridor, living room, hall),
                           Beds, Sources, HideSpots, Items, CreakyZones, Lights, Waypoints, Lobby
```

## How to play

| Action | Control |
| --- | --- |
| Take a snack (kitchen: fridge, freezer, counter, table) | hold **E** for 4 seconds |
| Hide the snack in a bed in the bedroom | **E** at a bed |
| Crouch (slow, quiet) | **Ctrl** or **C** |
| Hide in a wardrobe / under a bed / behind the bath curtain, and climb out | **E** |
| Pick up a тапок or мячик, then throw it | **E**, then **F** (it flies where the camera looks) |
| Turn on the TV, open the bathroom tap | **E** |
| Lie down in bed (when a teammate already has all 5) | hold **G** at a bed |

On phones the prompts are tappable and the buttons «Красться», «Бросить», «Вылезти» appear.

Rules worth knowing:

- You carry 1 snack at a time (3 with «Рюкзак»). Each player needs 5 delivered.
- Running is heard within 20 studs, crouching within 6, creaky boards (the darker ones) within 35.
  While the TV plays (30 s) every radius is halved.
- Родитель sees in a 70° cone up to 30 studs; walls and furniture block his view. He reacts for
  1 second («!»), then chases. If he loses you for 5 seconds he goes back to patrolling.
- A hiding spot does not help if he watched you climb in.
- Caught: he carries you to your bed, you lose one random carried snack and lie stunned for 10 s.
- **Win:** at least one player delivered all 5 snacks and everybody else is finished too or lying
  in bed. **Lose:** the 6 minutes run out.
- Rewards: 2 ★ per delivered snack, +15 ★ for a win, +10 ★ more if you delivered all 5.

Design decisions and limits:

- Родитель chases at 16.5 studs/s against the players' 16, so running in a straight line does
  not shake him off — break the line of sight or hide.
- The «Комната» code in the lobby is only a label for the server. Joining a specific room by
  code would need reserved servers (TeleportService) and is not implemented.
- Пижамы recolour the character (top, bottom, nightcap); they are not custom clothing assets.
- Sounds are Roblox built-in placeholders (`Config.Sounds`); swap the ids for your own.
- The map has no ceiling, so the camera never gets stuck; the night mood comes from Lighting.

## Testing with several players (Studio)

1. **Solo:** press **Play**, press «Готов», wait for the 10-second lift countdown.
2. **2–4 players:** Test tab → **Clients and Servers** → Local Server, choose 2–4 Players →
   **Start**. Studio opens one server window and one window per player. Press «Готов» in every
   client window; the countdown starts when all are ready.
3. Checklist:
   - take a snack (hold E), carry it to a bed, check «Собери перекусы: 1/5»;
   - run near Родитель → «!» → chase → caught → carried to bed, 10 s stun, a carried snack is lost;
   - crouch past him; step on a dark floorboard and watch him come;
   - hide while he does not see you (he gives up) and while he does (he pulls you out);
   - throw a тапок to lure him; turn on the TV; open the tap;
   - with 2 players: one finishes 5 snacks, the other holds G at a bed → «Победа!»;
   - let the timer run out → «Вас поймали...»;
   - buy a пижама and an upgrade in the lobby shop, rejoin and check they are still there.
4. To test faster, lower `Config.Round.Duration` or `Config.Round.EventMinDelay` /
   `EventMaxDelay`, or raise `Config.Rewards`, then press Play again.

**Saving** (Звёздочки, skins, upgrades, wins) works only in a published place with
Home → Game Settings → Security → **Enable Studio Access to API Services** turned on. Otherwise
the game shows «Сохранение сейчас недоступно» and runs without saving.

## Publishing

1. File → **Publish to Roblox As…**, create a new experience.
2. Game Settings → Security: enable API Services (needed for DataStore saving).
3. Game Settings → Places → set **Maximum Players to 4**.
4. Game Settings → Avatar: either avatar type works; R15 is recommended.
5. Game Settings → Permissions → set the experience to **Public**.

## Anti-exploit summary

- Родитель lives entirely on the server: patrol, vision raycasts, hearing, chase and the catch
  check (distance, same floor level, recently in sight).
- Every RemoteEvent goes through `AntiExploit.connect`: per-player rate limit, type checks and a
  kick after sustained flooding.
- Snack pickup: the server measures the real hold time and checks distance and carrying capacity.
  Delivery, hiding, grabbing items, TV and tap all check the distance from the character.
- Throwing: the client sends only a direction; origin and speed are set by the server.
- Movement: the server samples every player's speed, rubber-bands anyone faster than a running
  kid, and decides footstep noise from the measured speed, not from what the client claims.
- Loaded save data is rebuilt field by field, and a profile that failed to load is never saved over.
