# Skull Pillar (work in progress)

Temporary handover note. Written so another agent can pick the hazard up
without re-reading the code. Delete this file once the hazard is finished and
placed in rooms.

## What it is

A bone pillar with a skull face. It stands still until the player comes close;
then its eyes light up and it spits orbs at the player's chest. The orbs fly in
a straight line, so moving or jumping dodges them. It never stops firing while
the player stays close, and it never dies.

## Files

| File | What it is |
| --- | --- |
| `scenes/hazards/skull_pillar.tscn` | The hazard. Drop it in a room's `Hazards`/`Enemies` node. |
| `scripts/hazards/skull_pillar.gd` | Detection, glow, firing. |
| `scenes/hazards/skull_projectile.tscn` | The orb it fires. Spawned at runtime, do not place by hand. |
| `scripts/hazards/skull_projectile.gd` | Flight, damage, burst. |
| `assets/hazards/skullpillar.png` | 400x600 sheet. |
| `assets/hazards/skullpillarprojectile.png` | 240x48 sheet. |
| `assets/hazards/skull_pillar_frames.tres` | SpriteFrames built from the pillar sheet. |
| `assets/hazards/skull_projectile_frames.tres` | SpriteFrames built from the orb sheet. |

## Node layout of `skull_pillar.tscn`

```
SkullPillar (Node2D, skull_pillar.gd, scale 1.5)
├── AnimatedSprite2D       offset (0, -47) so the art's bottom sits on the origin
├── Body (StaticBody2D)    collision_layer 2 (room/world layer), mask 0
│   └── CollisionShape2D   RectangleShape2D 21 x 73 at (0, -36.5)
└── Muzzle (Marker2D)      (0, -50), the eye line the orbs come from
```

The node origin is the **bottom of the pillar**. Dropping the node on the floor
places it correctly; no per-room offset math is needed.

## Art layout (as measured from the PNG)

`skullpillar.png` is a 4 x 6 grid of **100 x 100** cells. The pillar art inside
a cell is 21 x 73 px, horizontally centred (`x 39..59`) and bottom-aligned
(`y 25..97`). The eye glow lives at `y 46..47`.

The sheet holds **three designs** of the same pillar, each with a 1-frame idle
and a 4-frame activated set:

| Design | idle (row, col) | activated (row, cols 0-3) |
| --- | --- | --- |
| 1 | row 0 | row 1 |
| 2 | row 3 | row 2 |
| 3 | row 4 | row 5 |

Design 2 is stored activated-first in the sheet; that is not a mistake.
Animation names in `skull_pillar_frames.tres`: `idle`, `activated`, `idle_2`,
`activated_2`, `idle_3`, `activated_3`. The `variant` export (1-3) picks one.

## Behaviour

`enum State { IDLE, CHARGING, FIRING }`, polled every physics frame.

- **IDLE** - plays `idle`. When a node in the `player` group is within
  `detection_radius` of the pillar's base, switch to CHARGING and play
  `activated` (eyes glow).
- **CHARGING** - wait `charge_time` (0.7 s) as a warning window. The player
  leaving the radius at any point cancels back to IDLE.
- **FIRING** - first orb right after the charge, then one every
  `fire_interval` (1.8 s) while the player stays close. Player leaving ->
  IDLE and the eyes go dark.
- Aim point is `player.global_position + (0, -18)`, i.e. chest height, sampled
  at the moment of firing. No prediction, so strafing or jumping works.
- Orbs are spawned as children of the pillar's parent so they don't inherit
  the pillar's transform.

## Projectile

`skull_projectile.gd` is an `Area2D` with `collision_mask = 3` (player layer 1
+ room layer 2), `collision_layer = 0`. It moves by `direction * speed * delta`.

- Touching the player (`player` group): `take_damage(damage, global_position)`,
  then bursts.
- Touching anything else on layer 1 or 2 (walls, floor): burst only.
- `ignore` is set by the pillar to its own `Body`, because the muzzle sits
  inside the pillar; otherwise the orb bursts the instant it spawns.
  Note: `Area2D` has no `add_collision_exception_with()` in Godot 4.7, which is
  why this is a plain node check.
- Burst: plays `burst` (5 frames at 14 fps) with monitoring off, then frees
  itself. Lifetime cap is 6 s.

## Exports and current defaults

| Export | Default | Notes |
| --- | --- | --- |
| `detection_radius` | 260 | Distance from the pillar's base. |
| `charge_time` | 0.7 | Glow delay before the first shot. |
| `fire_interval` | 1.8 | Gap between shots while close. |
| `projectile_speed` | 320 | Orb speed in px/s. |
| `damage` | 1 | Hearts per hit. |
| `variant` | 1 | Pillar design 1-3. |

Root `scale` is 1.5, which makes the pillar about 31 x 110 px in the world (the
player art is roughly 40 x 58 px). Change the scale on the root if it reads too
small or too large; the hitbox and muzzle scale with it.

## Collision layer conventions in this project

| Layer | Used by |
| --- | --- |
| 1 | player |
| 2 | room tiles / world (also the pillar body) |
| 4 | enemies |
| 16 | hazards |

Player collision mask is 2, so anything the player must stand on or bump into
belongs on layer 2. The player's sword hitbox has mask 4, so the pillar is not
destructible.

## Known gaps / sensible next steps

- Not placed in any room yet. `castle_1_room_1.tscn` has a good spot on the
  right-hand stretch past the floor spike.
- No sound, no screen shake, no damage flash on the pillar itself.
- Orbs pass through doorways and NPCs (they only care about layers 1 and 2).
- The player cannot destroy the pillar. If that should change, move it to
  layer 4 or add an `Enemy`-style health script.
- The pillar fires through walls; it only measures distance. A line-of-sight
  raycast on layer 2 would fix that if it matters.
- The three designs are only selectable through the `variant` export. If the
  room should mix them automatically, add a random pick in `_ready()`.
- Orbs are not pooled; a long fight allocates/frees a few nodes per second,
  which is fine at this scale.

## How it was verified

Headless run of a scratch scene containing both this pillar and the
chandelier, with a stub `player` body. Final result:

```
PASS  has idle + activated
PASS  has all three pillar designs
PASS  stays idle with the player far away
PASS  fires nothing with the player far away
PASS  eyes light up when the player comes close (state=1, anim=activated)
PASS  nothing fires during the charge-up
PASS  shoots after charging (1 orbs out)
PASS  the orb damages the player (hits=1)
PASS  keeps firing while the player stays close (3 hits)
PASS  goes back to idle when the player leaves
```

The scratch test files (`_dev_*`) were deleted afterwards. To repeat, make a
scene with a stub `CharacterBody2D` in the `player` group on layer 1 and a
`StaticBody2D` floor on layer 2, instance the pillar, and log `_state`,
`sprite.animation`, `get_child_count()` and the stub's hit counter.
