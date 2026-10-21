class_name NPC
extends Node2D

## Fires at the end of every conversation with this NPC.
## outcome: &"completed" &"accepted" &"declined" &"repeat" &"react" &"ended" &"cancelled"
signal interaction_finished(outcome: StringName)

## Valid keys of `stage_animations` (see its description below).
const _VALID_STAGES: Array[String] = ["talking", "choice", "accepted", "declined", "repeat", "completed", "react"]
## Valid values of `pickup_after` - the same list as the signal's outcomes.
const _VALID_OUTCOMES: Array[String] = ["completed", "accepted", "declined", "repeat", "react", "ended", "cancelled"]

@export var npc_name := "Villager"
@export var dialogue: Array[String] = ["Hello, traveller."]
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

@export_group("Animations by stage")
## Swap this NPC's animation as the conversation advances. Add one row per
## stage you care about (the "+" button; remove rows with the trash icon):
##   key   - the stage, typed exactly as listed below
##   value - animation NAME from this NPC's SpriteFrames
## Stages with no row keep whatever is playing, so only add what you need.
## Mistyped stages or missing animations print a warning when the game starts.
## Valid stages:
##   talking   - while the normal dialogue lines are shown
##   choice    - while the accept/decline question is open
##   accepted  - while accept_lines are shown
##   declined  - while decline_lines are shown
##   repeat    - while repeat_lines are shown (quest accepted, not done yet)
##   completed - while complete_lines are shown
##   react     - while react_lines are shown
## When the dialogue closes, the NPC returns to the default animation
## (unless the sword pickup below already happened).
@export var stage_animations: Dictionary[String, StringName] = {}

@export_group("Interaction")
## Size of the zone in which the "talk" prompt appears.
@export var interact_size := Vector2(160.5, 64.5)
## Offset of that zone from the NPC's origin.
@export var interact_offset := Vector2(3, -5)
## Text shown on the talk prompt.
@export var prompt_text := "E"

@export_group("Choice (optional)")
@export var question := ""                       # leave empty for no choice
@export var options: Array[String] = ["Accept", "Decline"]
@export var accept_lines: Array[String] = []
@export var decline_lines: Array[String] = []
@export var decline_again_lines: Array[String] = []  # said when you talk again after declining, then the question repeats
@export var flag_name := ""                      # set when you accept, e.g. "lantern_quest"
@export var repeat_lines: Array[String] = []     # said when you talk to them again after accepting

@export_group("Quest completion (optional)")
@export var complete_flag := ""                  # set by the quest when it is finished; MUST differ from flag_name, e.g. "lantern_quest_done"
@export var complete_lines: Array[String] = []   # said once complete_flag is set, instead of repeat_lines

@export_group("Reaction to another NPC's quest (optional)")
@export var react_flag := ""                     # e.g. "lantern_quest"
@export var react_lines: Array[String] = []

@export_group("Sword pickup (optional)")
## The sword lives in THIS NPC's frames: the stage animation for this outcome
## shows them holding it. When a conversation ends with this outcome (same
## values as the signal above, e.g. "completed"), the player takes it:
## `pickup_flag` is saved, `grants_weapon` goes to GameState.weapons and the
## NPC switches to `pickup_animation` - permanently, across scene changes.
## Leave empty to disable. Call take_sword() yourself for another trigger.
@export var pickup_after := ""
## Save flag written on pickup - THIS is what makes it stick forever.
@export var pickup_flag := "sword_taken"
## Animation WITHOUT the sword; what the NPC shows from the pickup onwards.
@export var pickup_animation := ""
## Weapon recorded in GameState.weapons (for the future HUD inventory),
## e.g. "sword". Leave empty to only change the NPC's look.
@export var grants_weapon := ""

@onready var prompt: Label = $Prompt
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var zone_shape: CollisionShape2D = $InteractZone/CollisionShape2D
var player: Player = null
var blink_tween: Tween

