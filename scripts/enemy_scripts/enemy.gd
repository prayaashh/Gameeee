class_name Enemy
extends CharacterBody2D

## Emitted once when this enemy's health reaches 0, right before it disappears.
## Connect it in the Inspector (or code) to run your own death logic.
signal died(enemy: Node)

@export_group("Health")
## Hit points: the sword takes this down; at 0 the enemy dies.
@export var health := 3

@export_group("Movement")
@export var gravity := 1500.0
@export var friction := 1200.0
@export var patrol_speed := 60.0
@export var chase_speed := 120.0

@export_group("Sight & attack")
@export var sight_range := 250.0
@export var vision_height := 80.0         # max vertical difference it can see
@export var back_sight_range := 60.0      # notices you behind it only when very close
@export var eye_offset := Vector2(0, -20) # raise the ray off the floor
@export var attack_range := 30.0       # horizontal reach, matches the hitbox (25px fwd + player half-width)
@export var attack_height := 20.0      # max vertical gap the hitbox can still connect at
@export var attack_cooldown := 0.4
@export var attack_damage := 1

@export_group("Death rewards")
## Credits paid straight to the player when this enemy dies (0 = none).
@export var credits_on_death := 0
## Item dropped where the enemy died. Defaults to a credit orb.
@export var drop_scene: PackedScene = preload("res://scenes/pickups/credit_pickup.tscn")
## Value written to each drop's `value` property (0 = leave the scene's own value).
@export var drop_value := 5
## How many items to drop.
@export var drop_count := 1
## Horizontal spread used to scatter several drops.
@export var drop_scatter := 40.0

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
var _death_handled := false

func _ready() -> void:
	attack_hitbox.monitoring = false
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	attack_cooldown_left = max(attack_cooldown_left - delta, 0.0)
	chase_block_time = max(chase_block_time - delta, 0.0)
	# re-resolve the player if it was missing at _ready (e.g. an Enemies-first
	# room) or got rebuilt on a respawn, so the slime never chases a stale ref
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

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
	if machine.current != null and machine.current.name == &"Death":
		return
	health -= amount
	knockback_dir = signf(global_position.x - from_position.x)
	last_seen_position = from_position      # NEW: it knows where the hit came from
	face(-knockback_dir)                    # NEW: turn toward the attacker
	if health <= 0:
		machine.change_state(&"Death")
	elif machine.current != null and machine.current.name == &"Stagger":
		machine.current.enter(&"Stagger")
	else:
		machine.change_state(&"Stagger")

# --- death --------------------------------------------------------------------

## Runs once when this enemy dies. Pays credits, spawns the drop, fires the
## `died` signal and finally calls the editable on_death() hook. The Death state
## calls this for you; you normally never call it yourself.
func handle_death() -> void:
	if _death_handled:
		return
	_death_handled = true

	if credits_on_death > 0:
		GameState.add_credits(credits_on_death)

	# take_damage is called from physics callbacks, and adding nodes there is not
	# allowed, so Loot.spawn queues the drop for the next step. Position and
	# parent are captured now in case this enemy is freed before then.
	var at := global_position
	var parent: Node = get_parent() if get_parent() else get_tree().current_scene
	Loot.spawn(drop_scene, parent, at, drop_value, drop_count, drop_scatter)

	died.emit(self)
	on_death()

## ------------------------------------------------------------------
## ON-DEATH EVENT HOOK - this is the function you edit.
##
## Runs once, the moment this enemy's health reaches 0, before it disappears.
## The `died` signal (top of this file) fires just before it, so you can also
## connect to that in the Inspector instead of writing here.
##
## Examples:
##   GameState.add_credits(10)
##   GameState.set_flag("slime_cleared")
##   get_tree().call_group("doors", "open")
##
## NOTE: you are still inside the enemy's death callback, so use
##       call_deferred("...") if you spawn nodes or change physics state.
## ------------------------------------------------------------------
func on_death() -> void:
	pass
