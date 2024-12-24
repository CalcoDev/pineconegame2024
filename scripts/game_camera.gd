class_name GameCamera
extends Camera2D

static var instance: GameCamera = null

@export var set_instance: bool = false
var phantom_camera: PhantomCamera2D

var top_left_corner: Vector2:
    get():
        return self.global_position - Vector2(160, 90)

func _enter_tree() -> void:
    if set_instance:
        instance = self

func _process(_delta: float) -> void:
    # if Input.is_action_just_pressed("dia_opt_select"):
        # shake(5.0, 50.0, 15.0, 0.25)
    pass

func shake(freq: float, ampl: float, rot_ampl: float, duration: float) -> void:
    var timer := 0.0
    while timer <= duration:
        await get_tree().process_frame
        var curr_ampl := lerpf(ampl, ampl * 0.25, timer / duration)
        var curr_rot_ampl := lerpf(rot_ampl, rot_ampl * 0.25, timer / duration)
        phantom_camera.noise.frequency = freq
        phantom_camera.noise.amplitude = curr_ampl
        phantom_camera.noise.rotational_multiplier = curr_rot_ampl / curr_ampl
        timer += get_process_delta_time()
    phantom_camera.noise.frequency = 0.0
    phantom_camera.noise.amplitude = 0.0
    phantom_camera.noise.rotational_multiplier = 1.0