# used only when flag_name is left empty; the state then resets when the scene reloads
var _accepted := false
var _declined := false

func _ready() -> void:
	if sprite:
		if sprite_frames:
			sprite.sprite_frames = sprite_frames
		elif texture:
			# static NPC: wrap the single texture into a one-frame SpriteFrames
			var sf := SpriteFrames.new()
			sf.add_animation("static")
			sf.set_animation_loop("static", false)
			sf.set_animation_speed("static", 1.0)
			sf.add_frame("static", texture)
			sprite.sprite_frames = sf
		sprite.flip_h = flip_h
		# a sword taken in an earlier visit to this room wins forever
		if _sword_taken() and pickup_animation != "":
			_play_if_exists(pickup_animation)
		else:
			_play_default_animation()
	_check_animation_setup()
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

func _on_enter(body: Node2D) -> void:
	if body is Player:
		player = body
		prompt.show()

func _on_exit(body: Node2D) -> void:
	if body == player:
		player = null
		prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.dead or Dialogue.active or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_talk()

func _talk() -> void:
	prompt.hide()
	player.machine.change_state(&"Talk")
	var outcome := &"ended"

	if react_flag != "" and GameState.has_flag(react_flag) and not react_lines.is_empty():
		_play_stage("react")
		await Dialogue.say(npc_name, react_lines)
		outcome = &"react"
	elif _quest_accepted():
		# already accepted: completion lines once the quest is done, in-progress lines otherwise
		if _quest_complete() and not complete_lines.is_empty():
			_play_stage("completed")
			await Dialogue.say(npc_name, complete_lines)
			outcome = &"completed"
		elif not repeat_lines.is_empty():
			_play_stage("repeat")
			await Dialogue.say(npc_name, repeat_lines)
			outcome = &"repeat"
	else:
		_play_stage("talking")
		var finished := await Dialogue.say(npc_name, _intro_lines())
		if not finished:
			outcome = &"cancelled"          # player pressed esc mid-conversation
		elif question != "":
			_play_stage("choice")
			var pick := await Dialogue.choose(npc_name, question, options)
			if pick == 0:
				_accepted = true
				if flag_name != "":
					GameState.set_flag(flag_name)
				_play_stage("accepted")
				await Dialogue.say(npc_name, accept_lines)
				outcome = &"accepted"
			elif pick == 1:
				_declined = true
				if flag_name != "":
					GameState.set_flag(flag_name + "_declined")
				_play_stage("declined")
				await Dialogue.say(npc_name, decline_lines)
				outcome = &"declined"
			else:
				outcome = &"cancelled"      # player pressed esc at the question

	Dialogue.close()
	prompt.visible = player != null
	if pickup_after != "" and outcome == StringName(pickup_after):
		take_sword()   # before the hook below, so scene changes in it can't skip it
	# back to the resting pose, or to the permanent post-pickup pose
	if _sword_taken() and pickup_animation != "":
		_play_if_exists(pickup_animation)
	else:
		_play_default_animation()
	after_interaction(outcome)   # last line on purpose: your code may change scene, free nodes, etc.

## ------------------------------------------------------------------
## AFTER-TALK EVENT HOOK - this is the function you edit.
##
## Runs every time a conversation with this NPC ends. `outcome` says how it ended:
##   &"completed"  - quest-complete lines were shown. FIRES ONLY ONCE EVER
##                   (the save flag "<complete_flag>_event" is set automatically),
##                   so it is safe to put non-repeatable events here.
##   &"accepted"   - the player just accepted the quest (once per accept)
##   &"declined"   - the player just declined (can happen again if they re-refuse)
##   &"repeat"     - in-progress chatter (repeat_lines) - fires every talk
##   &"react"      - react_lines were shown (fires every talk)
##   &"ended"      - plain conversation, no question was asked
##   &"cancelled"  - player pressed esc mid-conversation
##
## Examples:
##   if outcome == &"completed":
##       GameState.add_credits(100)
##   if outcome == &"completed":
##       GameState.set_flag("gate_open")
##   if outcome == &"accepted":
##       get_tree().call_group("doors", "open")
##
## NOTE: don't open a new Dialogue from here (the conversation just closed);
## do game-state work instead: credits, flags, spawning, doors, camera, etc.
## There is also the `interaction_finished(outcome)` signal at the top of this
## file if you'd rather connect it to another node in the Inspector.
## NOTE: if `pickup_after` matched the outcome, take_sword() already ran
## BEFORE this hook - the flag and weapon are in GameState when you get here.
## ------------------------------------------------------------------
func after_interaction(outcome: StringName) -> void:
	if outcome == &"completed":
		if GameState.has_flag(complete_flag + "_event"):
			return    # this NPC's completion event already fired in an earlier conversation
		GameState.set_flag(complete_flag + "_event")
	interaction_finished.emit(outcome)
	# --- put your own code below this line, guided by `outcome` ---

