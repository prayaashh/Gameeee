extends PlayerState

## Hollow-Knight-style focus. Hold the "heal" action while standing on the
## ground to spend `player.heal_cost` mana and restore one heart.
##
## Getting hit, releasing the key, pressing a direction again or walking off a
## ledge cancels the channel. The mana is only spent when the heal actually
## completes, so a cancelled focus costs nothing.

@export var tint := Color(0.55, 0.85, 1.0, 1.0)
@export var deceleration := 1600.0

var time_left := 0.0
var _pulse: Tween

func enter(_previous: StringName) -> void:
	time_left = player.heal_time
	player.velocity.x = 0.0
	player.play(&"idle")            # no dedicated focus animation yet
	player.sprite.modulate = tint
	_pulse = create_tween().set_loops()
	_pulse.tween_property(player.sprite, "modulate", tint.lightened(0.35), player.heal_time * 0.25)
	_pulse.tween_property(player.sprite, "modulate", tint, player.heal_time * 0.25)

func physics_update(delta: float) -> void:
	time_left -= delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, deceleration * delta)
	player.move_and_slide()

	if not player.is_on_floor() or not Input.is_action_pressed("heal"):
		_cancel()
		return
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		_cancel()
		return
	if time_left <= 0.0:
		_complete()

func exit() -> void:
	if _pulse:
		_pulse.kill()
	player.sprite.modulate = Color.WHITE

func _cancel() -> void:
	machine.change_state(&"Idle" if player.is_on_floor() else &"Fall")

func _complete() -> void:
	if player.health < player.max_health and player.spend_mana(player.heal_cost):
		player.heal(1)
	machine.change_state(&"Idle" if player.is_on_floor() else &"Fall")
