extends Control

## Title screen — the project's main scene (Project Settings > run/main_scene).
##
## "Start" plays the intro scene (First Scene) and then the first room.
## When a save with a checkpoint exists the button reads "Continue" and resumes
## at that bench instead. Nothing here writes to the save file.

const FIRST_ROOM := "res://scenes/rooms/game.tscn"

## Optional scene shown before the first room, e.g. the black text room.
## Leave empty to go straight into FIRST_ROOM.
@export_file("*.tscn") var first_scene := "res://scenes/rooms/black_room.tscn"

@onready var play_button: Button = $Center/Panel/VBox/PlayButton


func _ready() -> void:
	play_button.text = "Continue" if GameState.has_checkpoint() else "Start"
	play_button.grab_focus.call_deferred()


func _on_play_pressed() -> void:
	if GameState.has_checkpoint():
		GameState.respawn()          # back to the saved bench (or the first room)
		return
	GameState.go_to_room(_play_target(), "Spawn")


## Scene the Start button goes to: the intro when one is set, else the first room.
func _play_target() -> String:
	var target := first_scene.strip_edges()
	if target != "" and ResourceLoader.exists(target):
		return target
	return FIRST_ROOM


func _on_quit_pressed() -> void:
	GameState.save_to_disk()         # same as quitting from the pause menu
	get_tree().quit()
