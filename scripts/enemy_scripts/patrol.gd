extends EnemyState

func enter(_previous: StringName) -> void:
	enemy.play(&"walk")

func physics_update(delta: float) -> void:
	if enemy.at_edge_or_wall():
		enemy.face(-enemy.facing)

	enemy.velocity.x = enemy.facing * enemy.patrol_speed
	enemy.apply_gravity(delta)
	enemy.move_and_slide()

	# chase_block_time keeps us from immediately re-engaging a player we just
	# gave up on (e.g. standing on a ledge we can't reach)
	if enemy.chase_block_time <= 0.0 and enemy.can_see_player():
		machine.change_state(&"Chase")
