extends Node2D

## Skull pillar. Sits still until the player comes close, then its eyes light up
## (the activated animation), it charges briefly and starts spitting orbs at
## where the player is standing. The orbs fly in a straight line, so moving or
## jumping out of the way avoids them.
##
## The node's origin sits at the bottom of the art (the sprite is offset up), so
## dropping the node on the floor places the pillar correctly.
##
## Animations (see assets/hazards/skull_pillar_frames.tres):
##   idle / activated       - pillar design 1
##   idle_2 / activated_2   - pillar design 2
##   idle_3 / activated_3   - pillar design 3
## Pick one with the `variant` export.

@export_group("Detection")
## How close the player has to be for the eyes to light up, in pixels.
@export var detection_radius: float = 260.0

@export_group("Attack")
## Seconds the eyes glow before the first shot.
@export var charge_time: float = 0.7
## Seconds between shots while the player stays close.
@export var fire_interval: float = 1.8
## Orb speed in pixels per second.
@export var projectile_speed: float = 320.0
## Hearts removed per orb.
@export var damage: int = 1

@export_group("Looks")
## Which of the three pillar designs in the sheet to use.
@export_range(1, 3) var variant: int = 1

const PROJECTILE := preload("res://scenes/hazards/skull_projectile.tscn")
## Aim this far above the player's feet, so the orbs come in at chest height.
const AIM_HEIGHT := -18.0

enum State { IDLE, CHARGING, FIRING }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var body: StaticBody2D = $Body

var _state: int = State.IDLE
var _timer := 0.0

func _ready() -> void:
	_play_idle()

func _physics_process(delta: float) -> void:
	var player := _player_in_range()
	match _state:
		State.IDLE:
			if player != null:
				_state = State.CHARGING
				_timer = charge_time
				_play_activated()
		State.CHARGING:
			if player == null:
				_calm_down()
			else:
				_timer -= delta
				if _timer <= 0.0:
					_fire(player)
					_state = State.FIRING
					_timer = fire_interval
		State.FIRING:
			if player == null:
				_calm_down()
			else:
				_timer -= delta
				if _timer <= 0.0:
					_fire(player)
					_timer = fire_interval

func _calm_down() -> void:
	_state = State.IDLE
	_play_idle()

func _fire(player: Node2D) -> void:
	var aim := player.global_position + Vector2(0, AIM_HEIGHT)
	var origin := muzzle.global_position
	var dir := (aim - origin).normalized()
	if dir == Vector2.ZERO:
		return
	var shot := PROJECTILE.instantiate()
	shot.direction = dir
	shot.speed = projectile_speed
	shot.damage = damage
	# The muzzle sits inside our own body, so the orb must ignore it.
	shot.ignore = body
	get_parent().add_child(shot)
	shot.global_position = origin

## Closest player inside the detection radius, or null.
func _player_in_range() -> Node2D:
	var best: Node2D = null
	var best_distance := detection_radius
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node2D
		if player == null:
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = player
	return best

func _play_idle() -> void:
	_play(_anim(&"idle"))

func _play_activated() -> void:
	_play(_anim(&"activated"))

## idle -> idle_2 -> idle_3, activated -> activated_2 -> activated_3.
func _anim(base: StringName) -> StringName:
	if variant <= 1:
		return base
	return StringName("%s_%d" % [base, variant])

func _play(anim: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
