@tool
extends Area2D

#@export var coll: CollisionShape2D
#@export var camera: PhantomCamera2D

@export var coll: CollisionShape2D:
    get():
        if _coll != null and is_instance_valid(_coll):
            return _coll
        _coll = find_children("*", "CollisionShape2D", false)[0]
        return _coll
    set(value):
        _coll = value
var _coll: CollisionShape2D = null

@export var camera: PhantomCamera2D:
    get():
        if _camera != null and is_instance_valid(_coll):
            return _camera
        _camera = find_children("*", "PhantomCamera2D", false)[0]
        return _camera
    set(value):
        _camera = value
var _camera: PhantomCamera2D = null

var _old_priority: int = 0
@export var auto_set_follow_target: bool = true

@export_group("Buttons lmfao")
@export var center_area: bool = false:
    set(value):
        center_area = false
        var diff := self.global_position - coll.global_position
        self.global_position = coll.global_position
        coll.global_position += diff
@export var setup: bool = false:
    set(value):
        setup = false
        _setup()

func _ready() -> void:
    self.body_entered.connect(area_body_entered)
    self.body_exited.connect(area_body_exited)

func area_body_entered(body) -> void:
    if body != Player.instance:
        return
    # print("Player entered room: ", self.name)
    _old_priority = camera.priority
    camera.priority = 1
    if auto_set_follow_target:
        camera.follow_target = body

func area_body_exited(body) -> void:
    if body != Player.instance:
        return
    # print("Player left room: ", self.name)
    camera.priority = _old_priority
    if auto_set_follow_target:
        camera.follow_target = null

func _get_configuration_warnings() -> PackedStringArray:
    var warnings = []
    if coll == null:
        warnings.append("Please add a collision shape to room.")
    if camera == null:
        warnings.append("Please add a phantom camera to this room.")
    if warnings.size() > 0:
        return warnings
    _setup()
    return warnings

func _setup() -> void:
    camera.limit_target = camera.get_path_to(coll)