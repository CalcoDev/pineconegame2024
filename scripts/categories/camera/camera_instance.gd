@tool
class_name CameraInstance
extends Node2D

class InterpolationData:
	var curr := Transform2D()
	var prev := Transform2D()
	var tick := 0xffffffff

@export var debug_draw := true

@export var zoom: Vector2 = Vector2.ONE:
	set(value):
		zoom = value
		var v := Vector2.ONE / zoom
		if not _zoom_inverse.is_equal_approx(v):
			_zoom_inverse = v
var _zoom_inverse: Vector2:
	set(value):
		_zoom_inverse = value
		var v := Vector2.ONE / _zoom_inverse
		if not zoom.is_equal_approx(v):
			zoom = v

@export var _follow_target: Node2D

var _interp_data := InterpolationData.new()
var _group_name: String = ""
var _canvas_group_name: String = ""
var _viewport: Viewport

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_viewport = get_viewport()
			_group_name = "__cameras_" + str(_viewport.get_viewport_rid().get_id())
			_canvas_group_name = "__cameras_c" + str(get_canvas().get_id())
			add_to_group(_group_name)
			add_to_group(_canvas_group_name)
		NOTIFICATION_EXIT_TREE:
			_group_name = "__cameras_" + str(_viewport.get_viewport_rid().get_id())
			_canvas_group_name = "__cameras_c" + str(get_canvas().get_id())
			remove_from_group(_group_name)
			remove_from_group(_canvas_group_name)
		NOTIFICATION_TRANSFORM_CHANGED:
			if is_physics_interpolated_and_enabled():
				_update_interpolation_data()
				_interp_data.curr = _get_camera_transform()
		NOTIFICATION_PHYSICS_PROCESS:
			if is_physics_interpolated_and_enabled():
				_update_interpolation_data()
				_interp_data.curr = _get_camera_transform()

func _enter_tree() -> void:
	set_physics_process(true)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()
		global_position = _follow_target.global_position

		var half_size := _get_camera_size() * 0.5
		var t: Transform2D
		if is_physics_interpolated_and_enabled():
			t = _interp_data.prev.interpolate_with(_interp_data.curr, Engine.get_physics_interpolation_fraction())
		else:
			t = _get_camera_transform()
		get_viewport().canvas_transform = t
		var screen_center := t.basis_xform(half_size) - (half_size)
		# Ensure compat with normal camera nodes
		get_tree().call_group(_group_name, "_camera_moved", t, Vector2.ZERO, screen_center)

func _draw() -> void:
	if not debug_draw and not Engine.is_editor_hint():
		return
	# var r := rotation
	# rotation = 0.0
	draw_rect(_get_camera_rect(), Color("ff0000ff"), false, 2)
	# rotation = r

func _get_camera_transform() -> Transform2D:
		var t := Transform2D()
		t = t.scaled(_zoom_inverse)
		t = t.rotated_local(rotation)
		t.origin = -((_get_camera_size() * 0.5).rotated(rotation) / zoom) + global_position
		return t.affine_inverse()

func _get_camera_size() -> Vector2:
	return _viewport.get_visible_rect().size

func _update_interpolation_data() -> void:
	var tick := Engine.get_physics_frames()
	if _interp_data.tick != tick:
		_interp_data.prev = _interp_data.curr
		_interp_data.tick = tick

func _get_camera_rect() -> Rect2:
	var s := _get_camera_size() / zoom
	return Rect2(s * -0.5, s)