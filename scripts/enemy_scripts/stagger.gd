extends EnemyState

@export var stagger_time := 0.25
@export var knockback := Vector2(300.0, -150.0)
var timer := 0.0

func enter(_previous: StringName) -> void:
	enemy.play(&"hurt")
	enemy.attack_hitbox.monitoring = false
	timer = stagger_time
	enemy.velocity = Vector2(enemy.knockback_dir * knockback.x, knockback.y)

func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, enemy.friction * delta)
	enemy.move_and_slide()

	timer -= delta
	if timer <= 0.0:
		machine.change_state(&"Chase")
