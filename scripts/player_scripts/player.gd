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

@export_group("Mana")
@export var max_mana := 99
@export var mana_per_hit := 11      # mana gained each time the sword connects
@export var heal_cost := 33         # mana spent per heal
@export var heal_time := 0.9        # seconds the focus channel must be held

var facing := 1
var jump_buffer_left := 0.0
var dash_cooldown_left := 0.0
var air_dash_used := false

@export_group("Health")
@export var max_health := 5
var health := 0
var mana := 0
var hurt_dir := 1.0
var dead := false

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var machine: StateMachine = $StateMachine

func _ready() -> void:
	attack_hitbox.monitoring = false
	health = max_health
	mana = clampi(GameState.mana, 0, max_mana)   # mana survives room changes
	add_to_group("player")      # lets enemies find the player
	_resolve_spawn()

## Reads the spawn request left by GameState (checkpoint, doorway or death) and
## either places this player on it, or hops to the room the save points at.
func _resolve_spawn() -> void:
	var pending: Dictionary = GameState.pending_spawn
	if pending.is_empty():
		return
	var target := str(pending.get("scene", ""))
	var room_path := _room_scene_path()
	# On boot the save may point at a room other than the main scene: follow it.
	# A room opened on its own (e.g. F6 in the editor) should just run itself, so
	# only the main scene performs this hop. The change must be deferred because
	# we are inside _ready() (the tree is still adding children).
	if target != room_path:
		if room_path == GameState.MAIN_SCENE and ResourceLoader.exists(target):
			GameState.start_transition()
			GameState.call_deferred("_change_scene", target)   # target room consumes the request
			return
		# The request belongs to a different room: ignore it so this room keeps its
		# own spawn point instead of teleporting the player into another room's coords.
		if room_path == GameState.MAIN_SCENE:
			push_warning("Saved room is missing: " + target)
		GameState.pending_spawn = {}
		return
	GameState.pending_spawn = {}                      # consume
	GameState.start_transition()
	if pending.has("entrance"):
		_spawn_at_entrance(str(pending.get("entrance", "")))
	else:
		global_position = Vector2(
			float(pending.get("x", global_position.x)),
			float(pending.get("y", global_position.y)))
		_verify_ground.call_deferred()   # a stale save could be over a gap

## A checkpoint stores a raw position, so a room edit can leave it floating over a
## pit. If nothing solid sits under the spawn, fall back to the room's Spawn
## marker instead of dropping the player off the map.
func _verify_ground() -> void:
	if not is_inside_tree():
		return
	# Wait for the room's tile collision to register before probing.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var from := global_position + Vector2(0, 4)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), 2, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_warning("Spawn has no ground below — using the room's 'Spawn' entrance.")
		_spawn_at_entrance("Spawn")

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
	if dead or (machine.current != null and machine.current.name == &"Hurt"):
		return                  # dead, or brief invulnerability while hurt
	health = max(health - amount, 0)
	hurt_dir = signf(global_position.x - from_position.x)
	if health == 0:
		die()
	else:
		health_changed.emit(health, max_health)
		machine.change_state(&"Hurt")

## Full heal used by benches. Hearts only: mana is never granted for free, it
## only builds from landing sword hits (see gain_mana).
func heal_full() -> void:
	if dead:
		return
	health = max_health
	health_changed.emit(health, max_health)

## Restores a single heart. Used by the Heal state; see heal_full() for a bench.
func heal(amount: int) -> void:
	if dead or health >= max_health:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

# --- mana ---------------------------------------------------------------------

## Called when the sword lands a hit. Filling up by attacking mirrors soul.
func gain_mana(amount: int) -> void:
	if dead or amount <= 0:
		return
	_set_mana(mana + amount)

func spend_mana(amount: int) -> bool:
	if mana < amount:
		return false
	_set_mana(mana - amount)
	return true

## Single place that writes mana, so the persistent copy in GameState, the
## player's own value and the HUD signal always stay in sync.
func _set_mana(value: int) -> void:
	mana = clampi(value, 0, max_mana)
	GameState.mana = mana
	mana_changed.emit(mana, max_mana)

func can_heal() -> bool:
	return not dead and health < max_health and mana >= heal_cost

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
	if not is_inside_tree():
		return                                    # scene changed mid-fade; nothing to drop

	GameState.lose_all_credits(global_position)   # drops are recorded, nothing is saved
	GameState.respawn()                           # death writes no save file
