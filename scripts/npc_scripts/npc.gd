class_name NPC
extends Node2D

## Fires at the end of every conversation with this NPC.
## outcome is the id of the last stage that ran ("0", "1", ...), or &"cancelled"
## if the player pressed Esc. Connect it in the Inspector, or override
## after_interaction() below.
signal interaction_finished(outcome: StringName)

const NPCDialogue = preload("res://scripts/npc_scripts/npc_dialogue.gd")

@export var npc_name := "Villager"
## Plain-text conversation file, written in Notepad and picked here.
## Leave empty for an NPC that only shows a prompt. Syntax: docs/NPC_DIALOGUE.md
@export_file("*.txt", "*.npc") var dialogue_file := ""
@export_range(0.1, 3.0, 0.05) var blink_speed := 0.5  # 1.0 = original 0.4s per phase; lower = slower

@export_group("Appearance")
## Drag a SpriteFrames resource here to give this NPC an animated look.
@export var sprite_frames: SpriteFrames
## Single-image look for static NPCs. Ignored when Sprite Frames is set.
@export var texture: Texture2D
## Which animation to play on spawn. Leave empty for the first one in the resource.
@export var default_animation := ""
## Mirror the sprite horizontally.
@export var flip_h := false

@export_group("Interaction")
## Size of the zone in which the "talk" prompt appears.
@export var interact_size := Vector2(160.5, 64.5)
## Offset of that zone from the NPC's origin.
@export var interact_offset := Vector2(3, -5)
## Text shown on the talk prompt.
@export var prompt_text := "E"

@export_group("Crumble")
## Conversation stage that crumbles this NPC for good, e.g. "6". When the
## conversation reaches it the NPC plays `crumble_animation` once, settles on
## `crumbled_animation`, remembers it in the save and can no longer be talked
## to - in this room and on every later visit. Leave empty to opt out.
@export var crumble_stage := ""
## One-shot animation played when the crumble stage is reached.
@export var crumble_animation := &"crumble"
## Animation shown after the crumble finishes. When the SpriteFrames has no
## such animation, the last frame of `crumble_animation` is held instead.
@export var crumbled_animation := &"crumbled"
## Save flag remembering the crumbled state. Empty = "npc_<name>_crumbled".
@export var crumble_flag := ""

@onready var prompt: Label = $Prompt
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var zone_shape: CollisionShape2D = $InteractZone/CollisionShape2D
var player: Player = null
var blink_tween: Tween

var _dialogue = null
var _crumbled := false

func _ready() -> void:
	if sprite:
		if sprite_frames:
			sprite.sprite_frames = sprite_frames
		elif texture:
			# static NPC: wrap the single texture into a one-frame SpriteFrames
			var frames := SpriteFrames.new()
			frames.add_animation("static")
			frames.set_animation_loop("static", false)
			frames.set_animation_speed("static", 1.0)
			frames.add_frame("static", texture)
			sprite.sprite_frames = frames
		sprite.flip_h = flip_h
		_play_default_animation()
	_load_dialogue()
	# duplicate so each instance can have its own zone size without affecting others
	zone_shape.shape = zone_shape.shape.duplicate()
	zone_shape.shape.size = interact_size
	zone_shape.position = interact_offset
	prompt.text = prompt_text
	prompt.hide()
	$InteractZone.body_entered.connect(_on_enter)
	$InteractZone.body_exited.connect(_on_exit)
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(prompt, "modulate:a", 0.0, 0.4 / blink_speed).from(1.0)
	blink_tween.tween_property(prompt, "modulate:a", 1.0, 0.4 / blink_speed)
	# A room remembers a crumbled NPC through its save flag: skip straight to
	# the crumbled pose instead of replaying the fall.
	if _has_crumble_flag():
		_restore_crumble()

func _load_dialogue() -> void:
	_dialogue = null
	if dialogue_file.is_empty():
		return
	var parsed = NPCDialogue.new()
	if not parsed.read_file(dialogue_file):
		push_warning("NPC \"%s\": could not load %s" % [npc_name, dialogue_file])
		return
	_dialogue = parsed
	_dialogue.validate(npc_name, sprite)

