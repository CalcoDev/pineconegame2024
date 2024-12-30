@tool
class_name CameraInstance
extends Node2D

class InterpolationData:
	var curr := Transform2D()
	var prev := Transform2D()
	var tick := 0xffffffff

enum ProcessEvent {
	PROCESS,
	PHYSICS
}

@export var enable_ingame_draw := false:
	set(value):
		enable_ingame_draw = value
		queue_redraw()
@export var enable_editor_draw := true:
	set(value):
		enable_editor_draw = value
		queue_redraw()

@export var enable_physics_interpolation := false:
	set(value):
		enable_physics_interpolation = value
		_update_process_events()
@export var process_event: ProcessEvent = ProcessEvent.PHYSICS:
	set(value):
		if value == process_event:
			return
		process_event = value
		_update_process_events()

@export var zoom := Vector2.ONE:
	set(value):
		zoom = value
		var v := Vector2.ONE / zoom
		if not _zoom_inverse.is_equal_approx(v):
			_zoom_inverse = v
		queue_redraw()
var _zoom_inverse := Vector2.ONE:
	set(value):
		_zoom_inverse = value
		var v := Vector2.ONE / _zoom_inverse
		if not zoom.is_equal_approx(v):
			zoom = v
		queue_redraw()

var _interp_data := InterpolationData.new()
var _group_name: String = ""
var _canvas_group_name: String = ""
var _viewport: Viewport

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if not is_inside_tree():
				return
			_viewport = get_viewport()
			_group_name = "__cameras_" + str(_viewport.get_viewport_rid().get_id())
			_canvas_group_name = "__cameras_c" + str(get_canvas().get_id())
			add_to_group(_group_name)
			add_to_group(_canvas_group_name)

			_update_process_events()
			_update_transform()

			if _should_interpolate():
				_interp_data.curr = _get_camera_transform()
				_interp_data.prev = _interp_data.curr
		NOTIFICATION_EXIT_TREE:
			_group_name = "__cameras_" + str(_viewport.get_viewport_rid().get_id())
			_canvas_group_name = "__cameras_c" + str(get_canvas().get_id())
			remove_from_group(_group_name)
			remove_from_group(_canvas_group_name)
		NOTIFICATION_TRANSFORM_CHANGED:
			if not _should_interpolate() or _is_inside_editor():
				_update_transform()
			if _should_interpolate():
				_update_interpolation_data()
				_interp_data.curr = _get_camera_transform()
		NOTIFICATION_PROCESS:
			_update_transform()
		NOTIFICATION_PHYSICS_PROCESS:
			if _should_interpolate():
				_update_interpolation_data()
				_interp_data.curr = _get_camera_transform()
			else:
				_update_transform()
		NOTIFICATION_DRAW:
			if not is_inside_tree() or not _should_redraw():
				return
			draw_rect(_get_camera_rect(), Color("ff0000ff"), false, 2)

func _update_process_events() -> void:
	if _should_interpolate():
		set_process(true)
		set_physics_process(true)
	elif _is_inside_editor():
		set_process_internal(false)
		set_physics_process_internal(false)
	else:
		if process_event == ProcessEvent.PROCESS:
			set_process(true)
			set_physics_process(false)
		else:
			set_process(false)
			set_physics_process(true)

func _update_transform() -> void:
	if not is_inside_tree() or not _viewport:
		return
	
	if _is_inside_editor():
		queue_redraw()
		return
	if _should_redraw():
		queue_redraw()
		
	var hs_size := _get_camera_size() * 0.5
	var t: Transform2D
	if _should_interpolate():
		t = _interp_data.prev.interpolate_with(_interp_data.curr, Engine.get_physics_interpolation_fraction())
	else:
		t = _get_camera_transform()
	get_viewport().canvas_transform = t
	var screen_center := t.basis_xform(hs_size) - (hs_size)
	# Ensure compat with normal camera nodes
	get_tree().call_group(_group_name, "_camera_moved", t, Vector2.ZERO, screen_center)

func _is_inside_editor() -> bool:
	return Engine.is_editor_hint() and is_part_of_edited_scene()

func _should_redraw() -> bool:
	return (Engine.is_editor_hint() and enable_editor_draw) \
		or (not Engine.is_editor_hint() and enable_ingame_draw)

func _should_interpolate() -> bool:
	return is_physics_interpolated_and_enabled() and enable_physics_interpolation

func _get_camera_transform() -> Transform2D:
	if not get_tree():
		return Transform2D()
	
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