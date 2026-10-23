extends Area2D

## Castle floor spike. It waits hidden in the floor, rises, stays extended for
## `up_timer` seconds, then retracts. While extended it takes `damage` hearts
## from a player standing on or above it, at most once every
## `damage_cooldown` seconds.

@export_group("Damage")
## Hearts removed per hit. 1 = one heart.
@export var damage: int = 1
## Seconds before it can hurt the player again while they stay on it.
@export var damage_cooldown: float = 1.0

@export_group("Cycle")
## How long the spike stays fully extended before going back down.
@export var up_timer: float = 1.5
## How long it stays hidden in the floor before rising again.
@export var down_duration: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var stay_up_timer: Timer = $StayUpTimer

var _dangerous := false
var _damage_cooldown_left := 0.0

func _ready() -> void:
	_show_idle()
	_start_down_cycle()

func _physics_process(delta: float) -> void:
	_damage_cooldown_left = maxf(_damage_cooldown_left - delta, 0.0)
	if _dangerous and _damage_cooldown_left <= 0.0:
		_damage_overlapping_players()

func _show_idle() -> void:
	# Fully retracted frame; the hitbox is off in this state.
	_dangerous = false
	collision_shape.disabled = true
	sprite.play("idle")

func _start_down_cycle() -> void:
	await get_tree().create_timer(down_duration).timeout
	if not is_inside_tree():
		return
	_rise()

func _rise() -> void:
	sprite.play("up")
	await sprite.animation_finished
	if not is_inside_tree():
		return
	sprite.play("extended")
	_dangerous = true
	collision_shape.disabled = false
	_damage_cooldown_left = 0.0
	_damage_overlapping_players()   # hurt anyone already standing there
	stay_up_timer.start(up_timer)

func _lower() -> void:
	_dangerous = false
	collision_shape.disabled = true
	sprite.play("down")
	await sprite.animation_finished
	if not is_inside_tree():
		return
	sprite.play("idle")
	_start_down_cycle()

func _on_stay_up_timer_timeout() -> void:
	_lower()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_damage(body)

func _damage_overlapping_players() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_damage(body)
			if _damage_cooldown_left > 0.0:
				break

func _damage(body: Node) -> void:
	if not _dangerous or _damage_cooldown_left > 0.0:
		return
	if not body.has_method("take_damage"):
		return
	body.take_damage(damage, global_position)
	_damage_cooldown_left = damage_cooldown