func _on_enter(body: Node2D) -> void:
	if _crumbled:
		return
	if body is Player:
		player = body
		prompt.show()

func _on_exit(body: Node2D) -> void:
	if body == player:
		player = null
		prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if _crumbled or player == null or player.dead or Dialogue.active or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_talk()

func _talk() -> void:
	if _crumbled:
		return
	if _dialogue == null:
		return          # no file set (or it failed to load - warned in _ready)
	prompt.hide()
	player.machine.change_state(&"Talk")

	var stage_id := _entry_stage_id()
	var last_stage := &""
	var cancelled := false
	var steps := 0

	while not stage_id.is_empty():
		steps += 1
		if steps > 128:
			push_warning("NPC \"%s\": conversation loops forever (check goto/choices in %s)" % [npc_name, dialogue_file])
			break
		var stage = _dialogue.stages.get(stage_id)
		if stage == null:
			push_warning("NPC \"%s\": no stage \"%s\" in %s" % [npc_name, stage_id, dialogue_file])
			break
		last_stage = StringName(stage.id)

		# The crumble stage ends this NPC's story: start the fall and remember
		# it, then let the stage's own commands (if any) run.
		if not crumble_stage.is_empty() and str(stage.id) == crumble_stage:
			_begin_crumble()

		var result: Dictionary = await _run_stage(stage)
		if bool(result.get("cancelled", false)):
			cancelled = true
			break
		stage_id = str(result.get("next", ""))

	Dialogue.close()
	prompt.visible = player != null and not _crumbled
	if not _crumbled:
		_play_default_animation()
	after_interaction(&"cancelled" if cancelled else last_stage)

## Runs one stage in the order it is written: animation, lines, question, flags.
## Returns {"cancelled": bool, "next": stage id or "" to end}.
func _run_stage(stage) -> Dictionary:
	if not stage.animation.is_empty():
		_play_if_exists(StringName(stage.animation))

	if not stage.lines.is_empty():
		if not await Dialogue.say(_speaker(), stage.lines):
			return {"cancelled": true, "next": ""}

	var next: String = stage.go_to
	if not stage.question.is_empty():
		if stage.choices.is_empty():
			# a question with no options is just another line
			if not await Dialogue.say(_speaker(), [stage.question]):
				return {"cancelled": true, "next": ""}
		else:
			var labels: Array = []
			for choice in stage.choices:
				labels.append(str(choice.get("label", "")))
			var picked: int = await Dialogue.choose(_speaker(), stage.question, labels)
			if picked < 0:
				return {"cancelled": true, "next": ""}
			next = str(stage.choices[picked].get("target", ""))

	for flag in stage.sets:
		GameState.set_flag(flag)
	for flag in stage.clears:
		GameState.set_flag(flag, false)
	for weapon in stage.gives:
		GameState.grant_weapon(weapon)

	return {"cancelled": false, "next": next}

## Picks the stage the conversation starts at. Entry rules are checked in the
## order they appear in the file; the first match wins. With no match (and no
## rules at all) it falls back to Stage 0.
func _entry_stage_id() -> String:
	if _dialogue == null:
		return ""
	for rule in _dialogue.entries:
		var kind := str(rule.get("kind", ""))
		var flag := str(rule.get("flag", ""))
		var matches := false
		match kind:
			"flag", "has":
				matches = GameState.has_flag(flag)
			"noflag", "not":
				matches = not GameState.has_flag(flag)
			"always", "else", "default":
				matches = true
		if matches:
			return str(rule.get("target", ""))
	if _dialogue.stages.has("0"):
		return "0"
	var ids: Array = _dialogue.stages.keys()
	return "" if ids.is_empty() else str(ids[0])

func _speaker() -> String:
	if _dialogue != null and not _dialogue.speaker.is_empty():
		return _dialogue.speaker
	return npc_name

