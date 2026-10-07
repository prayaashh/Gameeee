# dash.gd

extends PlayerState

var time_left := 0.0

func enter(_previous: StringName) -> void:
	player.play(&"dash")
	time_left = player.dash_time
	player.dash_cooldown_left = player.dash_cooldown
	if not player.is_on_floor():
		player.air_dash_used = true
	player.velocity = Vector2(player.facing * player.dash_speed, 0.0)  # no gravity while dashing

func physics_update(delta: float) -> void:
	time_left -= delta
	player.move_and_slide()
	if Input.is_action_just_pressed("attack"):
		machine.change_state(&"Attack")
	if time_left <= 0.0:
		machine.change_state(&"Idle" if player.is_on_floor() else &"Fall")

func exit() -> void:
	player.velocity.x = 0.0
