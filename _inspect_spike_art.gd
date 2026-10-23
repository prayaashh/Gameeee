extends SceneTree

func _init() -> void:
	var tex: Texture2D = load("res://assets/hazards/castle_spike.png")
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	print("sheet=", img.get_width(), "x", img.get_height())
	for row in 2:
		for col in 5:
			var minx := 64
			var miny := 100
			var maxx := -1
			var maxy := -1
			for y in 100:
				for x in 64:
					var px := img.get_pixel(col * 64 + x, row * 100 + y)
					if px.a > 0.05:
						minx = mini(minx, x)
						miny = mini(miny, y)
						maxx = maxi(maxx, x)
						maxy = maxi(maxy, y)
			print("row=", row, " col=", col, " bbox=(", minx, ",", miny, ")-(", maxx, ",", maxy, ")")
	quit()
