extends CharacterBody2D

## Emitted once when this enemy's health reaches 0, right before it disappears.
signal died(enemy: Node)

@export_group("Path")
## The Path2D this fly follows. Draw a Path2D in the room, then drag the
## Path2D node from the Scene tree into this slot. Leave it empty and the
## fly simply hovers where you placed it.
@export var path: Path2D
@export var speed: float = 60.0          # travel speed in pixels/second
@export var loop_path: bool = true        # on = restart at the end, off = stop there
@export var start_progress: float = 0.0   # where on the path it begins (in pixels)

@export_group("Waiting")
## Where the fly pauses along its path:
##   Stop at every path point   - every point you drew on the Path2D is a stop
##   Stop only at listed points - uses "Points to stop at" below
##   Never stop                 - flies straight through
@export_enum("Stop at every path point", "Stop only at listed points", "Never stop") var wait_mode := 0
## Only used with "Stop only at listed points": 0-based indices of the Path2D's
## points, in the order you placed them ([0, 2] = 1st and 3rd point).
@export var wait_points: Array[int] = []
## How long it rests at each stop: a random time between these two.
@export var wait_time_min: float = 1.0
@export var wait_time_max: float = 3.0

@export_group("Health")
## Hit points: the sword takes this down; at 0 the fly dies.
@export var health: int = 3
@export var contact_damage: int = 1
@export var contact_interval: float = 0.5  # seconds between contact hits while overlapping

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var touch_area: Area2D = $TouchArea

var progress := 0.0
var dead := false
var contact_cooldown_left := 0.0
var wait_left := 0.0   # > 0 while resting at a wait point
var _stop_offsets := PackedFloat32Array()   # where the fly pauses, resolved at spawn

func _ready() -> void:
	sprite.play("fly")
	var total := _path_length()
	if total > 0.0:
		progress = fposmod(start_progress, total) if loop_path else clampf(start_progress, 0.0, total)
		_snap_to_path()
	_build_stop_offsets()
	_start_wait_if_on_point()

func _physics_process(delta: float) -> void:
	if dead:
		return
	contact_cooldown_left = maxf(contact_cooldown_left - delta, 0.0)
	_follow_path(delta)
	if contact_cooldown_left <= 0.0:
		_contact_damage_check()

## ---------------------------------------------------------------
## PATH: progress walks along the curve and the fly is placed at that point
## in world space every frame. The path is whatever Path2D you assigned in
## the Inspector - edit its points freely, the fly adapts immediately
## (the exact stop positions are resolved once, when it spawns).
func _path_length() -> float:
	if path == null or path.curve == null:
		return 0.0
	return path.curve.get_baked_length()

func _snap_to_path() -> void:
	var total := _path_length()
	if total <= 0.0:
		return
	# wrap only outside [0, total] so a stop ON the final point renders at the
	# final point instead of wrapping back to the start
	var offset := progress
	if offset > total or offset < 0.0:
		offset = fposmod(offset, total)
	global_position = path.to_global(path.curve.sample_baked(offset))

func _follow_path(delta: float) -> void:
	var total := _path_length()
	if total <= 0.0:
		return  # no path (or an empty one): hover in place
	if wait_left > 0.0:
		wait_left -= delta
		if wait_left > 0.0:
			return              # still resting at the wait point
		wait_left = 0.0         # rested long enough -> move again this tick
	var new_progress := progress + speed * delta
	if not loop_path:
		new_progress = minf(new_progress, total)
	var stop_at := _first_wait_crossing(progress, new_progress, total)
	if stop_at >= 0.0:
		progress = stop_at            # snap exactly onto the point, then rest
		wait_left = _roll_wait_time()
	else:
		progress = new_progress
	_snap_to_path()

## Resolves `wait_mode`/`wait_points` into concrete offsets along the path.
## Called once when the fly spawns (add/adjust stops, then run the scene).
func _build_stop_offsets() -> void:
	_stop_offsets.clear()
	if wait_mode == 2 or path == null or path.curve == null:
		return                      # "Never stop": empty list -> never waits
	var curve := path.curve
	if wait_mode == 0:
		for i in curve.get_point_count():
			_stop_offsets.append(curve.get_closest_offset(curve.get_point_position(i)))
	else:
		for idx in wait_points:
			if idx >= 0 and idx < curve.get_point_count():
				_stop_offsets.append(curve.get_closest_offset(curve.get_point_position(idx)))

## Finds the first stop point crossed between two progress values (checking
## every repeat of it when looping), snapped exactly onto it. -1 = none.
func _first_wait_crossing(from_p: float, to_p: float, total: float) -> float:
	if _stop_offsets.is_empty() or to_p <= from_p:
		return -1.0
	var best := -1.0
	for offset in _stop_offsets:
		# every place this stop occurs on the unbounded path is offset + k*total
		var k := floorf((from_p - offset) / total) + 1.0
		var candidate := offset + k * total
		if candidate <= to_p and (best < 0.0 or candidate < best):
			best = candidate
	return best

## If the fly starts right on one of its stops, rest there first.
func _start_wait_if_on_point() -> void:
	var total := _path_length()
	if total <= 0.0 or _stop_offsets.is_empty():
		return
	for offset in _stop_offsets:
		if absf(offset - progress) < 0.5:
			wait_left = _roll_wait_time()
			return

func _roll_wait_time() -> float:
	return randf_range(minf(wait_time_min, wait_time_max), maxf(wait_time_min, wait_time_max))
## ---------------------------------------------------------------

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
	# called from a physics callback -> everything must be deferred
	set_deferred("collision_layer", 0)            # the sword can no longer hit it
	touch_area.set_deferred("monitoring", false)
	set_physics_process(false)
	died.emit(self)
	# shrink into nothing while fading away, then disappear
	sprite.modulate = Color(1.0, 0.5, 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", scale * 0.15, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
## ---------------------------------------------------------------
