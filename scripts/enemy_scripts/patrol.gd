extends EnemyState

func enter(_previous: StringName) -> void:
	enemy.play(&"walk")

func physics_update(delta: float) -> void:
	if enemy.at_edge_or_wall():
		enemy.face(-enemy.facing)

	enemy.velocity.x = enemy.facing * enemy.patrol_speed
	enemy.apply_gravity(delta)
	enemy.move_and_slide()

	if enemy.can_see_player():
		machine.change_state(&"Chase")
