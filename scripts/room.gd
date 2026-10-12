class_name Room
extends Node2D

## Attached to every room's root node. By default the player's camera (the
## Camera2D lives inside player.tscn) is left unbounded, so it simply follows
## the player everywhere — including past the room's edges.
##
## Leave `camera_bounds` at zero size for that behaviour (recommended). Set it
## to a non-empty rectangle in world pixels only if you want the camera clamped
## to the room's edges instead.

@export var camera_bounds := Rect2(0, 0, 0, 0)

func _ready() -> void:
	var player := get_node_or_null("player")
	if player == null:
		push_warning("Room has no child named 'player': " + scene_file_path)
		return
	if camera_bounds.size.x <= 0 or camera_bounds.size.y <= 0:
		return   # zero size = camera follows the player freely (recommended)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		push_warning("The player scene has no Camera2D child — camera bounds not applied.")
		return
	camera.limit_left = int(camera_bounds.position.x)
	camera.limit_top = int(camera_bounds.position.y)
	camera.limit_right = int(camera_bounds.end.x)
	camera.limit_bottom = int(camera_bounds.end.y)
