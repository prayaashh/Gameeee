class_name Room
extends Node2D

## Attached to every room's root node. Configures the player's camera (the
## Camera2D lives inside player.tscn). Leave everything at its default and the
## camera simply follows the player everywhere — including past the room's
## edges.

@export_group("Camera")

## World-space height the camera should show. When > 0 the room sets the
## camera's zoom so its vertical view equals this many world pixels — set it to
## a background's height so that background fills the screen top to bottom.
## 0 = leave the camera's zoom untouched.
@export var camera_fit_height := 0.0

## Camera limits in world coordinates — the same four values a Camera2D has.
## The camera's view is kept inside them and stops at each edge. The defaults
## are the "no limit" values, so only change the edges you want.
@export var left_limit := -10000000
@export var top_limit := -10000000
@export var right_limit := 10000000
@export var bottom_limit := 10000000

var _camera: Camera2D

func _ready() -> void:
	var player := get_node_or_null("player")
	if player == null:
		push_warning("Room has no child named 'player': " + scene_file_path)
		return
	_camera = player.get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		push_warning("The player scene has no Camera2D child — camera settings not applied.")
		return
	_apply_camera()
	# Keep the fit correct if the window (and so the viewport) is resized.
	get_viewport().size_changed.connect(_apply_camera)

func _apply_camera() -> void:
	if not is_instance_valid(_camera):
		return
	if camera_fit_height > 0.0:
		# Uniform zoom: view height = viewport height / zoom, so zoom = vh / fit.
		var view_h := _camera.get_viewport_rect().size.y
		var z := view_h / camera_fit_height
		_camera.zoom = Vector2(z, z)
	_camera.limit_left = left_limit
	_camera.limit_top = top_limit
	_camera.limit_right = right_limit
	_camera.limit_bottom = bottom_limit
