class_name Audio
extends Node

static var instance: Audio
static var map: Dictionary:
	get:
		var d = {}
		for child in instance.get_children():
			d[child.name] = child
		return d

func _enter_tree() -> void:
	instance = self