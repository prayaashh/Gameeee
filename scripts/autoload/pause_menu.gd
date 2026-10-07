extends CanvasLayer

@onready var resume_button: Button = $Center/Panel/VBox/ResumeButton

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("esc"):
		return
	if Dialogue.active:                 # the dialogue owns Esc while it is open
		return
	get_viewport().set_input_as_handled()
	set_paused(not get_tree().paused)

func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		resume_button.grab_focus.call_deferred()

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_restart_pressed() -> void:
	set_paused(false)
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
