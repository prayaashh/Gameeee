# Room guide — building your world

Every room in the game is one scene. This is the recipe for making new ones,
based on `scenes/rooms/room_template.tscn` (the starting point) and the two rooms
that already work: `scenes/rooms/game.tscn` (room 1) and `scenes/rooms/room_02.tscn`.

---

## 1. Create the room

1. In the FileSystem panel, right-click `scenes/rooms/room_template.tscn` → **Duplicate…**
2. Name it something like `room_03.tscn` and save it.
3. Open it. The template already contains everything a room must have:

| Node        | What it is | Required? |
|-------------|------------|-----------|
| `Room` (root) | has `room.gd` attached — configures the room camera, warns if `player` is missing | yes — don't remove the script |
| `player`    | the one Player instance for this room | yes — every room has exactly one |
| `TileMap`   | your level geometry | optional (you can build floors from StaticBody2D instead) |
| `Entrances/Spawn` (Marker2D) | where the player appears when booting a save in this room | yes |
| `Doorways/` | container for Doorway instances | keep the folder |
| `Checkpoints/` | container for benches | keep the folder |
| `Enemies/`, `NPCs/` | containers | keep the folder |
| `HUD`       | hearts + credits overlay (one per room — rooms are swapped, not layered) | yes |

Rename the **root node** to match the file (e.g. `room_03`) — the root's name
is cosmetic, but keeping it tidy helps.

---

## 2. Floors and walls (the #1 gotcha)

Godot physics uses **collision layers**. In this project:

- **World geometry must be on collision layer 2.** The player only collides
  with layer 2.
- If your floor is on the default layer 1, **the player falls straight
  through it.**

If you build a floor from parts (like room 02 does):

1. Add a **StaticBody2D** node.
2. In the Inspector set **Collision → Collision Layer = 2** (bit 2 checked,
   bit 1 unchecked).
3. Add a `CollisionShape2D` child with a `RectangleShape2D`.
4. Add a **ColorRect** child at the same position as the visual surface.

Working example from `room_02.tscn`:

- Shape: size `1264 × 64`, body at `(600, 64)` → solid top surface at **y = 32**
- ColorRect: `offset_left -32, offset_top 32, offset_right 1232, offset_bottom 96`
  (paints the same rectangle it collides with)

If you use the TileMap, physics is already configured (`physics_layer_0`
is layer 2) — just paint tiles.

**Standing height rule:** with the floor surface at `y = 32`, the player
stands at `y = 13`. So entrance markers and benches on that floor go at
`y = 13`…`32` range (spawn markers use `y = 13`).

---

## 3. Entrances

Add `Marker2D` nodes under `Entrances/`. Names are **case-sensitive** and are
referenced by name from doorways in other rooms:

```
Entrances/
  Spawn      ← boot/save spawn for this room
  West       ← where you land when coming through the west door
  East       ← ...
```

A doorway in another room saying `target_entrance = "West"` must match a
marker named exactly `West`. A typo produces a warning and the default spawn.

**Rule:** never place an entrance marker on top of (or inside) a doorway's
trigger — the player would immediately bounce back through the door.
Markers should be a comfortable step away from the door (see room 01's
`East` marker at x 1395 vs. its east doorway at x 1456).

---

## 4. Doorways (room-to-room travel)

1. Instance `scenes/doorway.tscn` under `Doorways/`.
2. Position it where the player crosses the room edge.
3. In the Inspector set:
   - **Target Scene** — the `.tscn` file of the destination room
   - **Target Entrance** — the marker name in that room (e.g. `West`)

The trigger is a rectangle **56 px wide × 160 px tall**, centred 60 px above
the doorway's position. Concretely, the trigger covers:

- X: `position.x − 28` … `position.x + 28`
- Y: `position.y − 140` … `position.y + 20`

So the doorway's Y should sit near floor level. Proven placements:

- Room 01 east door: `position = (1456, 0)` with floor surface y = 32
- Room 02 west door: `position = (40, 32)`

While testing, make sure the player actually **walks into** the trigger
(bumping the room's right wall at x = 1440 is exactly what fires room 01's
door — that is normal).

Doorways also ignore the player while a dialogue is open, during the
0.35 s transition lock after a scene change, and while the player is dead —
you don't need to do anything for that.

---

