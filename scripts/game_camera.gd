class_name GameCamera
extends Camera2D

static var instance: Camera2D = null

@export var set_instance: bool = false

func _enter_tree() -> void:
    if set_instance:
        instance = self