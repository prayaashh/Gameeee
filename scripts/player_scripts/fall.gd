extends PlayerState

@export var coyote_time := 0.1
var coyote_left := 0.0

func enter(previous: StringName) -> void:
	player.play(&"fall")
	coyote_left = coyote_time if previous == &"Idle" or previous == &"Run" else 0.0

func physics_update(delta: float) -> void:
	coyote_left -= delta
	if coyote_left > 0.0 and player.wants_jump():
		machine.change_state(&"Jump")
		return
	if try_common_transitions():
		return

	var dir := player.get_move_input()
	player.move_horizontal(dir)
	player.apply_gravity(delta)
	player.move_and_slide()

	if player.is_on_floor():
		if player.wants_jump():
			machine.change_state(&"Jump")
		elif dir != 0.0:
			machine.change_state(&"Run")
		else:
			machine.change_state(&"Idle")
