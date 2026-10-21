extends CharacterBody2D
## Snail creep — a simple ground enemy.
##
## Behaviour:
##  - patrols the floor, turning around at walls and ledges,
##  - holds position when the player is inside its AttackRange (Area2D): it
##    stops walking and freezes the move cycle instead of sliding into the
##    player, then strikes at `hit_at` of the attack animation's duration,
##  - damages the player on contact (TouchArea) between attacks; the windup
##    itself never hits — the strike is the hit,
##  - dies when health reaches 0: the player's sword finds it because this
##    script has a take_damage() method (the sword calls has_method("take_damage")).
##
## The AnimatedSprite2D needs three animations: move (loop), attack, die.

## Emitted once when this enemy's health reaches 0, right before it disappears.
## Connect it in the Inspector (or code) to run your own death logic.
signal died(enemy: Node)

enum State { PATROL, ATTACK, DEAD }

@export var speed := 55.0
@export var gravity := 1500.0

@export_group("Health")
## Hit points: the sword takes this down; at 0 the snail dies.
@export var health := 3
## Damage dealt to the player when they touch it.
@export var contact_damage := 1
## How often contact damage repeats while overlapping.
@export var contact_interval := 0.5

@export_group("Attack")
@export var attack_damage := 1
@export var attack_cooldown := 0.8      # seconds after an attack before it can attack again
@export_range(0.0, 1.0) var hit_at = 0.4
@export var knockback_time := 0.15
@export var knockback_speed := 120.0

@export_group("Death rewards")
## Credits paid straight to the player when this enemy dies (0 = none).
@export var credits_on_death := 0
## Item dropped where the enemy died. Defaults to a credit orb.
@export var drop_scene: PackedScene = preload("res://scenes/pickups/credit_pickup.tscn")
## Value written to each drop's `value` property (0 = leave the scene's own value).
@export var drop_value := 5
## How many items to drop.
@export var drop_count := 1
## Horizontal spread used to scatter several drops.
@export var drop_scatter := 40.0

var state := State.PATROL
var direction := -1.0                   # the art faces left, so patrol starts moving left
var player: Node2D

var attack_cooldown_left := 0.0
var contact_cooldown_left := 0.0
var attack_elapsed := 0.0
var attack_duration := 1.0
var attack_hit_done := false
var knockback_left := 0.0
var knockback_dir := 1.0
var _death_handled := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck
@onready var attack_range: Area2D = $AttackRange
@onready var touch_area: Area2D = $TouchArea

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	_aim_rays()
	_face_moving_direction()
	sprite.play(&"move")

