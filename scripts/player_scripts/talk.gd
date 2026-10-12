extends PlayerState

func enter(_previous: StringName) -> void:
	player.velocity.x = 0.0
	player.play(&"idle")
	Dialogue.closed.connect(_on_closed, CONNECT_ONE_SHOT)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()

func _on_closed() -> void:
	# short pause so the key press that closed the dialogue doesn't trigger a sword swing
	await get_tree().create_timer(0.1).timeout
	if not is_inside_tree():
		return
	machine.change_state(&"Idle")

func exit() -> void:
	if Dialogue.closed.is_connected(_on_closed):
		Dialogue.closed.disconnect(_on_closed)
