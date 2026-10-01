extends PlayerState

@export_range(0.0, 1.0, 0.05) var release_cut := 0.4

func enter(_previous: StringName) -> void:
	player.play(&"jump")
	player.velocity.y = player.jump_velocity
	player.jump_buffer_left = 0.0

func physics_update(delta: float) -> void:
	if try_common_transitions():
		return

	if Input.is_action_just_released("jump") and player.velocity.y < 0.0:
		player.velocity.y *= release_cut

	player.move_horizontal(player.get_move_input())
	player.apply_gravity(delta)
	player.move_and_slide()

	if player.velocity.y >= 0.0:
		machine.change_state(&"Fall")
