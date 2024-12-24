class_name PlayerVelocityWobbler
extends Node2D

@export var min_rotation: float = -2.5 # Minimum rotation in degrees
@export var max_rotation: float = 2.5 # Maximum rotation in degrees
@export var wobble_frequency: float = 1.0 # How fast the wobble oscillates

var _time: float = 0.0
var _c: float = 0.0

func _process(delta: float):
	_time += delta
	if _time > wobble_frequency:
		_c = randf_range(min_rotation, max_rotation)
	var new_rotation = lerp_angle(rotation_degrees, _c, delta)
	rotation_degrees = new_rotation