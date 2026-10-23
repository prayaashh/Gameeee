extends Node

func _ready() -> void:
	var room: Node = (load("res://scenes/rooms/overworld castle 1/castle_1_room_1.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var spike: Area2D = room.get_node("CastleFloorSpike")
	var player: Node2D = room.get_node("player")
	var health_before: int = player.get("health")
	print("START health=", health_before, " spike=", spike.global_position,
		" shape=", (spike.get_node("CollisionShape2D") as CollisionShape2D).shape.size,
		" shape_pos=", (spike.get_node("CollisionShape2D") as CollisionShape2D).position)

	# stand the player on the spike
	player.global_position = Vector2(spike.global_position.x, 520.0 - 37.8)
	player.velocity = Vector2.ZERO

	var last_health: int = player.get("health")
	var last_dangerous: bool = spike._dangerous
	var hits := 0
	for i in 600:
		await get_tree().physics_frame
		if spike._dangerous != last_dangerous:
			print("t=", snappedf(i / 60.0, 0.01), " dangerous=", spike._dangerous,
				" anim=", (spike.get_node("AnimatedSprite2D") as AnimatedSprite2D).animation,
				" player_y=", snappedf(player.global_position.y, 0.1))
			last_dangerous = spike._dangerous
		if player.health != last_health:
			hits += 1
			print("HIT #", hits, " t=", snappedf(i / 60.0, 0.01),
				" health=", player.health, "/", player.max_health,
				" player_pos=", player.global_position.round())
			last_health = player.health
		# keep the player on the spike so the cooldown/overlap is exercised
		if absf(player.global_position.x - spike.global_position.x) > 4.0:
			player.global_position.x = spike.global_position.x
	print("END health=", player.health, " hits=", hits)
	get_tree().quit()
