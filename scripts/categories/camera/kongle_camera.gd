@tool
class_name KongleCamera
extends Node2D

#region Types
class InterpolationData:
	var curr := Transform2D()
	var prev := Transform2D()
	var tick := 0xffffffff

enum ProcessEvent {
	PROCESS,
	PHYSICS
}

#endregion

#region Vars - Transform
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

#endregion

#region Vars - Bounds
# @export var limits := Vector4(10000, -10000, -10000, 10000)
@export var enable_limits := true

@export var limit_left := -10000.0
@export var limit_right := 10000.0
@export var limit_top := -10000.0
@export var limit_bottom := 10000.0

@export_node_path("CollisionShape2D") var bounds_target := NodePath(""):
	set(value):
		bounds_target = value
		if not is_node_ready():
			await ready
		var node := get_node_or_null(bounds_target)
		if is_instance_valid(node):
			if node is CollisionShape2D:
				if node.shape == null:
					printerr("Bounds target Collision Shape missing Shape! ", node.name)
					_reset_bounds()
					_bounds_node = null
					return
			else:
				printerr("Bounds Target is unknown type of node!")
				return
		elif bounds_target == NodePath(""):
			_reset_bounds()
			_bounds_node = null
		else:
			printerr("Bounds Target cannot be null!")
			return
		_bounds_node = node
		_update_bounds()
	get():
		if not bounds_target:
			return NodePath("")
		else:
			return bounds_target
var _bounds_node: CollisionShape2D
#endregion

#endregion

#region Lifecycle
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
			
			set_notify_transform(true)

			if bounds_target == NodePath(""):
				bounds_target = NodePath("")
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
		# could use internal instead
		NOTIFICATION_PROCESS:
			if Engine.is_editor_hint():
				return
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
			var inv_t := _get_camera_transform().affine_inverse()
			var size := _get_camera_size()

			var points: Array[Vector2] = [
				inv_t * Vector2(0.0, 0.0),
				inv_t * Vector2(size.x, 0.0),
				inv_t * Vector2(size),
				inv_t * Vector2(0.0, size.y),
			]

			var inv_glob := global_transform.affine_inverse()
			for i in 4:
				draw_line(inv_glob * points[i], inv_glob * points[(i + 1) % 4], 0xff0000ff, 2)

#endregion

#region Transform Helpers
func _update_process_events() -> void:
	if _should_interpolate():
		set_process_internal(true)
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

var _cam_screen_center := Vector2.ZERO
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
		_cam_screen_center = t.affine_inverse() * hs_size
	else:
		t = _get_camera_transform()
	get_viewport().canvas_transform = t
	# Ensure compat with normal camera nodes
	var adj_screen_pos := _cam_screen_center - hs_size
	get_tree().call_group(_group_name, &"_camera_moved", t, hs_size, adj_screen_pos)

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

	var cam_pos = global_position
	
	var cam_size := _get_camera_size()
	var cam_offset := cam_size * 0.5 * _zoom_inverse
	var cam_rect := Rect2(-cam_offset + cam_pos, cam_size * _zoom_inverse)

	# cam_pos.x = cam_pos.x + cam_size.x * 0.5 * _zoom_inverse.x
	# cam_pos.y = cam_pos.y + cam_size.y * 0.5 * _zoom_inverse.y
	
	# stuff before rotations
	if enable_limits:
		if cam_rect.position.x < _limits[SIDE_LEFT]:
			cam_pos.x -= cam_rect.position.x - _limits[SIDE_LEFT]
		if cam_rect.position.x + cam_rect.size.x > _limits[SIDE_RIGHT]:
			cam_pos.x -= cam_rect.position.x + cam_rect.size.x - _limits[SIDE_RIGHT]
		if cam_rect.position.y < _limits[SIDE_TOP]:
			cam_pos.y -= cam_rect.position.y - _limits[SIDE_TOP]
		if cam_rect.position.y + cam_rect.size.y > _limits[SIDE_BOTTOM]:
			cam_pos.y -= cam_rect.position.y + cam_rect.size.y - _limits[SIDE_BOTTOM]
	
	# stuff after rotations
	var cam_offset_rot := cam_offset.rotated(rotation)
	var cam_rect_rot := Rect2(-cam_offset_rot + cam_pos, cam_size * _zoom_inverse)
	if enable_limits:
		if cam_rect_rot.position.x < _limits[SIDE_LEFT]:
			cam_rect_rot.position.x = _limits[SIDE_LEFT]
		if cam_rect_rot.position.x + cam_rect_rot.size.x > _limits[SIDE_RIGHT]:
			cam_rect_rot.position.x = _limits[SIDE_RIGHT] - cam_rect_rot.size.x
		if cam_rect_rot.position.y < _limits[SIDE_TOP]:
			cam_rect_rot.position.y = _limits[SIDE_TOP]
		if cam_rect_rot.position.y + cam_rect_rot.size.y > _limits[SIDE_BOTTOM]:
			cam_rect_rot.position.y = _limits[SIDE_BOTTOM] - cam_rect_rot.size.y

	var t := Transform2D()
	t = t.scaled(_zoom_inverse)
	t = t.rotated_local(rotation)
	t.origin = cam_rect_rot.position

	_cam_screen_center = t * (cam_size * 0.5)

	return t.affine_inverse()

func _get_camera_size() -> Vector2:
	if _is_inside_editor():
		return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
	return _viewport.get_visible_rect().size

func _update_interpolation_data() -> void:
	var tick := Engine.get_physics_frames()
	if _interp_data.tick != tick:
		_interp_data.prev = _interp_data.curr
		_interp_data.tick = tick

#endregion

#region Limit Helpers

func _reset_bounds() -> void:
	_limits[SIDE_RIGHT] = limit_right
	_limits[SIDE_TOP] = limit_top
	_limits[SIDE_LEFT] = limit_left
	_limits[SIDE_BOTTOM] = limit_bottom

var _limits := Vector4.ZERO
func _update_bounds() -> void:
	var rect := Rect2()
	if not is_instance_valid(_bounds_node):
		_limits[SIDE_RIGHT] = limit_right
		_limits[SIDE_TOP] = limit_top
		_limits[SIDE_LEFT] = limit_left
		_limits[SIDE_BOTTOM] = limit_bottom
	elif _bounds_node is CollisionShape2D:
		var shape := _bounds_node.shape
		if not shape:
			return
		var shape_size = shape.get_rect().size
		var shape_position = _bounds_node.global_position + shape.get_rect().position
		rect = Rect2(shape_position, shape_size)

		_limits[SIDE_LEFT] = roundi(rect.position.x)
		_limits[SIDE_RIGHT] = roundi(rect.position.x + rect.size.x)
		_limits[SIDE_TOP] = roundi(rect.position.y)
		_limits[SIDE_BOTTOM] = roundi(rect.position.y + rect.size.y)

#endregion