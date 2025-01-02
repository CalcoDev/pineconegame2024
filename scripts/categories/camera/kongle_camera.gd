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

static var instance: KongleCamera = null:
	get():
		if instance != null and (not is_instance_valid(instance) or not instance.is_inside_tree()):
			instance = null
		return instance
@export var active: bool:
	set(value):
		print("setting active to ", value)
		active = value
		if not _is_inside_editor() and active and instance != self:
			if is_instance_valid(instance) and instance.is_inside_tree():
				instance.active = false
				print("does this fucker run")
			instance = self

@warning_ignore("shadowed_variable")
func _await_process_event(process_event: ProcessEvent) -> void:
	if process_event == ProcessEvent.PROCESS:
		await get_tree().process_frame
	else:
		await get_tree().physics_frame

@warning_ignore("shadowed_variable")
func _get_process_event_delta(process_event: ProcessEvent) -> float:
	if process_event == ProcessEvent.PROCESS:
		return get_process_delta_time()
	return get_physics_process_delta_time()

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

@export var enable_pixel_snap := false

var _interp_data := InterpolationData.new()
var _group_name: String = ""
var _canvas_group_name: String = ""
var _viewport: Viewport

func get_screen_center() -> Vector2:
	return _cam_screen_center

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
		return bounds_target if bounds_target else NodePath("")
var _bounds_node: CollisionShape2D
#endregion

#region Vars - Follows
@export_node_path("Node2D") var follow_target := NodePath(""):
	set(value):
		follow_target = value
		if not is_node_ready():
			await ready
		var node := get_node_or_null(follow_target)
		if is_instance_valid(node):
			if node is Node2D:
				_follow_node = node
			else:
				printerr("Follow Target is of an unsupported type!")
				return
		elif follow_target == NodePath(""):
			_follow_node = null
		else:
			printerr("Follow Target cannot be null!")
		queue_redraw()
	get():
		return follow_target if follow_target else NodePath("")
var _follow_node: Node2D
#endregion

#region Shake API
signal on_shake_begin()
signal on_shake_end()

# var _shake_transform_offset := Transform2D()
var _shake_pos_offset := Vector2.ZERO
var _shake_rot_offset := 0.0
var _shake_scale := Vector2.ONE
var _is_shaking := false

var _shake_coro: Coroutine
var _noise := FastNoiseLite.new()

@warning_ignore("shadowed_global_identifier", "shadowed_variable")
func shake_noise(freq: float, ampl: float, duration: float, lerp: bool, process_event: ProcessEvent) -> void:
	await _shake_handler(_shake_noise_coro.bind(freq, ampl, duration, lerp, process_event))

@warning_ignore("shadowed_global_identifier", "shadowed_variable")
func shake_spring(velocity: Vector2, spring: float, damp: float, process_event: ProcessEvent) -> void:
	await _shake_handler(_shake_spring_coro.bind(velocity, spring, damp, process_event))

@warning_ignore("shadowed_global_identifier", "shadowed_variable")
func _shake_spring_coro(ctx: Coroutine.Ctx, velocity: Vector2, spring: float, damp: float, process_event: ProcessEvent) -> void:
	var s := Spring2D.new(spring, damp, velocity)
	var offset := Vector2.ZERO
	while not s.is_approx_done(offset, 0.001):
		if not ctx.is_valid() or not is_instance_valid(self) or not is_inside_tree():
			return
		await _await_process_event(process_event)
		offset = s.tick(_get_process_event_delta(process_event), offset)
		_shake_pos_offset = offset

@warning_ignore("shadowed_global_identifier", "shadowed_variable")
func _shake_noise_coro(ctx: Coroutine.Ctx, freq: float, ampl: float, duration: float, lerp: bool, process_event: ProcessEvent) -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var timer := 0.0
	while timer <= duration:
		if not ctx.is_valid() or not is_instance_valid(self) or not is_inside_tree():
			return
		await _await_process_event(process_event)
		
		var curr_ampl := lerpf(ampl, 0.0, timer / duration) if lerp else ampl
		_noise.frequency = freq

		var x_off := _noise.get_noise_2d(timer * freq, 0.0) * curr_ampl
		var y_off := _noise.get_noise_2d(0.0, timer * freq) * curr_ampl

		_shake_pos_offset = Vector2(x_off, y_off)
		# var curr_rot_ampl := lerpf(rot_ampl, rot_ampl * 0.25, timer / duration) if lerp else 

		timer += _get_process_event_delta(process_event)

