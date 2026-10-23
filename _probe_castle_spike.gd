extends Node

func _ready() -> void:
	var room: Node = (load("res://scenes/rooms/overworld castle 1/castle_1_room_1.tscn") as PackedScene).instantiate()
	add_child(room)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var spike: Area2D = room.get_node_or_null("CastleFloorSpike")
	var player: Node2D = room.get_node_or_null("player")
	print("SPIKE at ", spike.global_position, " scale=", spike.scale)
	var spr: AnimatedSprite2D = spike.get_node("AnimatedSprite2D")
	var cs: CollisionShape2D = spike.get_node("CollisionShape2D")
	var frame_tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	var frame_size := frame_tex.get_size() * spr.global_scale
	print("SPRITE pos=", spr.position, " anim=", spr.animation, " frame=", spr.frame,
		" frame_size=", frame_size,
		" bottom_y=", spr.global_position.y + frame_size.y * 0.5,
		" top_y=", spr.global_position.y - frame_size.y * 0.5)
	print("SHAPE pos=", cs.position, " size=", (cs.shape as RectangleShape2D).size,
		" disabled=", cs.disabled)
	if player:
		print("PLAYER at ", player.global_position, " scale=", player.scale,
			" feet_guess=", player.global_position.y + 31.5 * player.scale.y)

	# floor under the spike
	var space := get_viewport().world_2d.direct_space_state
	var params := PhysicsRayQueryParameters2D.create(
		Vector2(spike.global_position.x, spike.global_position.y - 400.0),
		Vector2(spike.global_position.x, spike.global_position.y + 400.0))
	var hit := space.intersect_ray(params)
	print("FLOOR under spike: ", hit)

	# watch one full cycle
	spr.animation_finished.connect(func(a): print("ANIM FINISHED: ", a))
	var last_anim := ""
	var last_disabled := cs.disabled
	for i in 480:
		await get_tree().physics_frame
		if spr.animation != last_anim or cs.disabled != last_disabled:
			print("t=", snappedf(i / 60.0, 0.01), " anim=", spr.animation,
				" frame=", spr.frame, " disabled=", cs.disabled)
			last_anim = spr.animation
			last_disabled = cs.disabled
	get_tree().quit()
