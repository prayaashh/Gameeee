extends Node

## Save / checkpoint / credits authority for the whole game.
##
## The save file (user://save.json) is written when:
##  - the player rests at a checkpoint (bench),
##  - the player quits from the pause menu,
##  - the window is force-closed (X button / Alt+F4).
## Death never writes the file; quitting never zeroes credits.

signal credits_changed(new_total: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const MAIN_SCENE := "res://scenes/rooms/game.tscn"
const TRANSITION_TIME := 0.35   # seconds doorways/spawns stay locked after a scene change

var flags := {}
var credits := 0
## Weapons the player owns (e.g. ["sword"]) - saved with the game.
## The future HUD inventory will read this list.
var weapons: Array[String] = []
## Current mana (soul). Kept here because the player node is rebuilt on every
## room change; like pending_spawn it lives in memory only (not saved to disk).
var mana := 0
var checkpoint := {}            # {id, scene, x, y} — {} means no checkpoint yet
var death_spot := {}            # {scene, x, y, amount} — where credits were last lost

## Spawn request waiting for the next player to read it: {"scene", "x", "y"} or
## {"scene", "entrance"}. Never written to disk; consumed in player._ready.
var pending_spawn := {}

var _transition_until_ms := 0

func _ready() -> void:
	if load_from_disk() and has_checkpoint():
		# Boot at the saved checkpoint, even if it lives in another room.
		pending_spawn = {
			"scene": str(checkpoint.get("scene", MAIN_SCENE)),
			"x": float(checkpoint.get("x", 0.0)),
			"y": float(checkpoint.get("y", 0.0)),
		}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_to_disk()            # force-shut (X / Alt+F4) saves like a normal quit
		get_tree().quit()

# --- flags -------------------------------------------------------------------

func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value

func has_flag(key: String) -> bool:
	return flags.get(key, false)

# --- weapons -----------------------------------------------------------------

## Gives the player a weapon (e.g. "sword"). Repeating the same name is a no-op.
func grant_weapon(weapon: String) -> void:
	if weapon != "" and not weapons.has(weapon):
		weapons.append(weapon)

func has_weapon(weapon: String) -> bool:
	return weapons.has(weapon)

# --- credits -----------------------------------------------------------------

func add_credits(amount: int) -> void:
	credits = maxi(credits + amount, 0)
	credits_changed.emit(credits)

func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true

## Called on death: everything carried drops where you fell. Nothing is saved here.
func lose_all_credits(death_position: Vector2) -> void:
	if credits > 0:
		death_spot = {
			"scene": _current_scene_path(),
			"x": death_position.x,
			"y": death_position.y,
			"amount": credits,
		}
	else:
		death_spot = {}          # dying again with nothing replaces the old drop
	credits = 0
	credits_changed.emit(0)

## Hook for the future recovery item: pick up the dropped credits, clear the spot.
func recover_death_spot() -> int:
	if death_spot.is_empty():
		return 0
	var amount := int(death_spot.get("amount", 0))
	death_spot = {}
	credits += amount
	credits_changed.emit(credits)
	return amount

# --- checkpoints -------------------------------------------------------------

func set_checkpoint(id: String, position: Vector2, scene_path: String) -> void:
	checkpoint = {"id": id, "scene": scene_path, "x": position.x, "y": position.y}

func has_checkpoint() -> bool:
	return not checkpoint.is_empty() and str(checkpoint.get("scene", "")) != ""

# --- scene changes -----------------------------------------------------------

## Death and the pause-menu Restart both land here. Writes nothing to disk.
func respawn() -> void:
	var target := MAIN_SCENE
	pending_spawn = {}
	if has_checkpoint():
		var scene := str(checkpoint.get("scene", ""))
		if ResourceLoader.exists(scene):
			target = scene
			pending_spawn = {
				"scene": scene,
				"x": float(checkpoint.get("x", 0.0)),
				"y": float(checkpoint.get("y", 0.0)),
			}
		else:
			push_warning("Checkpoint scene is missing: " + scene)
	start_transition()
	call_deferred("_change_scene", target)

## Doorways call go_to_room() from a physics callback (body_entered), where
## removing the scene immediately is not allowed - hence the defer.
func _change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

## Doorways: jump to another room and spawn at one of its entrance markers.
func go_to_room(scene_path: String, entrance: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("Doorway leads to a missing scene: " + scene_path)
		return
	pending_spawn = {"scene": scene_path, "entrance": entrance}
	start_transition()
	call_deferred("_change_scene", scene_path)

func start_transition() -> void:
	_transition_until_ms = Time.get_ticks_msec() + int(TRANSITION_TIME * 1000.0)

func in_transition() -> bool:
	return Time.get_ticks_msec() < _transition_until_ms

# --- save file ---------------------------------------------------------------

func save_to_disk() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"checkpoint": checkpoint,
		"credits": credits,
		"death_spot": death_spot,
		"flags": flags,
		"weapons": weapons,
	}, "\t"))
	return true

## Returns true when a save file was found and parsed. A corrupt file is
## ignored (with a warning) so the game can always start fresh.
func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is unreadable — starting fresh.")
		return false
	checkpoint = parsed.get("checkpoint", {})
	if typeof(checkpoint) != TYPE_DICTIONARY:
		checkpoint = {}
	credits = int(parsed.get("credits", 0))
	death_spot = parsed.get("death_spot", {})
	if typeof(death_spot) != TYPE_DICTIONARY:
		death_spot = {}
	var loaded_flags: Variant = parsed.get("flags", {})
	if typeof(loaded_flags) == TYPE_DICTIONARY:
		flags = loaded_flags
	var loaded_weapons: Variant = parsed.get("weapons", [])   # old saves have none
	weapons = []
	if typeof(loaded_weapons) == TYPE_ARRAY:
		for weapon in loaded_weapons:
			weapons.append(str(weapon))
	return true

func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""
