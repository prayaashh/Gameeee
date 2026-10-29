extends CharacterBody2D

## Emitted once when this enemy's health reaches 0, right before it disappears.
signal died(enemy: Node)

@export_group("Movement")
@export var patrol_speed: float = 40.0
@export var gravity: float = 1500.0
@export var idle_time: float = 1.5      # seconds standing still between patrols
@export var patrol_time: float = 2.5    # seconds walking before stopping again

@export_group("Detection")
@export var detection_range: float = 120.0  # distance at which the player triggers an attack
@export var lose_range: float = 180.0       # player must get further than this to de-aggro
@export var require_line_of_sight: bool = true

@export_group("Attack")
@export var spike_scene: PackedScene
@export var attack_cooldown: float = 1.5
@export var spike_x_offset: float = 0.0  # random x jitter around the player; 0 = exactly under them
@export var cast_distance_below: float = 64.0

@export_group("Health")
## Hit points: the sword takes this down; at 0 the groot dies.
@export var health: int = 3
@export var contact_damage: int = 1
@export var contact_interval: float = 0.5  # seconds between contact hits while overlapping

@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var lose_area: Area2D = $LoseArea
@onready var lose_shape: CollisionShape2D = $LoseArea/CollisionShape2D
@onready var cooldown_timer: Timer = $AttackCooldownTimer
@onready var raycast: RayCast2D = $GroundRayCast
@onready var los_raycast: RayCast2D = $LoSRaycast
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var touch_area: Area2D = $TouchArea

enum { IDLE, PATROL, ATTACK, COOLDOWN }
var state: int = IDLE

var player: CharacterBody2D = null
var can_attack := true
var dir := 1.0        # patrol direction: 1 = right, -1 = left
var state_time := 0.0 # countdown for IDLE / PATROL
var dead := false
var contact_cooldown_left := 0.0

