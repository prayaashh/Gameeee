extends EnemyState

enum Phase { WINDUP, ACTIVE, RECOVERY }

@export var windup_time := 0.4
@export var active_time := 0.15
@export var recovery_time := 0.5

var phase := Phase.WINDUP
var timer := 0.0
var already_hit: Array = []

func enter(_previous: StringName) -> void:
	enemy.velocity.x = 0.0
	enemy.face(enemy.direction_to_player())
	enemy.play(&"windup")
	phase = Phase.WINDUP
	timer = windup_time
	already_hit.clear()

func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.move_and_slide()
	timer -= delta

	match phase:
		Phase.WINDUP:
			if timer <= 0.0:
				phase = Phase.ACTIVE
				timer = active_time
				enemy.play(&"attack")
				enemy.attack_hitbox.monitoring = true
		Phase.ACTIVE:
			for body in enemy.attack_hitbox.get_overlapping_bodies():
				if body in already_hit:
					continue
				already_hit.append(body)
				if body.has_method("take_damage"):
					body.take_damage(enemy.attack_damage, enemy.global_position)
			if timer <= 0.0:
				phase = Phase.RECOVERY
				timer = recovery_time
				enemy.attack_hitbox.monitoring = false
				enemy.play(&"idle")
		Phase.RECOVERY:
			if timer <= 0.0:
				machine.change_state(&"Chase")

func exit() -> void:
	enemy.attack_hitbox.monitoring = false
	enemy.attack_cooldown_left = enemy.attack_cooldown
