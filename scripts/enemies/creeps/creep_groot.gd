extends CharacterBody2D

@export_group("Movement")
@export var speed: float = 60.0
@export var gravity: float = 1500.0

@export_group("Detection")
@export var detection_range: float = 120.0
@export var attack_range: float = 80.0
@export var lose_range: float = 180.0
@export var require_line_of_sight: bool = true

@export_group("Attack")
@export var spike_scene: PackedScene
@export var attack_cooldown: float = 1.5
@export var telegraph_time: float = 0.3
@export var spike_x_offset: float = 12.0
@export var cast_distance_below: float = 64.0

@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var lose_area: Area2D = $LoseArea
@onready var lose_shape: CollisionShape2D = $LoseArea/CollisionShape2D
@onready var cooldown_timer: Timer = $AttackCooldownTimer
@onready var raycast: RayCast2D = $GroundRayCast
@onready var los_raycast: RayCast2D = $LoSRaycast

var player: CharacterBody2D = null
var can_attack: bool = true
var attacking: bool = false

enum { IDLE, CHASE, ATTACK, COOLDOWN }
var state: int = IDLE

func _ready() -> void:
	detection_shape.shape.radius = detection_range
	attack_shape.shape.size = Vector2(attack_range, 32.0)
	lose_shape.shape.radius = lose_range
	cooldown_timer.wait_time = attack_cooldown
	if not has_node("GroundRayCast"):
		var gr = RayCast2D.new()
		gr.name = "GroundRayCast"
		gr.target_position = Vector2(0, cast_distance_below)
		gr.collision_mask = 5
		add_child(gr)
	if not has_node("LoSRaycast"):
		var lr = RayCast2D.new()
		lr.name = "LoSRaycast"
		lr.target_position = Vector2(0, 0)
		lr.collision_mask = 5
		add_child(lr)
	raycast = $GroundRayCast
	los_raycast = $LoSRaycast

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	match state:
		IDLE:
			pass
		CHASE:
			if player and can_see_player():
				var dir = sign(player.global_position.x - global_position.x)
				if abs(player.global_position.x - global_position.x) > 4.0:
					velocity.x = dir * speed
			else:
				state = IDLE
				player = null
		ATTACK:
			pass
		COOLDOWN:
			pass
	move_and_slide()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		state = CHASE

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		pass

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == player and can_attack and can_see_player():
		perform_attack()

func _on_attack_area_body_exited(body: Node2D) -> void:
	pass

func _on_lose_area_body_entered(body: Node2D) -> void:
	pass

func _on_lose_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		state = IDLE
		can_attack = true

func _on_attack_cooldown_timeout() -> void:
	can_attack = true
	if player and in_attack_range():
		perform_attack()
	else:
		state = CHASE if player else IDLE

func perform_attack() -> void:
	attacking = true
	can_attack = false
	state = ATTACK
	if player and spike_scene:
		var spawn_x = player.global_position.x + randf_range(-spike_x_offset, spike_x_offset)
		var ground_y = find_ground_y(spawn_x)
		if ground_y == 0.0:
			ground_y = player.global_position.y + 16.0
		var spike = spike_scene.instantiate()
		get_parent().add_child(spike)
		spike.global_position = Vector2(spawn_x, ground_y - 4.0)
	await get_tree().create_timer(telegraph_time + 0.1).timeout
	attacking = false
	cooldown_timer.start()
	state = COOLDOWN

func in_attack_range() -> bool:
	if not player: return false
	return global_position.distance_to(player.global_position) <= attack_range

func can_see_player() -> bool:
	if not require_line_of_sight or not player: return true
	los_raycast.global_position = global_position
	los_raycast.target_position = player.global_position - global_position
	los_raycast.force_raycast_update()
	if los_raycast.is_colliding():
		var hit = los_raycast.get_collider()
		return hit == player
	return true

func find_ground_y(x: float) -> float:
	var from = Vector2(x, global_position.y - 32.0)
	var to = Vector2(x, global_position.y + cast_distance_below)
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	var result = space_state.intersect_ray(params)
	if result.has("position"):
		return result.position.y
	return 0.0
