extends Node2D

@export var normal: bool = true

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PHYSICS_PROCESS:
			global_position = get_parent().global_position.round()
		NOTIFICATION_PROCESS:
			global_position = get_parent().global_position.round()

func _ready() -> void:
	set_physics_process(true)
	set_process(true)