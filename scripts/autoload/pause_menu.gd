extends CanvasLayer

@onready var resume_button: Button = $Center/Panel/VBox/ResumeButton

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		if Dialogue.active:             # the dialogue owns Esc while it is open
			return
		get_viewport().set_input_as_handled()
		set_paused(not get_tree().paused)
	elif get_tree().paused and event.is_action_pressed("attack"):
		# Attack also confirms on a gamepad: its trigger is not part of the
		# built-in ui_accept, so menus must listen for it themselves.
		# Dialogue.gd does the same thing.
		get_viewport().set_input_as_handled()
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()

func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		resume_button.grab_focus.call_deferred()

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_restart_pressed() -> void:
	set_paused(false)
	GameState.respawn()          # back to the last checkpoint (or the start)

func _on_quit_pressed() -> void:
	GameState.save_to_disk()     # quitting writes flags, credits and checkpoint
	get_tree().quit()
