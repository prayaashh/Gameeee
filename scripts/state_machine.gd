class_name StateMachine
extends Node

@export var actor: CharacterBody2D
@export var initial_state: State

var current: State
var states := {}

func _ready() -> void:
	if actor == null:
		actor = get_parent() as CharacterBody2D
	if initial_state == null:
		initial_state = get_child(0) as State

	for child in get_children():
		if child is State:
			states[child.name] = child
			child.actor = actor
			child.machine = self
	await actor.ready
	change_state(initial_state.name)

func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current:
		current.handle_input(event)

func change_state(state_name: StringName) -> void:
	var next: State = states.get(state_name)
	if next == null or next == current:
		return
#	print("Changing to: ", state_name)
	var previous_name: StringName = current.name if current else &""
	if current:
		current.exit()
	current = next
	current.enter(previous_name)
