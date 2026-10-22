extends Node

func _ready() -> void:
	var room: Node = (load("res://scenes/rooms/cave/cave_room_1.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame
	var fly: Node = room.get_node("Creeps/Creepfly")

	# Simulate the state left by a script hot-reload: the old run never built stops.
	fly._stop_offsets.clear()
	fly._stops_ready = false
	fly._stops_signature = ""
	fly.wait_left = 0.0
	fly.progress = 0.0
	print("BEFORE stops=", fly._stop_offsets, " ready=", fly._stops_ready)

	fly.speed = 600.0
	fly.wait_time_min = 0.2
	fly.wait_time_max = 0.2
	var was_waiting := false
	var stops := 0
	for i in 300:
		await get_tree().physics_frame
		if stops == 0 and not fly._stop_offsets.is_empty():
			print("REBUILT stops=", fly._stop_offsets)
		if fly.wait_left > 0.0 and not was_waiting:
			stops += 1
			print("STOP #", stops, " pos=", fly.global_position)
		was_waiting = fly.wait_left > 0.0
	print("TOTAL STOPS=", stops)
	get_tree().quit()
