class_name DialogueManager
extends Node2D

static var instance: DialogueManager
static var r: DialogueRunner

@export var runner: DialogueRunner

@export_file("dia_*.txt") var autoloads: Array[String]

func _enter_tree() -> void:
	instance = self
	r = runner
	for file in autoloads:
		runner.prepare_dialogue(file)