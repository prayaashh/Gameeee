extends PlayerState

func enter(_previous: StringName) -> void:
	player.play(&"run")

func physics_update(delta: float) -> void:
	var dir := player.get_move_input()
	player.move_horizontal(dir)
	player.apply_gravity(delta)
	player.move_and_slide()

	if not player.is_on_floor():
		machine.change_state(&"Fall")
	elif player.wants_jump():
		machine.change_state(&"Jump")
	elif try_common_transitions():
		return
	elif dir == 0.0:
		machine.change_state(&"Idle")
