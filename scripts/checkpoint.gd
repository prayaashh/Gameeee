class_name Checkpoint
extends Node2D

## A bench. Resting here heals to full and writes the save file; the player
## respawns at the position they rested from. Blink speed works like the NPC's.

@export var checkpoint_id := "checkpoint_1"
@export var rest_line := "You rest a while. Your journey is saved."
@export var rest_speaker := "Rest"
@export_range(0.1, 3.0, 0.05) var blink_speed := 0.5  # 1.0 = original 0.4s per phase; lower = slower

@onready var prompt: Label = $Prompt

var player: Player = null
var blink_tween: Tween

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
	if player == null or player.dead or Dialogue.active or not player.is_on_floor() or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_rest()

func _rest() -> void:
	prompt.hide()
	player.heal_full()
	GameState.set_checkpoint(checkpoint_id, player.global_position, _scene_path())
	GameState.save_to_disk()
	if rest_line != "":
		player.machine.change_state(&"Talk")
		await Dialogue.say(rest_speaker, [rest_line])
		Dialogue.close()
	prompt.visible = player != null

func _scene_path() -> String:
	var room := owner if owner else get_tree().current_scene
	return room.scene_file_path if room else ""
