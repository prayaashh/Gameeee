extends Node

func _ready() -> void:
	var room: Node = (load("res://scenes/rooms/cave/cave_room_1.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame
	var fly: Node = room.get_node("Creeps/Creepfly")

	var empty: Array[int] = []
	for mode in [0, 1, 2]:
		fly.wait_mode = mode
		fly.wait_points = empty
		fly._build_stop_offsets()
		print("MODE=", mode, " stops=", fly._stop_offsets, " ready=", fly._stops_ready)

	# live edit: the per-frame signature check must rebuild stops
	fly.wait_mode = 0
	fly._follow_path(0.016)
	print("LIVE EDIT rebuilt=", not fly._stop_offsets.is_empty())
	get_tree().quit()