func _shake_handler(new_callable: Callable) -> void:
	if _is_shaking and Coroutine.is_instance_valid(_shake_coro):
		_shake_coro.stop()
	if not _is_shaking:
		on_shake_begin.emit()
		_is_shaking = true
	_shake_coro = Coroutine.make_single(true, new_callable)
	await _shake_coro.run()
	_reset_shake()
	_is_shaking = false
	on_shake_end.emit()

func _reset_shake() -> void:
	_shake_pos_offset = Vector2.ZERO
	_shake_rot_offset = 0.0
	_shake_scale = Vector2.ONE

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

			if active and instance == null:
				active = true # auto set

			_reset_shake()
			_update_process_events()
			_update_transform()

			if _should_interpolate():
				_interp_data.curr = _get_camera_transform()
				_interp_data.prev = _interp_data.curr
			
			set_notify_transform(true)

			if bounds_target == NodePath(""):
				bounds_target = NodePath("")
		NOTIFICATION_EXIT_TREE:
			active = false

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
			# print("camera")
			# print("camera")
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
		# set_process_internal(true)
		set_process(true)
		set_physics_process(true)
	elif _is_inside_editor():
		# set_process_internal(false)
		# set_physics_process_internal(false)
		pass
	else:
		if process_event == ProcessEvent.PROCESS:
			set_process(true)
			set_physics_process(false)
		else:
			set_process(false)
			set_physics_process(true)

var __last_interp_pos := Vector2.ZERO

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
	# __last_interp_pos = t.affine_inverse().origin + hs_size * _zoom_inverse
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

	if is_instance_valid(_follow_node):
		global_position = _follow_node.global_position
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
	cam_pos += _shake_pos_offset

	var camera_rot := global_rotation + _shake_rot_offset
	var cam_offset_rot := cam_offset.rotated(camera_rot)
	var cam_rect_rot := Rect2(-cam_offset_rot + cam_pos, cam_size * _zoom_inverse)
	# todo calco this is kinda broken lmfao
	# if enable_limits:
	# 	if cam_rect_rot.position.x < _limits[SIDE_LEFT]:
	# 		cam_rect_rot.position.x = _limits[SIDE_LEFT]
	# 	if cam_rect_rot.position.x + cam_rect_rot.size.x > _limits[SIDE_RIGHT]:
	# 		cam_rect_rot.position.x = _limits[SIDE_RIGHT] - cam_rect_rot.size.x
	# 	if cam_rect_rot.position.y < _limits[SIDE_TOP]:
	# 		cam_rect_rot.position.y = _limits[SIDE_TOP]
	# 	if cam_rect_rot.position.y + cam_rect_rot.size.y > _limits[SIDE_BOTTOM]:
	# 		cam_rect_rot.position.y = _limits[SIDE_BOTTOM] - cam_rect_rot.size.y

	var t := Transform2D()
	t = t.scaled(Vector2.ONE / (zoom * _shake_scale))
	t = t.rotated(camera_rot)
	if enable_pixel_snap:
		t.origin = cam_rect_rot.position.round()
	else:
		t.origin = cam_rect_rot.position

	__last_interp_pos = cam_rect_rot.position
	# if enable_pixel_snap > 0:
	# 	var snap_size := enable_pixel_snap
	# 	print(snap_size)
	# 	t.origin = round(t.origin / snap_size) * snap_size
	# 	# print("new org: ", t.origin)

	# t = t * _shake_transform_offset

	_cam_screen_center = t * (cam_size * 0.5)

	return t.affine_inverse()

func _get_camera_size() -> Vector2:
	if _is_inside_editor():
		return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
	return _viewport.get_visible_rect().size

func _get_scaled_camera_size() -> Vector2:
	var cam := _get_camera_size()
	if _is_inside_editor():
		return cam
	return cam * _zoom_inverse

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
