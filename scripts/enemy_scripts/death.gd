extends EnemyState

@export var death_time := 0.6

func enter(_previous: StringName) -> void:
	enemy.play(&"death")
	enemy.attack_hitbox.monitoring = false
	enemy.collision_layer = 0          # player attacks can no longer hit it
	enemy.velocity.x = 0.0
	enemy.handle_death()               # credits + drop + `died` signal + on_death() hook
	await get_tree().create_timer(death_time).timeout
	if not is_inside_tree():
		return
	enemy.queue_free()

func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_and_slide()
