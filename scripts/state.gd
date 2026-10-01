class_name State
extends Node

var actor: CharacterBody2D
var machine: StateMachine

func enter(_previous: StringName) -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass
