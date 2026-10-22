extends Node

func _ready() -> void:
	var watcher := Node.new()
	watcher.name = "FlyWatcher"
	watcher.set_script(load("res://_watch_fly.gd"))
	get_tree().root.add_child.call_deferred(watcher)
	GameState.pending_spawn = {}
	Engine.time_scale = 10.0
	GameState.go_to_room("res://scenes/rooms/cave/cave_room_1.tscn", "Spawn")