func _physics_process(delta: float) -> void:
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	contact_cooldown_left = maxf(contact_cooldown_left - delta, 0.0)
	knockback_left = maxf(knockback_left - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.PATROL:
			# Player in range: stop, face them and wait out the cooldown instead
			# of walking into them (that made contact damage land before the
			# attack animation ever started).
			if knockback_left <= 0.0 and _player_in_range():
				_hold_for_player()
				if attack_cooldown_left <= 0.0:
					_start_attack()
			else:
				_patrol()
			_contact_damage_check()
		State.ATTACK:
			_attacking(delta)     # no contact damage here: the strike is the hit
		State.DEAD:
			velocity.x = 0.0

	move_and_slide()

# --- patrol -------------------------------------------------------------------

func _patrol() -> void:
	if knockback_left > 0.0:
		velocity.x = knockback_dir * knockback_speed
	else:
		velocity.x = speed * direction
		_face_moving_direction()    # undo any hold-for-player facing
		# turn around at walls and at ledges (only once we are actually standing)
		if is_on_floor() and (wall_check.is_colliding() or not floor_check.is_colliding()):
			direction = -direction
			_aim_rays()
			_face_moving_direction()
			velocity.x = speed * direction
	if sprite.animation != &"move" or not sprite.is_playing():
		sprite.play(&"move")        # resume after a hold-for-player pause

func _aim_rays() -> void:
	wall_check.position.x = 23.0 * direction
	wall_check.target_position.x = 9.0 * direction
	floor_check.position.x = 16.0 * direction
	wall_check.force_raycast_update()
	floor_check.force_raycast_update()

func _face_moving_direction() -> void:
	sprite.flip_h = direction > 0.0       # art faces left when unflipped

# --- attack -------------------------------------------------------------------

func _player_in_range() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	return player != null and attack_range.overlaps_body(player)

## The player is close: stop walking, face them and freeze the walk cycle so
## the snail never slides into the player while the attack is on cooldown.
func _hold_for_player() -> void:
	if knockback_left > 0.0:
		return                      # let the sword's knockback play out
	velocity.x = 0.0
	_face_position(player.global_position)
	if sprite.is_playing():
		sprite.pause()              # frozen mid-stride, not moonwalking in place

func _start_attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	attack_elapsed = 0.0
	attack_hit_done = false
	_face_position(player.global_position)
	var frames := float(sprite.sprite_frames.get_frame_count(&"attack"))
	var fps := sprite.sprite_frames.get_animation_speed(&"attack")
	attack_duration = frames / maxf(fps, 0.01)
	sprite.play(&"attack")

func _attacking(delta: float) -> void:
	attack_elapsed += delta
	velocity.x = 0.0
	# the strike lands at the hit_at fraction of the animation (inspector-tunable)
	if not attack_hit_done and attack_elapsed >= attack_duration * hit_at:
		attack_hit_done = true
		for body in attack_range.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(attack_damage, global_position)
	# safety net in case animation_finished never fires (animation swapped out)
	if attack_elapsed > attack_duration + 0.5:
		_finish_attack()

func _on_animation_finished() -> void:
	# The 'move' animation loops, so it never finishes; only 'attack' (and
	# later 'die') can land here. Godot 4's animation_finished emits no args.
	if state == State.ATTACK:
		_finish_attack()

func _finish_attack() -> void:
	state = State.PATROL
	attack_cooldown_left = attack_cooldown
	_face_moving_direction()
	sprite.play(&"move")

func _face_position(target: Vector2) -> void:
	sprite.flip_h = target.x > global_position.x   # unflipped art looks left

# --- contact damage -----------------------------------------------------------

func _contact_damage_check() -> void:
	if state != State.PATROL or contact_cooldown_left > 0.0:
		return                      # during the windup only the strike damages
	for body in touch_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)
			contact_cooldown_left = contact_interval
			break

# --- getting hurt / dying -----------------------------------------------------

## Called by the player's sword:  body.take_damage(player.attack_damage, origin)
func take_damage(amount: int, from_position: Vector2) -> void:
	if state == State.DEAD:
		return
	health -= amount
	knockback_dir = signf(global_position.x - from_position.x)
	if knockback_dir == 0.0:
		knockback_dir = 1.0
	knockback_left = knockback_time
	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	# we are inside a physics callback here -> everything must be deferred
	attack_range.set_deferred("monitoring", false)
	touch_area.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)     # the sword can no longer hit it
	wall_check.set_deferred("enabled", false)
	floor_check.set_deferred("enabled", false)
	handle_death()                         # credits + drop + `died` signal + on_death() hook
	sprite.play(&"die")
	await sprite.animation_finished
	if not is_inside_tree():
		return
	queue_free()

# --- death --------------------------------------------------------------------

## Runs once when this enemy dies. Pays credits, spawns the drop, fires the
## `died` signal and finally calls the editable on_death() hook. _die() calls
## this for you; you normally never call it yourself.
func handle_death() -> void:
	if _death_handled:
		return
	_death_handled = true

	if credits_on_death > 0:
		GameState.add_credits(credits_on_death)

	# take_damage is called from a physics callback, and adding nodes there is not
	# allowed, so Loot.spawn queues the drop for the next step. Position and
	# parent are captured now in case this enemy is freed before then.
	var at := global_position
	var parent: Node = get_parent() if get_parent() else get_tree().current_scene
	Loot.spawn(drop_scene, parent, at, drop_value, drop_count, drop_scatter)

	died.emit(self)
	on_death()

## ------------------------------------------------------------------
## ON-DEATH EVENT HOOK - this is the function you edit.
##
## Runs once, the moment this enemy's health reaches 0, before it disappears.
## The `died` signal (top of this file) fires just before it, so you can also
## connect to that in the Inspector instead of writing here.
##
## Examples:
##   GameState.add_credits(10)
##   GameState.set_flag("snail_cleared")
##   get_tree().call_group("doors", "open")
##
## NOTE: you are still inside the enemy's death callback, so use
##       call_deferred("...") if you spawn nodes or change physics state.
## ------------------------------------------------------------------
func on_death() -> void:
	pass