## ------------------------------------------------------------------
## SWORD PICKUP
## Called automatically when a conversation ends with `pickup_after`.
## You can also call take_sword() from after_interaction() yourself for a
## different trigger (a button, a zone, another NPC's event, ...).
func take_sword() -> void:
	if pickup_flag != "":
		GameState.set_flag(pickup_flag)          # saved to disk -> permanent
	if grants_weapon != "":
		GameState.grant_weapon(grants_weapon)    # lives in GameState.weapons
	if pickup_animation != "":
		_play_if_exists(pickup_animation)        # switch right now, on screen

## True once the pickup happened - in this session or in an earlier save.
func _sword_taken() -> bool:
	return pickup_flag != "" and GameState.has_flag(pickup_flag)

# first lines of a conversation: the follow-up set after a decline, the normal set otherwise
func _intro_lines() -> Array[String]:
	if _has_declined() and not decline_again_lines.is_empty():
		return decline_again_lines
	return dialogue

func _quest_accepted() -> bool:
	return _accepted or (flag_name != "" and GameState.has_flag(flag_name))

func _has_declined() -> bool:
	return _declined or (flag_name != "" and GameState.has_flag(flag_name + "_declined"))

func _quest_complete() -> bool:
	return complete_flag != "" and GameState.has_flag(complete_flag)

# --- animations ---------------------------------------------------------------

## Starts the animation configured for a conversation stage. Stages without a
## row in `stage_animations` keep the current pose; after the sword pickup no
## stage can change the pose anymore.
func _play_stage(stage: String) -> void:
	if _sword_taken():
		return
	var anim: Variant = stage_animations.get(stage)
	if anim != null:
		_play_if_exists(StringName(anim))

func _play_if_exists(anim: StringName) -> void:
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

## Catches Inspector typos when the NPC spawns: unknown stage names, outcomes
## that don't exist and animations missing from the SpriteFrames.
func _check_animation_setup() -> void:
	if sprite == null and (not stage_animations.is_empty() or pickup_animation != ""):
		push_warning("NPC \"%s\": animations are configured but there is no AnimatedSprite2D child." % npc_name)
	for stage in stage_animations:
		if not _VALID_STAGES.has(stage):
			push_warning("NPC \"%s\": stage_animations has an unknown stage \"%s\" (valid ones: %s)." % [npc_name, stage, str(_VALID_STAGES)])
		else:
			_warn_missing_animation(stage_animations[stage], "stage \"%s\"" % stage)
	_warn_missing_animation(pickup_animation, "pickup_animation")
	if pickup_after != "" and not _VALID_OUTCOMES.has(pickup_after):
		push_warning("NPC \"%s\": pickup_after is \"%s\", which is no outcome (valid ones: %s)." % [npc_name, pickup_after, str(_VALID_OUTCOMES)])

func _warn_missing_animation(anim: StringName, where: String) -> void:
	if anim == &"" or sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		push_warning("NPC \"%s\": %s wants animation \"%s\", which is missing from the SpriteFrames." % [npc_name, where, anim])
