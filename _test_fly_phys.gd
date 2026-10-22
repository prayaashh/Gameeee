extends Node

func _ready() -> void:
	var room: Node = (load("res://scenes/rooms/cave/cave_room_1.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame

	var fly: Node = room.get_node("Creeps/Creepfly")
	fly.speed = 600.0              # shorten the test; stop logic is unchanged
	fly.wait_time_min = 0.2
	fly.wait_time_max = 0.2
	fly._start_wait_if_on_point()  # the speed/waits changed, refresh first stop
	var was_waiting: bool = fly.wait_left > 0.0
	var stops := 0
	var elapsed := 0.0
	for i in 600:                  # 10 s real time
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if fly.wait_left > 0.0 and not was_waiting:
			stops += 1
			print("PHYS STOP #", stops, " t=", snappedf(elapsed, 0.01),
					" pos=", fly.global_position, " progress=", snappedf(fly.progress, 0.1))
		was_waiting = fly.wait_left > 0.0
	print("PHYS TOTAL STOPS=", stops, " progress=", snappedf(fly.progress, 0.1))
	get_tree().quit()