## 5. Camera

The camera lives **inside `player.tscn`** and follows the player automatically.
By default it is **unbounded**, so it keeps the player centered even past the
room's edges — you don't need to set anything for a new room.

If you *do* want to constrain the camera, the room root has these fields in
the Inspector:

- **Camera Fit Height** — world-space height the camera should show. Set it to
  a background's height (texture height x its parent's scale) so that
  background fills the screen top to bottom. `0` leaves the zoom alone.
- **Camera Limit Left / Top / Right / Bottom** — the four camera limits, in
  world coordinates (the same values a `Camera2D` has). The camera's view is
  kept inside them and stops at each edge. They default to the "no limit"
  values, so only change the edges you want.

Examples:

- **Stop the camera moving up/down while jumping:** set **Top = 0** and
  **Bottom = 640** (the background's top/bottom) with **Camera Fit Height =
  640**. The camera's Y is pinned and it only scrolls sideways.
- **Clamp the camera to the room's edges:** set all four limits.
- **Free-following camera:** leave everything at its default.

---

## 6. Checkpoints (benches)

Instance `scenes/checkpoint.tscn` under `Checkpoints/`, set:

- **Checkpoint Id** — any unique string (`room03_bench`)
- **Rest Line** — the one line shown when resting (empty = rest silently,
  no dialogue)
- **Blink Speed** — how fast the "E" prompt pulses: `1.0` = original speed,
  `0.4` = slow. Same range as the NPC prompt (`0.1`–`3.0`).

Resting saves the game, heals to full, and records the player's exact
standing position as the respawn point (not the bench's origin, so you can't
be spawned inside a wall).

---

## 7. NPCs and enemies

- Instance `scenes/npc.tscn` under `NPCs/`, then set **Dialogue File** to a text
  file you wrote in Notepad (see `docs/NPC_DIALOGUE.md`). Give it a
  **Sprite Frames** resource if it should be animated.
- Instance `scenes/enemies/enemy.tscn` under `Enemies/`.

---

## 8. Testing your room

1. Open your room scene and press **F6** (Run Current Scene) to test it
   standalone.
2. Walk every doorway in both directions.
3. Check the player never falls through, the camera doesn't show outside
   your room, and the bench saves (quit and relaunch — you should wake up
   at your bench).

**Save compatibility warning:** checkpoints store the room's **file path**.
If you rename or move a room that a save points at, that save can no longer
find it (the game warns and starts fresh from room 01). Rename rooms only
while you don't care about existing saves.

---

## 9. NPC conversations — text files, not the Inspector

An NPC's lines, questions, stages, flags and animations all live in a plain-text
file picked in its **Dialogue File** field. Write it in Notepad; full syntax is in
`docs/NPC_DIALOGUE.md`. Example (`dialogue/Dionysus.txt`):

```
name: Dionysus

entry: flag lantern_done -> 4
entry: flag lantern_quest -> 3
entry: else -> 0

Stage 0: (default stage)
	play: idle
	speak: "Oh, so you have come"
	ask: "will you find my lantern?"
	choices: "yes" -> 1, "no" -> 2

Stage 1:
	play: talk
	speak: "Then go. The cave beyond the castle swallows everything."
	set: lantern_quest
```

`Stage 0` is the first-conversation default. `entry:` rules pick a different
starting stage once flags are set (quest accepted, finished, declined…).
Flags are stored in the save file, so quest state survives quitting.

### Running your own code after a conversation

Text, choices and flags need no code. For anything else (credits, doors,
spawning), either override `after_interaction(outcome)` at the bottom of
`scripts/npc_scripts/npc.gd`, or connect the `interaction_finished` signal in the
Inspector. `outcome` is the id of the last stage that ran, or `cancelled` if the
player pressed Esc.

```gdscript
func after_interaction(outcome: StringName) -> void:
	if outcome == &"4":                        # the "quest done" stage
		GameState.add_credits(100)
		GameState.set_flag("gate_open")
```

Notes:

- Typos are reported in the **Output** panel when the NPC spawns: unknown
  commands, choices/`goto`s pointing at stages that do not exist, and animation
  names missing from the NPC's SpriteFrames. The game keeps running.
- Don't open a new Dialogue from `after_interaction()` — the conversation has
  just closed. Change game state instead.
