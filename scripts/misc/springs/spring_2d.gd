class_name Spring2D
extends Object

var spring: float
var damp: float
var vel := Vector2.ZERO
var target := Vector2.ZERO

@warning_ignore("shadowed_variable")
func _init(spring: float, damping: float) -> void:
    self.spring = spring
    self.damp = damping

func tick(delta: float, position: Vector2) -> Vector2:
    var deceleration := delta * damp * vel
    if vel.length_squared() > deceleration.length_squared():
        vel -= deceleration
    else:
        vel = Vector2.ZERO
    vel += delta * spring * (target - position)
    return position + delta * vel
