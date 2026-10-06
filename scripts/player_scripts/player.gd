class_name Player
extends CharacterBody2D

@export_group("Movement")
@export var speed := 250.0
@export var gravity := 1500.0
@export var max_fall_speed := 900.0
@export var jump_velocity := -550.0
@export var jump_buffer_time := 0.12
@export_group("Abilities")
@export var dash_speed := 700.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.4
@export var attack_damage := 1
@export var attack_time := 0.25

var facing := 1
var jump_buffer_left := 0.0
var dash_cooldown_left := 0.0
var air_dash_used := false

@export var max_health := 5
var health := 0
var hurt_dir := 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var machine: StateMachine = $StateMachine

func _ready() -> void:
	attack_hitbox.monitoring = false
	health = max_health
	add_to_group("player")      # lets enemies find the player


func _physics_process(delta: float) -> void:
	jump_buffer_left = max(jump_buffer_left - delta, 0.0)
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = jump_buffer_time
	if is_on_floor():
		air_dash_used = false

func get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")

func apply_gravity(delta: float) -> void:
	velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

func move_horizontal(dir: float) -> void:
	velocity.x = dir * speed
	face(dir)

func face(dir: float) -> void:
	if dir == 0.0:
		return
	facing = 1 if dir > 0 else -1
	sprite.flip_h = facing < 0
	attack_hitbox.scale.x = facing

func play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

func wants_jump() -> bool:
	return jump_buffer_left > 0.0

func can_dash() -> bool:
	return dash_cooldown_left <= 0.0 and not air_dash_used

func take_damage(amount: int, from_position: Vector2) -> void:
	if machine.current.name == &"Hurt":
		return                  # brief invulnerability while hurt
	health -= amount
	hurt_dir = signf(global_position.x - from_position.x)
	print("Player health: ", health)
	machine.change_state(&"Hurt")