## ------------------------------------------------------------------
## AFTER-TALK EVENT HOOK - edit this function for game-state work.
##
## Runs every time a conversation with this NPC ends. `outcome` is the id of the
## last stage that ran, or &"cancelled" if the player pressed Esc. The stage ids
## come from the dialogue file, so you can do things like:
##
##   if outcome == &"1":            # the "yes" stage
##       GameState.add_credits(100)
##   if outcome == &"4":            # the "quest done" stage
##       GameState.set_flag("gate_open")
##
## NOTE: don't open a new Dialogue from here (the conversation just closed);
## do game-state work instead: credits, flags, spawning, doors, camera, etc.
## There is also the `interaction_finished(outcome)` signal at the top of this
## file if you'd rather connect another node in the Inspector.
## ------------------------------------------------------------------
func after_interaction(outcome: StringName) -> void:
	interaction_finished.emit(outcome)
	# --- put your own code below this line, guided by `outcome` ---

# --- crumble ------------------------------------------------------------------

## True once this NPC has crumbled, either in this conversation or earlier.
func is_crumbled() -> bool:
	return _crumbled

## Save flag that remembers the crumble. Uses `crumble_flag` when set, else
## derives it from the NPC's name.
func _crumble_flag_name() -> String:
	if not crumble_flag.is_empty():
		return crumble_flag
	if npc_name.is_empty():
		return ""
	return "npc_%s_crumbled" % npc_name.to_lower().replace(" ", "_")

## True when a previous visit already crumbled this NPC (flag in the save).
func _has_crumble_flag() -> bool:
	if crumble_stage.is_empty():
		return false          # crumble behaviour not set up for this NPC
	var flag := _crumble_flag_name()
	return not flag.is_empty() and GameState.has_flag(flag)

## Reaching `crumble_stage` in the conversation: remember it, stop listening to
## the player and play the one-shot fall.
func _begin_crumble() -> void:
	if _crumbled:
		return
	_crumbled = true
	var flag := _crumble_flag_name()
	if not flag.is_empty():
		GameState.set_flag(flag)
	_disable_interaction()
	_play_crumble_sequence()

## Puts the NPC straight into the finished crumbled pose (room loaded after an
## earlier crumble). The fall is not replayed.
func _restore_crumble() -> void:
	_crumbled = true
	_disable_interaction()
	_play_crumbled_rest()

## Hides the talk prompt and switches the interaction zone off for good.
func _disable_interaction() -> void:
	player = null
	prompt.hide()
	if blink_tween:
		blink_tween.kill()
	var zone := get_node_or_null("InteractZone") as Area2D
	if zone:
		zone.set_deferred("monitoring", false)
		zone.set_deferred("monitorable", false)

func _play_crumble_sequence() -> void:
	if not _has_animation(crumble_animation):
		return
	sprite.play(crumble_animation)
	var duration := _animation_length(crumble_animation)
	if duration <= 0.0:
		_play_crumbled_rest()
		return
	# Wait exactly one playthrough, then settle on the permanent pose. A Tween
	# dies with the node, so leaving the room mid-fall is safe.
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_play_crumbled_rest)

func _play_crumbled_rest() -> void:
	if not _has_animation(crumble_animation) and not _has_animation(crumbled_animation):
		return
	var frames := sprite.sprite_frames
	if frames.has_animation(crumbled_animation) and frames.get_frame_count(crumbled_animation) > 0:
		sprite.play(crumbled_animation)
		return
	# No dedicated crumbled animation: freeze on the fall's last frame.
	sprite.play(crumble_animation)
	sprite.frame = frames.get_frame_count(crumble_animation) - 1
	sprite.pause()

func _has_animation(anim: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and anim != &"" and sprite.sprite_frames.has_animation(anim)

func _animation_length(anim: StringName) -> float:
	if not _has_animation(anim):
		return 0.0
	var frames := sprite.sprite_frames
	var speed := frames.get_animation_speed(anim)
	if speed <= 0.0:
		speed = 1.0
	var total := 0.0
	for index in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, index)
	return total / speed

# --- animations ---------------------------------------------------------------

func _play_if_exists(anim: StringName) -> void:
	if _crumbled and anim == crumble_animation:
		return          # the crumble sequence already owns the sprite
	if sprite == null or sprite.sprite_frames == null or anim == &"":
		return
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

## What the NPC shows while no conversation is running.
func _play_default_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var names := sprite.sprite_frames.get_animation_names()
	if names.is_empty():
		return
	sprite.play(default_animation if default_animation != "" and names.has(default_animation) else names[0])
