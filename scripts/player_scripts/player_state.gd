class_name PlayerState
extends State

var player: Player:
	get: return actor as Player

func try_common_transitions() -> bool:
	if Input.is_action_just_pressed("dash") and player.can_dash():
		machine.change_state(&"Dash")
		return true
	if Input.is_action_just_pressed("attack"):
		machine.change_state(&"Attack")
		return true
	# Focus/heal: grounded only, needs missing health and enough mana.
	if player.is_on_floor() and Input.is_action_just_pressed("heal") and player.can_heal():
		machine.change_state(&"Heal")
		return true
	return false
