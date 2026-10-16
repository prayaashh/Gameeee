extends SceneTree

var scene
var player
var cam
var steps := 0

func _initialize() -> void:
	scene = load("res://scenes/rooms/overworld castle 1/castle_1_room_1.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("player")
	cam = player.get_node("Camera2D")
	physics_frame.connect(_phys)

func _phys() -> void:
	steps += 1
	if steps < 150:
		return
	if steps > 200:
		quit()
		return
	print("p=", player.global_position, " v=", player.velocity, " floor=", player.is_on_floor(),
		" cam=", cam.get_screen_center_position(), " zoom=", cam.zoom)
