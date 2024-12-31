class_name Spring2D
extends Object

var spring: float
var damp: float
var velocity: Vector2
var target := Vector2.ZERO

@warning_ignore("shadowed_variable")
func _init(spring: float, damp: float, velocity := Vector2.ZERO) -> void:
    self.spring = spring
    self.damp = damp
    self.velocity = velocity

func tick(delta: float, position: Vector2) -> Vector2:
    var deceleration := delta * damp * velocity
    if velocity.length_squared() > deceleration.length_squared():
        velocity -= deceleration
    else:
        velocity = Vector2.ZERO
    velocity += delta * spring * (target - position)
    return position + delta * velocity

func is_approx_done(position: Vector2, epsilon: float = 0.001) -> bool:
    var p := (position - target).length_squared() < epsilon * epsilon
    var v := velocity.length_squared() < epsilon * epsilon
    return p and v