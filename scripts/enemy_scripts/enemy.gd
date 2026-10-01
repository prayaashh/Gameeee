class_name Enemy
extends CharacterBody2D

@export var health := 3

func take_damage(amount: int, from_position: Vector2) -> void:
	health -= amount
	var push := signf(global_position.x - from_position.x)
	velocity = Vector2(push * 300.0, -150.0)   # simple knockback
	print("damage dealt! health = ", health)
	if health <= 0:
		queue_free()
