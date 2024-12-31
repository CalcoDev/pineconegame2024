class_name Spring1D
extends Object

var spring: float
var damp: float
var vel: float = 0.0
var target: float = 0.0

@warning_ignore("shadowed_variable")
func _init(spring: float, damping: float) -> void:
    self.spring = spring
    self.damp = damping

func tick(delta: float, position: float) -> float:
    var deceleration := delta * damp * vel
    if abs(vel) > abs(deceleration):
        vel -= deceleration
    else:
        vel = 0.0
    vel += delta * spring * (target - position)
    return position + delta * vel
