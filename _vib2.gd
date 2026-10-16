extends SceneTree

var scene
var player
var cam
var steps := 0
var started := false

func _initialize() -> void:
	scene = load("res://scenes/rooms/overworld castle 1/castle_1_room_1.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("player")
	cam = player.get_node("Camera2D")
	physics_frame.connect(_phys)

func _phys() -> void:
	steps += 1
	if steps == 120:
		Input.action_press("move_right")
		print("--- start walking ---")
		return
	if steps < 120 or steps > 145:
		if steps > 145:
			quit()
		return
	var vp := Vector2(1152, 648)
	var zoom: Vector2 = cam.zoom
	var center: Vector2 = cam.get_screen_center_position()
	var screen := (player.global_position - center) * zoom + vp / 2.0
	print("p=", player.global_position, " screen=", screen, " floor=", player.is_on_floor())
