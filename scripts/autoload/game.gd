class_name Game
extends Node

static var instance: Game

func _enter_tree() -> void:
    instance = self

func hitstop(duration: float, time_scale: float = 0.001) -> void:
    var t := Engine.time_scale
    Engine.time_scale = time_scale
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = t