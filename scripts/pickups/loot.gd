class_name Loot
extends RefCounted

## Small helper for spawning reward drops at a world position.
##
## Enemies call this when they die, but you can call it from anywhere
## (chests, crates, scripted events...):
##
##     Loot.spawn(preload("res://scenes/pickups/credit_pickup.tscn"), get_parent(), global_position, 5)
##
## `scene` is any PackedScene whose root is a Node2D. If the root happens to
## expose a `value` property it is written with the requested value, and if it
## has a `pop(velocity)` method it gets an initial push so several drops scatter.
##
## Safe to call from inside a physics callback: the drop is created right away
## but only added to the tree on the next step, and it is queued on `parent`
## (which outlives an enemy that is about to be freed).

static func spawn(scene: PackedScene, parent: Node, at: Vector2, value: int = 0,
		count: int = 1, scatter: float = 40.0) -> void:
	if scene == null or not is_instance_valid(parent):
		return
	for _i in maxi(count, 0):
		var instantiated := scene.instantiate()
		if not instantiated is Node2D:
			push_warning("Loot.spawn: drop scene root is not a Node2D — skipping.")
			instantiated.free()
			continue
		var drop := instantiated as Node2D
		if value > 0 and drop.get("value") != null:
			drop.set("value", value)
		drop.z_index = 5     # draw over the ground
		if drop.has_method("pop"):
			drop.pop(Vector2(randf_range(-scatter, scatter), randf_range(-230.0, -170.0)))

		# Adding nodes during a physics callback is not allowed, so the actual
		# insertion is deferred one step. `at` is a world position.
		parent.add_child.call_deferred(drop)
		drop.set_deferred("global_position", at)
