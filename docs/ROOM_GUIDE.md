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
| `Room` (root) | has `room.gd` attached — sets camera bounds, warns if `player` is missing | yes — don't remove the script |
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

## 5. Camera bounds

The camera lives **inside `player.tscn`** (it follows the player
automatically). Each room clamps it via the root's `camera_bounds`
(Rectangle) in the Inspector:

- Room 01: `Rect2(-64, -360, 1568, 704)`
- Room 02: `Rect2(-64, -360, 1392, 704)`

`x/y` = top-left corner of the allowed camera area, `w/h` = its size.
Set it to roughly your room's visible area (a little padding is fine).
If you leave it at the template default, the camera just uses those values —
adjust them to your room's width.

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

- Instance `scenes/npc.tscn` under `NPCs/` — see the NPC section below.
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

## 9. NPC events — running your own code after a conversation

Every NPC has an event hook at the bottom of `scripts/npc_scripts/npc.gd`:

```gdscript
func after_interaction(outcome: StringName) -> void:
	...
	# --- put your own code below this line, guided by `outcome` ---
```

It runs **every time a conversation with that NPC ends**. The `outcome`
argument tells you how it ended:

| outcome | meaning |
|---|---|
| `&"accepted"` | the player just accepted the quest (fires once per accept) |
| `&"declined"` | the player just declined (can fire again if they refuse again) |
| `&"completed"` | the quest-complete lines were shown — **fires only once ever** for that NPC, so it is safe for big one-shot events |
| `&"repeat"` | in-progress chatter (`repeat_lines`) — fires every talk |
| `&"react"` | reaction lines — fires every talk |
| `&"ended"` | a plain conversation with no question |
| `&"cancelled"` | the player pressed Esc mid-conversation |

Examples:

```gdscript
func after_interaction(outcome: StringName) -> void:
	if outcome == &"completed":
		GameState.add_credits(100)            # reward on turn-in
		GameState.set_flag("gate_open")       # open something elsewhere
	if outcome == &"accepted":
		get_tree().call_group("doors", "open")
```

Notes:

- The `completed` once-guard is automatic: the save flag
  `"<complete_flag>_event"` is written the first time, so re-talking (even
  after reloading the game) never repeats the event.
- Don't open a new Dialogue from this function — the conversation has just
  closed. Change game state instead (credits, flags, spawning, doors…).
- If you'd rather wire it up in the editor than edit code, the same event is
  emitted as the signal `interaction_finished(outcome)` at the top of
  `npc.gd` — select the NPC node and connect it in the Inspector.
