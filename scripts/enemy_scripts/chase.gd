extends EnemyState

@export var give_up_time := 2.0
var lost_timer := 0.0

func enter(_previous: StringName) -> void:
	enemy.play(&"run")
	lost_timer = give_up_time

func physics_update(delta: float) -> void:
	var seen: bool = enemy.can_see_player(true)
	var target_x: float = enemy.player.global_position.x if seen else enemy.last_seen_position.x
	var dx := target_x - enemy.global_position.x
	var dir := signf(dx)
	enemy.face(dir)

	var arrived := absf(dx) < 10.0
	enemy.velocity.x = 0.0 if (arrived or enemy.at_edge_or_wall()) else dir * enemy.chase_speed
	enemy.apply_gravity(delta)
	enemy.move_and_slide()

	if seen:
		lost_timer = give_up_time
	else:
		lost_timer -= delta

	if lost_timer <= 0.0:
		machine.change_state(&"Patrol")
	elif seen and enemy.distance_to_player() <= enemy.attack_range \
			and enemy.attack_cooldown_left <= 0.0:
		machine.change_state(&"Attack")
