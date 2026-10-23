extends Node2D

## Hanging chandelier. It drops when the player crosses underneath, hurts them
## once while it is falling, plays the crash animation where it lands and then
## stays there as scenery. It never hangs itself back up.
##
## The node's origin sits at the bottom of the art (the sprite is offset up), so
## the chandelier's base is the point that touches the floor. The drop distance
## is found with a raycast, so it lands on whatever floor is underneath.
##
## Animations (see assets/hazards/chandelier_frames.tres):
##   hanging - 1 frame, swings/waits on the ceiling
##   fall    - 1 frame, used on the way down
##   crash   - 7 frames, plays once where it lands (~3.5 s)
##   crashed - 1 frame, the final smashed chandelier

@export_group("Fall")
## Drop speed in pixels per second.
@export var fall_speed: float = 900.0
## Only used if no floor is found underneath; otherwise the raycast decides.
@export var fall_backup: float = 300.0

@export_group("Damage")
## Hearts removed if the falling chandelier hits the player.
@export var damage: int = 1

## How far down to look for the floor.
const MAX_FALL := 4000.0
## Collision layer the room tiles are on.
const WORLD_MASK := 2

enum State { HANGING, FALLING, CRASHING, CRASHED }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger_zone: Area2D = $TriggerZone
@onready var impact_zone: Area2D = $ImpactZone

var _state: int = State.HANGING
var _hit := false
var _target_y := 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	_play(&"hanging")

func _physics_process(delta: float) -> void:
	match _state:
		State.HANGING:
			# Crossing under it or standing there both count.
			if _player_in(trigger_zone) != null:
				_start_fall()
		State.FALLING:
			global_position.y = minf(global_position.y + fall_speed * delta, _target_y)
			if not _hit:
				_try_damage()
			if global_position.y >= _target_y:
				_land()

func _start_fall() -> void:
	_state = State.FALLING
	_hit = false
	_target_y = _floor_y()
	_play(&"fall")

func _land() -> void:
	if _has_animation(&"crash"):
		_state = State.CRASHING
		sprite.play(&"crash")
	else:
		_settle()

func _settle() -> void:
	_state = State.CRASHED
	if _has_animation(&"crashed"):
		sprite.play(&"crashed")
	else:
		sprite.stop()

func _on_animation_finished() -> void:
	# Only the crash animation ends on its own.
	if _state == State.CRASHING:
		_settle()

func _try_damage() -> void:
	var player := _player_in(impact_zone)
	if player == null:
		return
	_hit = true
	player.take_damage(damage, global_position)

## Straight down until something solid on the room's layer is hit.
func _floor_y() -> float:
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0, MAX_FALL), WORLD_MASK)
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y + fall_backup
	return hit["position"].y

func _player_in(zone: Area2D) -> Node2D:
	for body in zone.get_overlapping_bodies():
		var node := body as Node2D
		if node != null and node.is_in_group("player"):
			return node
	return null

func _has_animation(anim: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim)

func _play(anim: StringName) -> void:
	if _has_animation(anim):
		sprite.play(anim)
