extends Node

func _ready() -> void:
	var room: Node = (load("res://scenes/rooms/cave/cave_room_1.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame

	var fly: Node = room.get_node("Creeps/Creepfly")
	print("WAIT_MODE=", fly.wait_mode, " PATH=", fly.path)
	print("STOPS=", fly._stop_offsets)
	print("TOTAL=", fly._path_length(), " PROGRESS=", fly.progress)

	fly.set_physics_process(false)
	var was_waiting := false
	var stops := 0
	var travel := 0.0
	for i in 12000:                      # 0.016 s * 12000 = 192 s of flight
		fly._follow_path(0.016)
		travel += 0.016
		if fly.wait_left > 0.0 and not was_waiting:
			stops += 1
			print("STOP #", stops, " t=", snappedf(travel, 0.01),
					" progress=", snappedf(fly.progress, 0.1))
		was_waiting = fly.wait_left > 0.0
	print("TOTAL STOPS=", stops, " final_progress=", fly.progress)
	get_tree().quit()
