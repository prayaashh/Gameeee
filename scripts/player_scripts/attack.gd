extends PlayerState

var time_left := 0.0
var already_hit: Array = []   # so one swing hits each enemy only once

func enter(_previous: StringName) -> void:
	player.play(player.attack_animation())
	time_left = player.attack_time
	player.velocity.x = 0.6 * player.velocity.x
	already_hit.clear()
	player.attack_hitbox.body_entered.connect(_on_hit)
	player.attack_hitbox.monitoring = true

func physics_update(delta: float) -> void:
	time_left -= delta
	player.apply_gravity(delta)
	player.move_and_slide()
#	print("monitoring: ", player.attack_hitbox.monitoring,
#	" | mask: ", player.attack_hitbox.collision_mask,
#	" | overlaps: ", player.attack_hitbox.get_overlapping_bodies().size())
	if player.wants_jump():
		machine.change_state(&"Jump")
		return
	if time_left <= 0.0:
		machine.change_state(&"Idle" if player.is_on_floor() else &"Fall")

func exit() -> void:
	player.attack_hitbox.monitoring = false
	player.attack_hitbox.body_entered.disconnect(_on_hit)
#	print("monitoring: ", player.attack_hitbox.monitoring,
#	" | mask: ", player.attack_hitbox.collision_mask,
#	" | overlaps: ", player.attack_hitbox.get_overlapping_bodies().size())

func _on_hit(body: Node2D) -> void:
	if body in already_hit:
		return
	already_hit.append(body)
	if body.has_method("take_damage"):
		body.take_damage(player.current_damage(), player.global_position)
		player.gain_mana(player.mana_per_hit)   # landing a hit builds mana, like soul
