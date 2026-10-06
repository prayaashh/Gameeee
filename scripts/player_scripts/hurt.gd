extends PlayerState

@export var hurt_time := 0.3
@export var knockback := Vector2(300.0, -250.0)
var time_left := 0.0

func enter(_previous: StringName) -> void:
	player.play(&"idle")        # swap for a hurt animation later
	time_left = hurt_time
	player.velocity = Vector2(player.hurt_dir * knockback.x, knockback.y)

func physics_update(delta: float) -> void:
	time_left -= delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 1200.0 * delta)
	player.move_and_slide()
	if time_left <= 0.0:
		machine.change_state(&"Idle" if player.is_on_floor() else &"Fall")
