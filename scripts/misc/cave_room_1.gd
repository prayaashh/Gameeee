extends Room


func _ready() -> void:
	super._ready() # Let Room handle finding the player, camera limits, etc first
	if _camera != null:
		_camera.zoom = Vector2(1.25, 1.25)
		_camera.position.y -= 40
		
