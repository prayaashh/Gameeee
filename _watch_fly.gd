extends Node

var fly: Node = null
var was_waiting := false
var stops := 0
var elapsed := 0.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	if fly == null or not is_instance_valid(fly):
		var scene := get_tree().current_scene
		if scene == null:
			return
		fly = scene.get_node_or_null("Creeps/Creepfly")
		if fly == null:
			return
		print("WATCH found fly, wait_mode=", fly.wait_mode,
				" stops=", fly._stop_offsets, " total=", fly._path_length())
	if fly.wait_left > 0.0 and not was_waiting:
		stops += 1
		print("FLOW STOP #", stops, " t=", snappedf(elapsed, 0.01),
				" pos=", fly.global_position, " progress=", snappedf(fly.progress, 0.1))
	was_waiting = fly.wait_left > 0.0
	if stops >= 6:
		print("FLOW OK: stopped at ", stops, " points")
		get_tree().quit()
