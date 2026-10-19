extends Area2D

@export_group("Damage")
@export var damage: int = 1

@export_group("Timing")
@export var damage_frame: int = 2   # animation frame at which the spike becomes harmful (its peak)
@export var active_time: float = 0.2 # how long it stays harmful after the peak

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var life_timer: Timer = $LifeTimer

var player: CharacterBody2D = null
var _active := false

func _ready() -> void:
	collision_shape.disabled = true
	sprite.modulate.a = 0.5
	sprite.play("attack")
	# damage is enabled frame-based: watch the animation, not a fixed timer
	# (the spike is telegraphed/transparent until it nears its peak)

func _physics_process(_delta: float) -> void:
	if _active:
		return
	if sprite.frame >= damage_frame:
		_active = true
		sprite.modulate.a = 1.0
		collision_shape.disabled = false
		life_timer.wait_time = active_time
		life_timer.start()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)

func _on_life_timer_timeout() -> void:
	queue_free()
