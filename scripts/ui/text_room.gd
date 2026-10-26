extends Node2D

## A pitch-black screen with centred text and no player.
##
## Text is read from a .txt file (Inspector: Text File). If that file is
## missing or empty, the inline "Text" field is used instead. Lines starting
## with '#' in the file are ignored, blank lines are kept, and BBCode works.
##
## The room has no player, so nothing here can consume a doorway spawn
## request — _ready() clears it to keep the next room's spawn honest.
##
## Leave "Next Scene" empty to hold the screen forever (a lore card).
## Set it to continue on Space / E / gamepad A once the text is fully shown.

@export_group("Text")
## Plain-text file to show. Takes priority over the inline text below.
@export_file("*.txt") var text_file := ""
## Used when no file is set (or the file cannot be read).
@export_multiline var text := ""
## Typewriter speed. High values show the text almost at once.
@export_range(0.0, 400.0, 1.0) var chars_per_second := 30.0

@export_group("Leaving")
## Scene to load after the text is read. Empty = stay on this screen.
@export_file("*.tscn") var next_scene := ""
## Entrance marker in the next room (an "Entrances" child of its root).
@export var next_entrance := "Spawn"
## Move on by itself this many seconds after the text finishes. 0 = wait for input.
@export var auto_advance_seconds := 0.0

@onready var text_label: RichTextLabel = $CanvasLayer/Text
@onready var hint: Label = $CanvasLayer/Hint

var _tween: Tween
var _leaving := false


func _ready() -> void:
	# No player means no one else will consume this; a stale request would make
	# the next room teleport to a marker here instead of its own spawn.
	GameState.pending_spawn = {}

	var body := _read_text()
	text_label.text = body
	text_label.visible_ratio = 0.0
	hint.hide()

	if body.strip_edges().is_empty():
		push_warning("Text room has no text: %s" % scene_file_path)
		_on_revealed()
		return

	if chars_per_second <= 0.0:
		text_label.visible_ratio = 1.0
		_on_revealed()
		return

	var seconds := body.length() / chars_per_second
	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, seconds)
	_tween.finished.connect(_on_revealed)


func _read_text() -> String:
	var path := text_file.strip_edges()
	if path != "":
		if FileAccess.file_exists(path):
			var kept: PackedStringArray = []
			for raw in FileAccess.get_file_as_string(path).split("\n"):
				if raw.strip_edges().begins_with("#"):
					continue
				kept.append(raw)
			return "\n".join(kept).strip_edges()
		push_warning("Text room file not found: " + path)
	return text.strip_edges()


## Text is fully on screen and the player may now move on.
func _on_revealed() -> void:
	if next_scene.strip_edges() == "":
		return
	hint.show()
	if auto_advance_seconds > 0.0:
		await get_tree().create_timer(auto_advance_seconds).timeout
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if next_scene.strip_edges() == "" or _leaving:
		return
	if not (event.is_action_pressed("attack") or event.is_action_pressed("interact")):
		return
	get_viewport().set_input_as_handled()

	# First press completes the typing instead of skipping the whole screen.
	if _tween and _tween.is_running():
		_tween.kill()
		text_label.visible_ratio = 1.0
		_on_revealed()
		return

	_advance()


func _advance() -> void:
	var target := next_scene.strip_edges()
	if _leaving or target == "":
		return
	_leaving = true
	GameState.go_to_room(target, next_entrance)
