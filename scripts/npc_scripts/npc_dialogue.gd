extends RefCounted

## A conversation for one NPC, read from a plain-text file so it can be written
## in Notepad instead of filling the Inspector with fields.
##
## Smallest possible file:
##
##     name: Dionysus
##
##     Stage 0: (default stage)
##         play: idle
##         speak: "Oh, so you have come"
##         ask: "Will you find my lantern?"
##         choices: "yes" -> 1, "no" -> 2
##
##     Stage 1:
##         play: talk
##         speak: "Thank you, traveller."
##         set: lantern_quest
##
## Full syntax: docs/NPC_DIALOGUE.md
## Anything after "#" on its own line is a comment. Indentation only needs to be
## a space or a tab; the amount does not matter.


## One stage of a conversation. Runs top to bottom: the animation, then the
## lines, then the question, then the flags, then the goto.
class Stage:
	var id := ""
	var animation := ""
	var lines: Array[String] = []
	var question := ""
	var choices: Array[Dictionary] = []      # [{"label": String, "target": String}]
	var sets: Array[String] = []
	var clears: Array[String] = []
	var gives: Array[String] = []            # weapons granted, e.g. ["sword"]
	var go_to := ""


## Speaker name written with "name:". Empty means "use the NPC's Name field".
var speaker := ""
## Entry rules, checked in order; the first one that matches picks the stage.
## [{"kind": String, "flag": String, "target": String}]
var entries: Array[Dictionary] = []
## Stage id (String) -> Stage
var stages: Dictionary = {}
var file_path := ""


## Reads and parses a dialogue file. Returns false (after warning) when the file
## is missing, unreadable, or contains no stages.
func read_file(path: String) -> bool:
	file_path = path
	if path.is_empty():
		return false
	if not FileAccess.file_exists(path):
		push_warning("Dialogue file not found: " + path)
		return false
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Dialogue file is empty or unreadable: " + path)
		return false
	parse(text)
	return not stages.is_empty()


func parse(source: String) -> void:
	source = source.replace("\r\n", "\n").replace("\r", "\n")
	if source.begins_with("\uFEFF"):
		source = source.substr(1)          # Notepad's UTF-8 BOM

	var current: Stage = null
	var number := 0
	for raw in source.split("\n"):
		number += 1
		var stripped := raw.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue

		var indented := raw.begins_with(" ") or raw.begins_with("\t")
		var pair := _split_key(stripped)
		var key: String = pair["key"]
		var value: String = pair["value"]

		if indented:
			if current == null:
				_warn(number, "command outside a stage: \"%s\"" % stripped)
			else:
				_parse_command(current, key, value, number)
			continue

		var lower := key.to_lower()
		if lower == "name":
			speaker = _clean(value)
		elif lower == "entry":
			_parse_entry(value, number)
		elif lower.begins_with("stage"):
			var id := key.substr(5).strip_edges()
			if id.is_empty():
				_warn(number, "a stage needs an id, e.g. \"Stage 0:\"")
				current = null
			else:
				if stages.has(id):
					_warn(number, "stage \"%s\" is defined twice" % id)
				current = Stage.new()
				current.id = id
				stages[id] = current
		else:
			_warn(number, "unknown setting \"%s\" (expected name, entry or Stage)" % key)


## Warns about typos the parser cannot catch on its own: stages that point at
## stages that do not exist, and animations the SpriteFrames does not have.
func validate(owner_name: String, sprite: AnimatedSprite2D) -> void:
	var label := owner_name if not owner_name.is_empty() else "NPC"
	if stages.is_empty():
		push_warning("%s: %s has no stages" % [label, file_path])
		return
	if not stages.has("0"):
		push_warning("%s: %s has no Stage 0 - it will start at \"%s\" instead" % [label, file_path, stages.keys()[0]])
	var knows_animations := sprite != null and sprite.sprite_frames != null
	for id in stages:
		var stage: Stage = stages[id]
		if knows_animations and not stage.animation.is_empty():
			if not sprite.sprite_frames.has_animation(StringName(stage.animation)):
				push_warning("%s: stage \"%s\" plays \"%s\", which is not in the SpriteFrames" % [label, id, stage.animation])
		if not stage.go_to.is_empty() and not stages.has(stage.go_to):
			push_warning("%s: stage \"%s\" goes to \"%s\", which does not exist" % [label, id, stage.go_to])
		for choice in stage.choices:
			var target := str(choice.get("target", ""))
			if not target.is_empty() and not stages.has(target):
				push_warning("%s: stage \"%s\" has a choice going to \"%s\", which does not exist" % [label, id, target])
	for rule in entries:
		var target := str(rule.get("target", ""))
		if not stages.has(target):
			push_warning("%s: an entry rule goes to \"%s\", which does not exist" % [label, target])


