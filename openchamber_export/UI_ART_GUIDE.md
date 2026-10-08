# Swapping in your custom UI art

How to replace the placeholder styling with your own artwork later, without breaking anything.

## 1. What is placeholder today

| Piece | File | Styled with |
|---|---|---|
| Dialogue panel background | `scenes/dialogue.tscn` → `Panel` | StyleBoxFlat (dark blue, rounded) via Theme Overrides |
| Dialogue text | `dialogue.tscn` → `Panel/VBoxContainer/TextLabel` | font size 20, word-smart wrap |
| Speaker name | `dialogue.tscn` → `Panel/VBoxContainer/NameLabel` | default font |
| Choice buttons | created in code by `scripts/autoload/dialogue.gd` | default engine theme |
| Pause menu background | `scenes/pause_menu.tscn` → `Panel` | StyleBoxFlat |
| Pause title + buttons | `pause_menu.tscn` | font 28 title, default buttons |
| NPC "E" prompt | `scenes/npc.tscn` → `Prompt` | text "E", font 16, black outline |

**Yes, you can change the fonts at any time.** Nothing in the scripts hardcodes a font — every font
and size lives in the scenes as a Theme Override, so swapping them is a pure editor change.

## 2. Import your art

1. Create `assets/UI/` (and `assets/Fonts/`).
2. Drag your `.png` / `.ttf` / `.otf` files in. Godot imports them automatically.
3. For panel backgrounds, export **9-patch style** images: a small picture whose border pixels are
   designed to stretch while the corners stay sharp. A plain stretched photo will smear the corners.

## 3. Replace a panel background (dialogue or pause menu)

1. Open the scene, select the `Panel` node.
2. Inspector → **Theme Overrides → Styles → panel → New StyleBoxTexture**.
3. Click it, set **Texture** to your PNG.
4. Set the **margin values** (content margins) to keep the text padding you have now:
   dialogue: left/right 16, top/bottom 12. Pause: your choice.
5. Set **Texture margins** (the *Margin* row) to the thickness of your art's border so the corners
   don't stretch. This is what makes a 9-patch behave.
6. Do **not** touch anchors/offsets — only the style changes. Layout stays top-center.

## 4. Fonts

1. Import your `.ttf`/`.otf`.
2. Select the label (`TextLabel`, `NameLabel`, pause `Title`, `Prompt`).
3. **Theme Overrides → Fonts → font** → your FontFile.
4. Sizes stay in **Theme Overrides → Fonts → font_size** (20 dialogue text, 16 prompt, 28 pause title).
5. Optional global default: **Project Settings → GUI → Theme → custom_font** (or assign a Theme
   resource there) — applies everywhere that has no explicit override. Per-label overrides win.

## 5. Buttons (choices + pause menu)

- **Per button:** select it → Theme Overrides → Styles → `normal` / `hover` / `pressed` → New
  StyleBoxTexture → your art (same margin trick as step 3).
- **All buttons at once:** Project Settings → GUI → Theme → New Theme, set the Button styles in it,
  and pick it as the default. Style once, applies everywhere.

## 6. The NPC "E" prompt

Pick one:

- **Keep the Label (simplest):** import an icon font containing the key glyph, assign it as the
  font override on `Prompt`, change the text to that glyph. The blink animation keeps working.
- **Swap to an image:** change the `Prompt` node type from `Label` to `TextureRect`, set its
  Texture to your art, and update one line in `scripts/npc_scripts/npc.gd`:
  `@onready var prompt: Label = $Prompt` → `@onready var prompt: TextureRect = $Prompt`.
  Centering (anchors), `z_index = 10`, and the blink all still work.

## 7. Screen zones to respect (default 1152×648)

- **Dialogue panel:** centered, roughly x 276–876, y 20–176. Keep clear.
- **Top-left (x < 276):** reserved for health.
- **Top-right (x > 876):** reserved for future UI.
- **Pause menu:** covers the whole screen — no conflicts.
- Stretch mode is `canvas_items` + `expand`, so the dialogue stays centered at other window sizes;
  the side zones grow/shrink with the screen.

## 8. Do not change

- **Node names and paths:** `Panel`, `Panel/VBoxContainer`, `NameLabel`, `TextLabel`, `ChoiceBox`,
  `Prompt` — the scripts find them by path and will break otherwise.
- **Autoload names:** `GameState`, `Dialogue`, `PauseMenu`.
- **Anchor/grow values** on the dialogue `Panel` (top-center, grows downward) — layout, not style.
- The scripts (`dialogue.gd`, `npc.gd`, `pause_menu.gd`) — styling needs no code changes.

## 9. Quick check after each change

1. Run the game.
2. Walk to the NPC → the **E** blinks above its head.
3. Press **E** → panel appears top-center, text wraps, choices appear; declining and re-talking
   re-asks the question.
4. **Esc** during talk cancels the dialogue; **Esc** otherwise opens the pause menu.

## 10. HUD (hearts + credits)

The HUD is `scenes/hud.tscn` (instanced once per room, top-left corner):

| Node | Placeholder today | Swap idea |
|---|---|---|
| `Row/HeartsFull` | `♥♥♥♥♥` — red `#ED2929`, size 24, black outline 4 | custom heart sprite/font |
| `Row/HeartsEmpty` | `♡♡♡♡♡` — gray `#6B6B6B`, same size/outline | dim/empty variant |
| `Row/Credits` | number in gold `#F9C940`, size 24 | your currency icon + counter |
| `Row/Gap` | invisible spacer (8 px) — layout only, don't remove | — |

Notes:

- Hearts are **two stacked labels** (full under empty); `hud.gd` reveals them by
  `visible_ratio`, so keep both labels and their order — style them freely.
- The heart glyphs currently come from the engine's fallback font. If you swap in a
  custom font, make sure it includes `U+2665` (♥) and `U+2661` (♡), or replace the
  labels with textures and keep `hud.gd`'s node names.
- **Do not change node names** (`HeartsFull`, `HeartsEmpty`, `Credits`) — `hud.gd`
  finds them by path.
- The HUD lives on CanvasLayer **layer 1** (above the world, below dialogue panel).
- Safe zone: keep it in the top-left ~320 × 40 px box at the default 1152×648
  (see section 7).
