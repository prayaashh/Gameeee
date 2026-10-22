# NPC dialogue files

NPC conversations live in a plain-text file you write in Notepad (or any
editor). Pick the file in the NPC's **Dialogue File** field in the Inspector —
no need to fill in the old question/answer/pickup fields any more.

Files live wherever you like; this project keeps them in `dialogue/`.
The Windows export preset already includes `*.txt`, so dialogue files ship with
the game.

## The smallest working file

```
name: Dionysus

Stage 0: (default stage)
	play: idle
	speak: "Oh, so you have come"
	ask: "will you find my lantern?"
	choices: "yes" -> 1, "no" -> 2
```

- Lines starting with `#` are comments and are ignored.
- Indentation can be a tab or spaces; the amount does not matter.
- `(default stage)` after a stage name is just a note — it is ignored.
- Quotes around text are optional, but they let you keep leading/trailing
  spaces and use commas inside a line. `speak: Hello there` also works.
- Write `\n` inside a line for a manual line break.

## Top level

| Line | Meaning |
|---|---|
| `name: Dionysus` | Name shown above the text. If left out, the NPC's **Name** field is used. |
| `entry: ...` | Which stage to start at. Repeat it; **first match wins**. If none match, the NPC starts at `Stage 0`. |
| `Stage 0:` | Starts a stage. The id can be a number or a word (`Stage accepted:`). |

### Entry rules

```
entry: flag lantern_done -> 4       # only if this save flag is set
entry: noflag lantern_quest -> 6    # only if it is NOT set
entry: else -> 0                    # always matches - keep this last
```

Check the more specific cases first (finished quest before active quest), then
finish with `entry: else -> 0`. Without any `entry:` lines the NPC always
starts at `Stage 0`.

## Commands inside a stage

| Command | Meaning |
|---|---|
| `play: idle` | Play this animation from the NPC's SpriteFrames. |
| `speak: "text"` | Show a line. Repeat for more lines; they appear in order. |
| `ask: "question"` | Show a question with the buttons from `choices`. |
| `choices: "yes" -> 1, "no" -> 2` | Button labels. `-> id` jumps to a stage; no arrow ends the conversation. |
| `set: flag` | Set a save flag (survives quitting; saved with the game). |
| `set: a, b` | Set several flags at once. |
| `unset: flag` | Clear a save flag. |
| `goto: 3` | Continue in another stage instead of ending. |
| `end` | Stop here (same as leaving `goto` out). |

Flags are written straight into the save file, so a quest state survives
restarting the game. Flag names are yours to choose.

## How a stage runs

1. `play` (if given)
2. every `speak` line, in order
3. `ask` + `choices` (if given) — the chosen stage runs next
4. `set` / `unset`
5. `goto` (if given), otherwise the conversation ends

Stages can chain, so a choice can lead to another question. The NPC's default
animation is restored when the conversation ends.

## Example: a quest with three states

```
name: Dionysus

entry: flag lantern_done -> 4
entry: flag lantern_quest -> 3
entry: else -> 0

Stage 0: (first talk)
	play: idle
	speak: "Oh, so you have come"
	ask: "will you find my lantern?"
	choices: "yes" -> 1, "no" -> 2

Stage 1: (accepted)
	play: talk
	speak: "Then go. The cave beyond the castle swallows everything."
	set: lantern_quest

Stage 2: (declined)
	speak: "Then we have nothing more to say."

Stage 3: (in progress)
	speak: "Have you found it yet?"

Stage 4: (done)
	play: talk
	speak: "You found it. I knew the dark could not keep it from you."
```

To finish the quest elsewhere in code:

```gdscript
GameState.set_flag("lantern_done")
```

## Warnings

When an NPC spawns, typos are reported in the **Output** panel with the file and
line number: unknown commands, choices/gotos that point at stages that do not
exist, and animation names that are not in the NPC's SpriteFrames. The game
still runs with the problem skipped.

## Doing more than text

Text, questions and flags are handled by the file. For anything else (credits,
doors, spawning), override `after_interaction(outcome)` in `npc.gd`, or connect
the `interaction_finished` signal in the Inspector. `outcome` is the last stage
id that ran, or `cancelled` if the player pressed Esc.

```gdscript
func after_interaction(outcome: StringName) -> void:
	if outcome == &"4":
		GameState.add_credits(100)
```
