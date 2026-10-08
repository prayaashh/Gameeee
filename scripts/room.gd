class_name Room
extends Node2D

## Attached to every room's root node. Applies camera_bounds to the player's
## camera (the Camera2D lives inside player.tscn) and warns about a missing
## player. Bounds are in world pixels and should cover the room with at least
## half a viewport of margin (window is 1152x648).

@export var camera_bounds := Rect2(-64, -360, 1568, 704)

func _ready() -> void:
	var player := get_node_or_null("player")
	if player == null:
		push_warning("Room has no child named 'player': " + scene_file_path)
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		push_warning("The player scene has no Camera2D child — camera bounds not applied.")
		return
	if camera_bounds.size.x <= 0 or camera_bounds.size.y <= 0:
		return   # left empty on purpose: keep default (unbounded) camera
	camera.limit_left = int(camera_bounds.position.x)
	camera.limit_top = int(camera_bounds.position.y)
	camera.limit_right = int(camera_bounds.end.x)
	camera.limit_bottom = int(camera_bounds.end.y)
