extends CanvasLayer

signal closed
signal _step(value: int)      # -1 = cancelled, 0 = advance, 0+ = chosen option

@export var chars_per_second := 40.0

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var text_label: RichTextLabel = $Panel/VBoxContainer/TextLabel
@onready var choice_box: HBoxContainer = $Panel/VBoxContainer/ChoiceBox
@onready var choice_font: Font = text_label.get_theme_font("normal_font")
@onready var choice_font_size: float = text_label.get_theme_font_size("normal_font_size")

var active := false
var choosing := false
var tween: Tween

func _ready() -> void:
	panel.hide()
	choice_box.hide()

# Shows lines one by one. Returns true if all were read, false if the player pressed esc.
func say(speaker: String, lines: Array) -> bool:
	active = true
	name_label.text = speaker
	panel.show()
	for line in lines:
		_show_line(line)
		if await _step == -1:
			return false
	return true

# Shows a question with buttons. Returns the chosen index, or -1 if cancelled.
func choose(speaker: String, question: String, options: Array) -> int:
	active = true
	choosing = true
	name_label.text = speaker
	panel.show()
	text_label.text = question
	text_label.visible_ratio = 1.0

	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.add_theme_font_override("font", choice_font)          # same font as the dialogue text
		b.add_theme_font_size_override("font_size", int(choice_font_size))
		b.pressed.connect(func(): _step.emit(i))
		choice_box.add_child(b)
	choice_box.show()
	choice_box.get_child(0).grab_focus.call_deferred()   # left/right arrows move between buttons

	var result: int = await _step
	choosing = false
	choice_box.hide()
	for c in choice_box.get_children():
		c.queue_free()
	return result

func close() -> void:
	active = false
	choosing = false
	panel.hide()
	closed.emit()

func _show_line(line: String) -> void:
	text_label.text = line
	text_label.visible_ratio = 0.0
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(text_label, "visible_ratio", 1.0, line.length() / chars_per_second)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		if tween:
			tween.kill()
		_step.emit(-1)
	elif event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if choosing:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()      # attack confirms the highlighted button
		elif text_label.visible_ratio < 1.0:
			tween.kill()                    # first press finishes typing
			text_label.visible_ratio = 1.0
		else:
			_step.emit(0)                   # second press goes to the next line