func _ready() -> void:
	# duplicate shapes: each instance may have its own scale, shapes are shared otherwise
	detection_shape.shape = detection_shape.shape.duplicate()
	lose_shape.shape = lose_shape.shape.duplicate()
	# divide by scale so the exported ranges stay accurate in world pixels
	detection_shape.shape.radius = detection_range / scale.x
	lose_shape.shape.radius = lose_range / scale.x
	cooldown_timer.wait_time = attack_cooldown
	if not has_node("GroundRayCast"):
		var gr = RayCast2D.new()
		gr.name = "GroundRayCast"
		gr.target_position = Vector2(0, cast_distance_below)
		gr.collision_mask = collision_mask | (1 << 3)
		add_child(gr)
	if not has_node("LoSRaycast"):
		var lr = RayCast2D.new()
		lr.name = "LoSRaycast"
		lr.target_position = Vector2(0, 0)
		lr.collision_mask = collision_mask | (1 << 3)
		add_child(lr)
	raycast = $GroundRayCast
	los_raycast = $LoSRaycast
	state_time = idle_time
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if dead:
		return
	contact_cooldown_left = maxf(contact_cooldown_left - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0

	match state:
		IDLE:
			sprite.play("idle")
			state_time -= delta
			if state_time <= 0.0:
				dir = 1.0 if randf() < 0.5 else -1.0
				state_time = patrol_time
				state = PATROL
		PATROL:
			velocity.x = dir * patrol_speed
			sprite.flip_h = dir > 0.0   # art faces left by default
			sprite.play("walk")
			state_time -= delta
			if state_time <= 0.0:
				state_time = idle_time
				state = IDLE
		ATTACK:
			velocity.x = 0.0
			sprite.play("attack")
		COOLDOWN:
			velocity.x = 0.0
			sprite.play("idle")

	move_and_slide()

	# touch damage: only while not attacking (the spike is the attack's hit)
	if state != ATTACK and contact_cooldown_left <= 0.0:
		_contact_damage_check()

	# turn around at walls and ledge edges while patrolling
	if state == PATROL and is_on_floor():
		if is_on_wall() or not _ground_ahead():
			dir = -dir
			sprite.flip_h = dir > 0.0

	# attack as soon as the aggro'd player is close enough and visible
	if player and can_attack and state in [IDLE, PATROL] and _player_in_range() and can_see_player():
		_attack()

func _ground_ahead() -> bool:
	# probe the floor a bit in front of the feet
	raycast.global_position = global_position + Vector2(dir * 24.0, 0.0)
	raycast.force_raycast_update()
	return raycast.is_colliding()

## ---------------------------------------------------------------
## AGGRO: DetectionArea/LoseArea only track WHO the player is.
## Whether to actually attack is checked every frame (range + line of sight).
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D

func _on_lose_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		can_attack = true
		cooldown_timer.stop()
		if state in [ATTACK, COOLDOWN]:
			state = IDLE
			state_time = idle_time
## ---------------------------------------------------------------

func _attack() -> void:
	can_attack = false
	state = ATTACK
	if player:
		sprite.flip_h = player.global_position.x > global_position.x  # art faces left by default
	# hold the attack pose until the animation has actually finished
	var frames := sprite.sprite_frames
	var attack_duration: float = frames.get_frame_count("attack") / maxf(frames.get_animation_speed("attack"), 0.01)
	await get_tree().create_timer(attack_duration).timeout
	if dead or not is_inside_tree():
		return
	if player and spike_scene:
		var spawn_x = player.global_position.x + randf_range(-spike_x_offset, spike_x_offset)
		var ground_y = find_ground_y(spawn_x)
		if ground_y == 0.0:
			ground_y = player.global_position.y + 31.0  # fallback: player's feet, not mid-body
		var spike = spike_scene.instantiate()
		get_parent().add_child(spike)
		spike.global_position = Vector2(spawn_x, ground_y)
	cooldown_timer.start()
	state = COOLDOWN

func _on_attack_cooldown_timeout() -> void:
	if dead:
		return
	can_attack = true
	if player and _player_in_range() and can_see_player():
		_attack()
	else:
		state = IDLE
		state_time = idle_time

func _player_in_range() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func can_see_player() -> bool:
	if not require_line_of_sight or not player:
		return true
	los_raycast.global_position = global_position
	# target_position is local space, so undo the node scale or the ray overshoots
	los_raycast.target_position = (player.global_position - global_position) / scale
	los_raycast.force_raycast_update()
	if los_raycast.is_colliding():
		var hit = los_raycast.get_collider()
		return hit == player
	return true

func find_ground_y(x: float) -> float:
	if not player:
		return 0.0
	# cast relative to the PLAYER, not the creep: the spike must land on the
	# floor under the player even when the two are at different heights.
	# start at the player's origin (not above!) so a ceiling can't be hit first
	var from = Vector2(x, player.global_position.y)
	var to = Vector2(x, player.global_position.y + maxf(cast_distance_below, 256.0))
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	# exclude bodies: otherwise the ray hits the player (or this creep) and
	# the "ground" position ends up on the player's head
	params.exclude = [get_rid()]
	params.exclude.append(player.get_rid())
	var result = space_state.intersect_ray(params)
	if result.has("position"):
		return result.position.y
	return 0.0

## ---------------------------------------------------------------
## DAMAGE: the player's sword finds this enemy because take_damage() exists
## (attack.gd checks has_method("take_damage")).
func take_damage(amount: int, _from_position: Vector2) -> void:
	if dead:
		return
	health -= amount
	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		_die()

func _contact_damage_check() -> void:
	for body in touch_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)
			contact_cooldown_left = contact_interval
			break

func _die() -> void:
	dead = true
	state = COOLDOWN
	# called from a physics callback -> everything must be deferred
	set_deferred("collision_layer", 0)            # the sword can no longer hit it
	touch_area.set_deferred("monitoring", false)
	detection_shape.set_deferred("disabled", true)
	lose_shape.set_deferred("disabled", true)
	cooldown_timer.stop()
	died.emit(self)
	set_physics_process(false)
	# the sheet has no die animation -> flash out instead:
	# shrink into nothing while fading away, then disappear
	sprite.modulate = Color(1.0, 0.5, 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", scale * 0.15, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
## ---------------------------------------------------------------
