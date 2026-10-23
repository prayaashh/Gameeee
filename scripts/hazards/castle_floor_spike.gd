extends Area2D

## Castle floor spike. It hides in the floor and only strikes when the player
## stands on it: the blades shoot up, take `damage` hearts once, then retract.
## After `strike_delay` seconds it strikes again, but only if the player is
## still standing there.

@export_group("Damage")
## Hearts removed by one strike. 1 = one heart.
@export var damage: int = 1

@export_group("Cycle")
## Seconds the blades stay extended before they go back in.
@export var up_timer: float = 1.5
## Seconds to wait after the blades retract before the next strike. The spike
## only strikes again if the player is still standing on it.
@export var strike_delay: float = 2.0

enum State { IDLE, RISING, EXTENDED, RETRACTING, WAITING }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var stay_up_timer: Timer = $StayUpTimer

var _state: int = State.IDLE
var _dangerous := false
var _hit_this_strike := false
var _wait_left := 0.0

func _ready() -> void:
	# The hitbox stays on at all times. Besides hurting the player it is how the
	# spike notices that someone is standing on it, so it cannot be disabled
	# while the blades are down.
	collision_shape.disabled = false
	sprite.animation_finished.connect(_on_animation_finished)
	_go_idle()

func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			# Never rise on its own: the player has to be on the tile.
			if _player_on_spike() != null:
				_strike()
		State.WAITING:
			_wait_left -= delta
			if _wait_left > 0.0:
				return
			if _player_on_spike() != null:
				_strike()
			else:
				_go_idle()

func _go_idle() -> void:
	_state = State.IDLE
	_dangerous = false
	_hit_this_strike = false
	sprite.play("idle")

func _strike() -> void:
	_state = State.RISING
	_hit_this_strike = false
	sprite.play("up")

func _on_animation_finished() -> void:
	match _state:
		State.RISING:
			if sprite.animation != &"up":
				return
			_state = State.EXTENDED
			_dangerous = true
			sprite.play("extended")
			if _player_on_spike() != null:
				_damage_once()
			stay_up_timer.start(up_timer)
		State.RETRACTING:
			if sprite.animation != &"down":
				return
			_dangerous = false
			_hit_this_strike = false
			sprite.play("idle")
			_state = State.WAITING
			_wait_left = strike_delay

func _on_stay_up_timer_timeout() -> void:
	if _state != State.EXTENDED:
		return
	_dangerous = false
	_state = State.RETRACTING
	sprite.play("down")

func _on_body_entered(body: Node2D) -> void:
	# Walking into blades that are already up hurts, but never twice.
	if body.is_in_group("player"):
		_damage_once()

func _damage_once() -> void:
	if not _dangerous or _hit_this_strike:
		return
	var player := _player_on_spike()
	if player == null:
		return
	_hit_this_strike = true
	player.take_damage(damage, global_position)

func _player_on_spike() -> Node2D:
	for body in get_overlapping_bodies():
		var node := body as Node2D
		if node != null and node.is_in_group("player"):
			return node
	return null
