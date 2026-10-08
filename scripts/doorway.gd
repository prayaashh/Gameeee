class_name Doorway
extends Area2D

## A one-way connection to another room. Set target_scene and the entrance
## (marker name under the target room's "Entrances" node) in the inspector.

@export_file("*.tscn") var target_scene := ""
@export var target_entrance := "Spawn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or player.dead:
		return
	if GameState.in_transition() or Dialogue.active:
		return
	if target_scene == "":
		push_warning("Doorway has no target scene set: " + name)
		return
	GameState.go_to_room(target_scene, target_entrance)
