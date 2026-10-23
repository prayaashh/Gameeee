extends Area2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	print("[DEATHBOX] ready, mask=", collision_mask)

func _on_body_entered(body: Node2D) -> void:
	print("[DEATHBOX] body_entered: ", body.name, " groups: ", body.get_groups(), " has_die: ", body.has_method("die"))
	if body.is_in_group("player"):
		if body.has_method("die"):
			body.die()
		elif body.has_method("take_damage"):
			body.take_damage(9999, global_position)