# --- parsing helpers ----------------------------------------------------------

func _parse_command(stage: Stage, key: String, value: String, number: int) -> void:
	match key.to_lower():
		"play", "animation", "animate":
			stage.animation = _clean(value)
		"speak", "say", "line":
			stage.lines.append(_clean(value))
		"ask", "question":
			stage.question = _clean(value)
		"choices", "options":
			stage.choices = _parse_choices(value, number)
		"set":
			for flag in _clean_list(value):
				stage.sets.append(flag)
		"unset", "clear":
			for flag in _clean_list(value):
				stage.clears.append(flag)
		"give", "weapon":
			for weapon in _clean_list(value):
				stage.gives.append(weapon)
		"goto", "next":
			stage.go_to = _clean(value)
		"end", "stop":
			stage.go_to = ""
		_:
			_warn(number, "unknown command \"%s\"" % key)


func _parse_choices(value: String, number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part in _split_list(value):
		var text := part.strip_edges()
		if text.is_empty():
			continue
		var target := ""
		var arrow := text.find("->")
		if arrow != -1:
			target = _clean(text.substr(arrow + 2))
			text = text.substr(0, arrow).strip_edges()
		result.append({"label": _clean(text), "target": target})
	if result.is_empty():
		_warn(number, "choices needs at least one option")
	return result


func _parse_entry(value: String, number: int) -> void:
	var text := value.strip_edges()
	var target := ""
	var arrow := text.find("->")
	if arrow != -1:
		target = _clean(text.substr(arrow + 2))
		text = text.substr(0, arrow).strip_edges()
	if target.is_empty():
		_warn(number, "entry needs a target, e.g. \"entry: flag my_flag -> 2\"")
		return
	var words := text.split(" ", false)
	var kind := "always"
	var flag := ""
	if not words.is_empty():
		kind = str(words[0]).to_lower()
	if words.size() > 1:
		flag = str(words[1])
	match kind:
		"flag", "has", "noflag", "not", "always", "else", "default":
			entries.append({"kind": kind, "flag": flag, "target": target})
		_:
			_warn(number, "unknown entry condition \"%s\"" % kind)


## Splits "key: value" at the first colon.
func _split_key(line: String) -> Dictionary:
	var colon := line.find(":")
	if colon == -1:
		return {"key": line.strip_edges(), "value": ""}
	return {
		"key": line.substr(0, colon).strip_edges(),
		"value": line.substr(colon + 1).strip_edges(),
	}


## Splits a comma-separated list, ignoring commas inside quotes.
func _split_list(value: String) -> Array[String]:
	var parts: Array[String] = []
	var buffer := ""
	var quote := ""
	for i in value.length():
		var c := value[i]
		if quote != "":
			if c == quote:
				quote = ""
			buffer += c
		elif c == "\"" or c == "'":
			quote = c
			buffer += c
		elif c == ",":
			parts.append(buffer)
			buffer = ""
		else:
			buffer += c
	parts.append(buffer)
	return parts


func _clean_list(value: String) -> Array[String]:
	var result: Array[String] = []
	for part in _split_list(value):
		var cleaned := _clean(part)
		if not cleaned.is_empty():
			result.append(cleaned)
	return result


## Strips surrounding quotes and turns a literal \n into a line break.
func _clean(value: String) -> String:
	var text := value.strip_edges()
	if text.length() >= 2:
		var first := text.substr(0, 1)
		var last := text.substr(text.length() - 1, 1)
		if (first == "\"" and last == "\"") or (first == "'" and last == "'"):
			text = text.substr(1, text.length() - 2)
	return text.replace("\\n", "\n")


func _warn(number: int, message: String) -> void:
	var where := file_path if not file_path.is_empty() else "dialogue"
	push_warning("%s:%d: %s" % [where, number, message])
