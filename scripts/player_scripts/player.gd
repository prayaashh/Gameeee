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
var dead := false

signal health_changed(current: int, maximum: int)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var machine: StateMachine = $StateMachine

func _ready() -> void:
	attack_hitbox.monitoring = false
	health = max_health
	add_to_group("player")      # lets enemies find the player
	_resolve_spawn()

## Reads the spawn request left by GameState (checkpoint, doorway or death) and
## either places this player on it, or hops to the room the save points at.
func _resolve_spawn() -> void:
	var pending: Dictionary = GameState.pending_spawn
	if pending.is_empty():
		return
	GameState.pending_spawn = {}                      # consume
	var target := str(pending.get("scene", ""))
	var room_path := _room_scene_path()
	if target != room_path:
		# Saved room is a different one: switch scenes and let that room's player spawn.
		GameState.pending_spawn = pending
		if ResourceLoader.exists(target):
			GameState.start_transition()
			get_tree().change_scene_to_file(target)
		else:
			push_warning("Saved room is missing: " + target)
			GameState.pending_spawn = {}
		return
	GameState.start_transition()
	if pending.has("entrance"):
		_spawn_at_entrance(str(pending.get("entrance", "")))
	else:
		global_position = Vector2(
			float(pending.get("x", global_position.x)),
			float(pending.get("y", global_position.y)))

func _room_scene_path() -> String:
	var room := owner if owner else get_tree().current_scene
	return room.scene_file_path if room else ""

func _spawn_at_entrance(entrance: String) -> void:
	var room := owner if owner else get_tree().current_scene
	var marker: Node2D = null
	if room:
		marker = room.get_node_or_null("Entrances/" + entrance)
	if marker == null:
		push_warning("Missing entrance marker '%s' — using the room's default spawn." % entrance)
		return
	global_position = marker.global_position


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
	if dead or machine.current.name == &"Hurt":
		return                  # dead, or brief invulnerability while hurt
	health = max(health - amount, 0)
	hurt_dir = signf(global_position.x - from_position.x)
	if health == 0:
		die()
	else:
		health_changed.emit(health, max_health)
		machine.change_state(&"Hurt")

func heal_full() -> void:
	if dead:
		return
	health = max_health
	health_changed.emit(health, max_health)

func die() -> void:
	if dead:
		return
	dead = true
	health = 0
	health_changed.emit(0, max_health)
	if Dialogue.active:
		Dialogue.close()               # release the Talk state before we freeze
	machine.set_physics_process(false)
	machine.set_process_unhandled_input(false)
	set_physics_process(false)
	velocity = Vector2.ZERO
	sprite.stop()

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade.finished

	GameState.lose_all_credits(global_position)   # drops are recorded, nothing is saved
	GameState.respawn()                           # death writes no save file
