class_name Enemy
extends CharacterBody2D

@export var health := 3
@export var gravity := 1500.0
@export var friction := 1200.0
@export var patrol_speed := 60.0
@export var chase_speed := 120.0
@export var sight_range := 250.0
@export var attack_range := 30.0       # horizontal reach, matches the hitbox (25px fwd + player half-width)
@export var attack_height := 20.0      # max vertical gap the hitbox can still connect at
@export var attack_cooldown := 0.4
@export var attack_damage := 1

var facing := 1
var knockback_dir := 1.0
var attack_cooldown_left := 0.0
var chase_block_time := 0.0            # set when we give up, keeps patrol from re-engaging instantly
var player: Node2D

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var wall_check: RayCast2D = $Visuals/WallCheck
@onready var ledge_check: RayCast2D = $Visuals/LedgeCheck
@onready var attack_hitbox: Area2D = $Visuals/AttackHitbox
@onready var machine: StateMachine = $StateMachine

@export var vision_height := 80.0         # max vertical difference it can see
@export var back_sight_range := 60.0      # notices you behind it only when very close
@export var eye_offset := Vector2(0, -20) # raise the ray off the floor

const WORLD_MASK := 2                     # the ground/wall layer

# the slime sheet only ships `chasing` + `idle`, so missing anims fall back
# to a placeholder instead of spamming "There is no animation with name X"
const ANIM_FALLBACK := {
	&"walk": &"chasing",
	&"run": &"chasing",
	&"windup": &"idle",
	&"attack": &"chasing",
	&"hurt": &"idle",
	&"death": &"idle",
}

var last_seen_position := Vector2.ZERO

func _ready() -> void:
	attack_hitbox.monitoring = false
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	attack_cooldown_left = max(attack_cooldown_left - delta, 0.0)
	chase_block_time = max(chase_block_time - delta, 0.0)

# ---- helpers used by states ----
func face(dir: float) -> void:
	if dir == 0.0:
		return
	facing = 1 if dir > 0 else -1
	visuals.scale.x = facing
	wall_check.force_raycast_update()    # refresh rays right after flipping
	ledge_check.force_raycast_update()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func play(anim: StringName) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		var fallback: StringName = ANIM_FALLBACK.get(anim, &"")
		if fallback == &"" or not sprite.sprite_frames.has_animation(fallback):
			return
		anim = fallback
	if sprite.animation != anim:
		sprite.play(anim)

func distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)

func horizontal_gap_to_player() -> float:
	if player == null:
		return INF
	return absf(player.global_position.x - global_position.x)

func vertical_gap_to_player() -> float:
	if player == null:
		return INF
	return absf(player.global_position.y - global_position.y)

func direction_to_player() -> float:
	if player == null:
		return 0.0
	return signf(player.global_position.x - global_position.x)

func can_see_player(alerted: bool = false) -> bool:
	if player == null:
		return false

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# alerted enemies see farther and higher (you jumped over them)
	var range_mult: float = 1.5 if alerted else 1.0
	var height_mult: float = 2.0 if alerted else 1.0

	if dist > sight_range * range_mult:
		return false
	if absf(to_player.y) > vision_height * height_mult:
		return false

	# the front-only cone applies only while NOT alerted
	if not alerted:
		var in_front: bool = signf(to_player.x) == facing
		if not in_front and dist > back_sight_range:
			return false

	# line of sight
	var from: Vector2 = global_position + eye_offset
	var to: Vector2 = player.global_position + eye_offset
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return false

	last_seen_position = player.global_position
	return true
func at_edge_or_wall() -> bool:
	return is_on_floor() and (wall_check.is_colliding() or not ledge_check.is_colliding())

func take_damage(amount: int, from_position: Vector2) -> void:
	if machine.current.name == &"Death":
		return
	health -= amount
	knockback_dir = signf(global_position.x - from_position.x)
	last_seen_position = from_position      # NEW: it knows where the hit came from
	face(-knockback_dir)                    # NEW: turn toward the attacker
	if health <= 0:
		machine.change_state(&"Death")
	elif machine.current.name == &"Stagger":
		machine.current.enter(&"Stagger")
	else:
		machine.change_state(&"Stagger")
