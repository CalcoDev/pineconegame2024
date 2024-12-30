class_name InteractableBody
extends Actor

@export_group("Physics")
@export var floor_friction := 400.0
@export var slope_friction := 350.0

@export var gravity_scale := 1.0
@export var max_fall := 300.0

func _physics_process(delta: float) -> void:
    velocity.y -= ProjectSettings.get_setting("physics/2d/default_gravity") * delta
    velocity.y = min(velocity.y, max_fall)
		
    velocity = move(velocity * delta, ) / delta

    if is_on_floor():
        velocity.x = move_toward(velocity.x, 0.0, floor_friction * delta)
    elif is_on_slope():
        # velocity.x = move_toward(velocity.x, 0.0, slope_friction * delta)
        var l := velocity.length()
        l = move_toward(l, 0.0, slope_friction * delta)
        velocity = velocity.normalized() * l
