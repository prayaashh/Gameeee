extends Area2D

@export_group("Damage")
@export var damage: int = 1

@export_group("Timing")
@export var telegraph_time: float = 0.3
@export var active_time: float = 0.2

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var life_timer: Timer = $LifeTimer

var player: CharacterBody2D = null

func _ready() -> void:
	collision_shape.disabled = true
	sprite.modulate.a = 0.5
	life_timer.wait_time = telegraph_time + active_time
	life_timer.start()
	await get_tree().create_timer(telegraph_time).timeout
	sprite.modulate.a = 1.0
	collision_shape.disabled = false
	await get_tree().create_timer(active_time).timeout
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_life_timer_timeout() -> void:
	queue_free()
