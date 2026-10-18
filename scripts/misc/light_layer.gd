extends Parallax2D

## How many extra copies to make on each side of the original.
@export var copies_each_side: int = 3


func _ready() -> void:
	if repeat_size.x <= 0.0:
		push_warning("Set Repeat Size X on this Parallax2D first.")
		return

	# Remember the lights you placed by hand (before we add any copies).
	var originals: Array[PointLight2D] = []
	for child in get_children():
		if child is PointLight2D:
			originals.append(child)

	for i in range(-copies_each_side, copies_each_side + 1):
		if i == 0:
			continue  # the originals already sit at offset 0
		for original in originals:
			var copy := original.duplicate() as PointLight2D
			copy.position.x += i * repeat_size.x
			add_child(copy)
