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
	return false
