extends PlayerState

var time_left := 0.0

func enter(_previous: StringName) -> void:
	player.play(&"attack")
	time_left = player.attack_time
	player.velocity.x = 0.0
	player.attack_hitbox.monitoring = true

func physics_update(delta: float) -> void:
	time_left -= delta
	player.apply_gravity(delta)
	player.move_and_slide()
	if time_left <= 0.0:
		machine.change_state(&"Idle" if player.is_on_floor() else &"Fall")

func exit() -> void:
	player.attack_hitbox.monitoring = false
