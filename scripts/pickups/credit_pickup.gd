class_name CreditPickup
extends Area2D

## A credit orb dropped by enemies when they die (see enemy.gd / snail_creep.gd).
## The player collects it by touching it, which adds `value` credits to GameState.
## You can also place one in a room by hand — it behaves the same.

signal collected(value: int)

@export var value := 5
@export var magnet_range := 80.0     # starts homing to the player inside this radius
@export var magnet_speed := 650.0
@export var pickup_delay := 0.25     # grace period before it can be picked up
@export var lifetime := 15.0         # seconds until it fades away; 0 = forever

var _velocity := Vector2.ZERO
var _age := 0.0
var _taken := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var _base_scale: Vector2 = sprite.scale

func _ready() -> void:
	_bob()

## Initial push given by Loot.spawn so several drops scatter apart.
func pop(velocity: Vector2) -> void:
	_velocity = velocity

func _process(delta: float) -> void:
	if _taken:
		return
	_age += delta

	if lifetime > 0.0 and _age >= lifetime:
		_disappear()
		return

	# short pop arc that settles to a stop
	_velocity = _velocity.move_toward(Vector2.ZERO, 420.0 * delta)
	global_position += _velocity * delta

	var player := _player()
	if player == null or _age < pickup_delay:
		return

	# home in on the player, then collect on contact
	var to_player := player.global_position - global_position
	if to_player.length() <= magnet_range:
		global_position += to_player.normalized() * magnet_speed * delta
	if to_player.length() <= 14.0 or get_overlapping_bodies().has(player):
		_collect()

func _player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or not is_instance_valid(players[0]):
		return null
	return players[0] as Node2D

func _collect() -> void:
	if _taken:
		return
	_taken = true
	GameState.add_credits(value)
	collected.emit(value)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)

func _disappear() -> void:
	if _taken:
		return
	_taken = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _bob() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", _base_scale * 1.15, 0.55).from(_base_scale * 0.85)
	tween.tween_property(sprite, "scale", _base_scale * 0.85, 0.55)
