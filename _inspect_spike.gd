extends SceneTree
func _init() -> void:
	var tex := load("res://assets/hazards/castle_spike.png") as Texture2D
	print(str(tex.get_width()) + "x" + str(tex.get_height()))
	quit()
