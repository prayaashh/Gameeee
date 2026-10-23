extends Area2D

@export_group("Damage")
## Damage dealt to the player when standing on/above the spike
@export var damage: int = 1

@export_group("Cycle")
## Time to stay extended (up) before retracting
@export var up_time: float = 1.5
## Time to stay retracted (down) before extending again
@export var down_time: float = 2.0
## Optional cooldown between damage ticks if player stays on it
@export var damage_cooldown: float = 0.5

@export_group("Detection")
## If true, only damages when player is standing on or above the spike
@export var require_on_or_above: bool = true
## Vertical tolerance for "above" detection (pixels)
@export var vertical_tolerance: float = 4.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var cycle_timer: Timer = $CycleTimer

var _is_up := false
var _damage_cooldown_left := 0.0

func _ready() -> void:
	collision_shape.disabled = true
	if sprite.sprite_frames:
		sprite.play("down")
	_start_down_cycle()

func _physics_process(delta: float) -> void:
	_damage_cooldown_left = maxf(_damage_cooldown_left - delta, 0.0)
	if _is_up and collision_shape.disabled == false and _damage_cooldown_left <= 0.0:
		_try_damage_player()

func _start_down_cycle() -> void:
	_is_up = false
	collision_shape.disabled = true
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("down"):
		sprite.play("down")
	cycle_timer.wait_time = down_time
	cycle_timer.start()

func _start_up_cycle() -> void:
	_is_up = true
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("up"):
		sprite.play("up")
		# Wait for animation to finish or extend immediately
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return
	collision_shape.disabled = false
	_damage_cooldown_left = 0.0  # allow immediate damage on first contact
	_try_damage_player()
	cycle_timer.wait_time = up_time
	cycle_timer.start()

func _try_damage_player() -> void:
	if _damage_cooldown_left > 0.0 or collision_shape.disabled:
		return
	var bodies := get_overlapping_bodies()
	for body in bodies:
		if not body.is_in_group("player"):
			continue
		if require_on_or_above:
			# Player must be standing on or above the spike (their feet at or above spike's top)
			var spike_top: float = global_position.y - (collision_shape.shape.size.y * scale.y * 0.5)
			var player_bottom: float = body.global_position.y
			# If using character controller, check feet position; approximate by position
			if player_bottom > spike_top + vertical_tolerance:
				continue
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			_damage_cooldown_left = damage_cooldown
			break

func _on_body_entered(body: Node2D) -> void:
	if _is_up and _damage_cooldown_left <= 0.0 and body.is_in_group("player"):
		if require_on_or_above:
			var spike_top: float = global_position.y - (collision_shape.shape.size.y * scale.y * 0.5)
			var player_bottom: float = body.global_position.y
			if player_bottom > spike_top + vertical_tolerance:
				return
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			_damage_cooldown_left = damage_cooldown

func _on_cycle_timer_timeout() -> void:
	if _is_up:
		_start_down_cycle()
	else:
		_start_up_cycle()
