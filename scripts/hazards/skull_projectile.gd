extends Area2D

## Straight-flying orb spat out by the skull pillar. Damage happens on contact
## with the player; hitting the room tiles only makes it burst.

## Pixels per second, set by whoever spawns it.
var speed: float = 320.0
## Hearts removed on contact.
var damage: int = 1
## Unit vector, set by whoever spawns it. The sprite turns to face the way the
## orb is travelling.
var direction: Vector2 = Vector2.RIGHT:
	set(value):
		direction = value
		_face_direction()
## Seconds before it gives up if it hits nothing.
var lifetime: float = 6.0
## Node it was fired from, so it does not burst on its own pillar.
var ignore: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _dead := false

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	_play(&"fly")
	_face_direction()
	body_entered.connect(_on_body_entered)

## Points the art along the flight path. The sprite offset already centres the
## orb on the node, so rotating the sprite keeps the hit circle centred.
func _face_direction() -> void:
	if is_node_ready():
		sprite.rotation = direction.angle()+PI

func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_burst()

func _on_body_entered(body: Node2D) -> void:
	if _dead or body == ignore:
		return
	if body.is_in_group("player"):
		body.take_damage(damage, global_position)
	_burst()

func _burst() -> void:
	_dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _has_animation(&"burst"):
		sprite.play(&"burst")
	else:
		queue_free()

func _on_animation_finished() -> void:
	if _dead:
		queue_free()

func _has_animation(anim: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim)

func _play(anim: StringName) -> void:
	if _has_animation(anim):
		sprite.play(anim)
