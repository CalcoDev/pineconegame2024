class_name Player
extends RigidBody2D

static var instance: Player = null

@export_group("References")
#@export var _rb: RigidBody2D
@export var _visuals: Node2D
@export var _line: Line2D
@export var _gc: Area2D

@export_group("Movement")
@export var roll_speed: float = 2.0
@export var jump_force: float = 2.0

@export_group("Yeet Settings")
@export var has_yeet: bool = true
@export var yeet_max_dist: float = 100.0
@export var yeet_display_max_dist: float = 25.0
@export var yeet_max_force: float = 300.0

var is_ground: bool = false
var was_ground: bool = false

# yeeting
var _is_yeet: bool = false
var _was_yeet: bool = false
var _yeet_drag_start: Vector2
var _yeet_drag_end: Vector2

var _yeeted: bool = false

func _enter_tree() -> void:
    if instance == null or not is_instance_valid(instance):
        instance = self
    else:
        push_warning("ERROR: Somehow 2 player instances at same time?")
    _line.top_level = true
    _gc.top_level = true
    _gc.body_entered.connect(_entered_ground)
    _gc.body_exited.connect(_exited_ground)
    #_rb.top_level = true

func _ready() -> void:
    _visuals.scale = Vector2.ONE * 0.75

func _process(_detal: float) -> void:
    was_ground = is_ground
    is_ground = _is_ground_coll
    
    var _rb = self
    _line.global_rotation = 0.0
    
    if has_yeet and Input.is_action_just_pressed("yeet"):
            _is_yeet = true
            _yeet_drag_start = get_global_mouse_position()
            # TODO(calco): Enable visuals
    
    if not _was_yeet and _is_yeet:
        _line.visible = true
    if not _is_yeet and _was_yeet:
        _line.visible = false

    # $"Visuals".rotation = linear_velocity.angle()
    if _is_yeet:
        _yeet_drag_end = get_global_mouse_position()
        var offset = _yeet_drag_end - _yeet_drag_start
        
        var angle = -offset.angle_to(Vector2.UP)
        # TODO(calco): update visuals angle accordingly
        
        var dist = offset.length()
        var t = minf(dist / yeet_max_dist, 1.0)
        var display_dist = 8.0 + t * yeet_display_max_dist
        # TODO(calco): Update visuals distance accordingly
        
        _line.set_point_position(0, _yeet_drag_start)
        _line.set_point_position(1, _yeet_drag_end)
        if Input.is_action_just_released("yeet"):
            _was_yeet = true
            _is_yeet = false
            var dir = -offset.normalized()
            # TODO(calco): Disable visuals
            # TODO(calco): Apply force and stuff
            _rb.linear_velocity = Vector2.ZERO
            _rb.apply_impulse(dir * t * yeet_max_force)

            _yeeted = true
        else:
            _was_yeet = true
    else:
        if _rb.linear_velocity.length_squared() < 0.025:
            _yeeted = false
        _was_yeet = _is_yeet

    # handle normal movenet
    var inp_x := Input.get_axis("walk_left", "walk_right")
    # self.linear_velocity.x = inp_x * roll_speed

    if Input.is_action_just_pressed("jump"):
        pass
    if Input.is_action_just_pressed("fall") and is_ground:
        self.global_position.y += 1

var _is_ground_coll := false
var _grounds: Array = [] # faster for smaller values lmfao
func _entered_ground(body: Node2D) -> void:
    var idx := _grounds.find(body)
    if idx != -1:
        return
    _grounds.append(body)
    _is_ground_coll = true

func _exited_ground(body: Node2D) -> void:
    var idx := _grounds.find(body)
    if idx == -1:
        return
    _grounds.remove_at(idx)
    if _grounds.size() == 0:
        _is_ground_coll = false