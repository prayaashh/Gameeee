class_name NPC
extends Node2D

## Fires at the end of every conversation with this NPC.
## outcome: &"completed" &"accepted" &"declined" &"repeat" &"react" &"ended" &"cancelled"
signal interaction_finished(outcome: StringName)

@export var npc_name := "Villager"
@export var dialogue: Array[String] = ["Hello, traveller."]
@export_range(0.1, 3.0, 0.05) var blink_speed := 0.5  # 1.0 = original 0.4s per phase; lower = slower

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

@onready var prompt: Label = $Prompt
var player: Player = null
var blink_tween: Tween

# used only when flag_name is left empty; the state then resets when the scene reloads
var _accepted := false
var _declined := false

func _ready() -> void:
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
		await Dialogue.say(npc_name, react_lines)
		outcome = &"react"
	elif _quest_accepted():
		# already accepted: completion lines once the quest is done, in-progress lines otherwise
		if _quest_complete() and not complete_lines.is_empty():
			await Dialogue.say(npc_name, complete_lines)
			outcome = &"completed"
		elif not repeat_lines.is_empty():
			await Dialogue.say(npc_name, repeat_lines)
			outcome = &"repeat"
	else:
		var finished := await Dialogue.say(npc_name, _intro_lines())
		if not finished:
			outcome = &"cancelled"          # player pressed esc mid-conversation
		elif question != "":
			var pick := await Dialogue.choose(npc_name, question, options)
			if pick == 0:
				_accepted = true
				if flag_name != "":
					GameState.set_flag(flag_name)
				await Dialogue.say(npc_name, accept_lines)
				outcome = &"accepted"
			elif pick == 1:
				_declined = true
				if flag_name != "":
					GameState.set_flag(flag_name + "_declined")
				await Dialogue.say(npc_name, decline_lines)
				outcome = &"declined"
			else:
				outcome = &"cancelled"      # player pressed esc at the question

	Dialogue.close()
	prompt.visible = player != null
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
## ------------------------------------------------------------------
func after_interaction(outcome: StringName) -> void:
	if outcome == &"completed":
		if GameState.has_flag(complete_flag + "_event"):
			return    # this NPC's completion event already fired in an earlier conversation
		GameState.set_flag(complete_flag + "_event")
	interaction_finished.emit(outcome)
	# --- put your own code below this line, guided by `outcome` ---

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
