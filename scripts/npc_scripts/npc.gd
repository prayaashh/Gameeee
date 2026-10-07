class_name NPC
extends Node2D

@export var npc_name := "Villager"
@export var dialogue: Array[String] = ["Hello, traveller."]

@export_group("Choice (optional)")
@export var question := ""                       # leave empty for no choice
@export var options: Array[String] = ["Accept", "Decline"]
@export var accept_lines: Array[String] = []
@export var decline_lines: Array[String] = []
@export var flag_name := ""                      # set when you accept, e.g. "lantern_quest"
@export var repeat_lines: Array[String] = []     # said when you talk to them again after accepting

@export_group("Reaction to another NPC's quest (optional)")
@export var react_flag := ""                     # e.g. "lantern_quest"
@export var react_lines: Array[String] = []

@onready var prompt: Label = $Prompt
var player: Player = null

func _ready() -> void:
	prompt.hide()
	$InteractZone.body_entered.connect(_on_enter)
	$InteractZone.body_exited.connect(_on_exit)

func _on_enter(body: Node2D) -> void:
	if body is Player:
		player = body
		prompt.show()

func _on_exit(body: Node2D) -> void:
	if body == player:
		player = null
		prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player == null or Dialogue.active or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_talk()

func _talk() -> void:
	prompt.hide()
	player.machine.change_state(&"Talk")

	if react_flag != "" and GameState.has_flag(react_flag) and not react_lines.is_empty():
		await Dialogue.say(npc_name, react_lines)
	elif flag_name != "" and GameState.has_flag(flag_name) and not repeat_lines.is_empty():
		await Dialogue.say(npc_name, repeat_lines)
	elif await Dialogue.say(npc_name, dialogue) and question != "":
		var pick := await Dialogue.choose(npc_name, question, options)
		if pick == 0:
			if flag_name != "":
				GameState.set_flag(flag_name)
			await Dialogue.say(npc_name, accept_lines)
		elif pick == 1:
			await Dialogue.say(npc_name, decline_lines)

	Dialogue.close()
	prompt.visible = player != null
