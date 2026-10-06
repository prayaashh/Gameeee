extends EnemyState

@export var give_up_time := 2.0
@export var unreachable_time := 1.5     # how long we keep trying before breaking off
@export var re_chase_delay := 1.0       # pause before patrol is allowed to spot the player again

var lost_timer := 0.0
var stuck_timer := 0.0

func enter(_previous: StringName) -> void:
	enemy.play(&"run")
	lost_timer = give_up_time
	stuck_timer = 0.0

func physics_update(delta: float) -> void:
	var seen: bool = enemy.can_see_player(true)
	var target_x: float = enemy.player.global_position.x if seen else enemy.last_seen_position.x
	var dx := target_x - enemy.global_position.x
	var dir := signf(dx)
	enemy.face(dir)

	# stop inside striking distance instead of walking into the player and freezing
	var arrived := absf(dx) <= enemy.attack_range
	enemy.velocity.x = 0.0 if (arrived or enemy.at_edge_or_wall()) else dir * enemy.chase_speed
	enemy.apply_gravity(delta)
	enemy.move_and_slide()

	if seen:
		lost_timer = give_up_time
	else:
		lost_timer -= delta

	# in reach horizontally but the hitbox can't connect (player on a ledge above/below),
	# or wedged against a wall/edge on the way over -> start the give-up timer
	var in_reach: bool = enemy.horizontal_gap_to_player() <= enemy.attack_range \
			and enemy.vertical_gap_to_player() <= enemy.attack_height
	var wedged: bool = enemy.at_edge_or_wall() and not arrived
	if seen and not in_reach and (arrived or wedged):
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	if stuck_timer >= unreachable_time:
		enemy.chase_block_time = re_chase_delay
		machine.change_state(&"Patrol")
	elif lost_timer <= 0.0:
		machine.change_state(&"Patrol")
	elif seen and in_reach and enemy.attack_cooldown_left <= 0.0:
		machine.change_state(&"Attack")
