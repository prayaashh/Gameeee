extends Control

## Title screen — the project's main scene (Project Settings > run/main_scene).
##
## "Start" plays the intro scene (First Scene) and then the first room.
## When a save with a checkpoint exists the button reads "Continue" and resumes
## at that bench instead. "New Game" erases that save after a confirmation and
## restarts in the black room (the intro).

const FIRST_ROOM := "res://scenes/rooms/overworld castle 1/castle_1_room_1.tscn"
## "New Game" always replays the intro room, whatever First Scene is set to.
const NEW_GAME_SCENE := "res://scenes/rooms/black screens/black_room.tscn"

## Optional scene shown before the first room, e.g. the black text room.
## Leave empty to go straight into FIRST_ROOM.
@export_file("*.tscn") var first_scene := "res://scenes/rooms/black screens/black_room.tscn"

@onready var play_button: Button = $Center/Panel/VBox/PlayButton
@onready var new_game_confirm: ConfirmationDialog = $NewGameConfirm


func _ready() -> void:
	play_button.text = "Continue" if GameState.has_checkpoint() else "Start"
	play_button.grab_focus.call_deferred()


func _on_play_pressed() -> void:
	if GameState.has_checkpoint():
		GameState.respawn()          # back to the saved bench (or the first room)
		return
	# Only play intro if there is no previous save available
	if FileAccess.file_exists(GameState.SAVE_PATH):
		GameState.go_to_room(FIRST_ROOM, "Spawn")
		return
	GameState.go_to_room(_play_target(), "Spawn")


## Scene the Start button goes to: the intro when one is set, else the first room.
func _play_target() -> String:
	var target := first_scene.strip_edges()
	if target != "" and ResourceLoader.exists(target):
		return target
	return FIRST_ROOM


## Erasing progress cannot be undone, so New Game asks first.
func _on_new_game_pressed() -> void:
	new_game_confirm.popup_centered()


## Wipes the save (on disk too), then opens the black room intro, which walks on
## to the first room by itself.
func _on_new_game_confirmed() -> void:
	GameState.reset_progress()
	if ResourceLoader.exists(NEW_GAME_SCENE):
		GameState.go_to_room(NEW_GAME_SCENE, "Spawn")
	else:
		_on_play_pressed()          # intro missing: fall back to the normal start


func _on_quit_pressed() -> void:
	GameState.save_to_disk()         # same as quitting from the pause menu
	get_tree().quit()
