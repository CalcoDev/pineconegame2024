class_name Actor
extends StaticBody2D

@export_group("Movement Options")
@export var slide_on_floor := false
@export var slide_on_slope := false

@export var floor_max_angle := 30.0
@export var slope_max_angle := 90.0

@export var floor_snap_length := 1.0

@export var slide_on_ceiling := true

@export_flags_2d_physics var moving_platform_layer := 0

var velocity := Vector2.ZERO

var _last_coll: KinematicCollision2D

var _on_floor := false
var _on_floor_body: RID = RID()
var _floor_velocity := Vector2.ZERO

var _colliders := []

func move(motion: Vector2, callback: Callable = _empty_callable, max_slides: int = 4) -> Vector2:
	var delta = get_process_delta_time() if not Engine.is_in_physics_frame() else get_physics_process_delta_time()

	if _on_floor and _on_floor_body.is_valid():
		var t: Vector2 = PhysicsServer2D.body_get_state(_on_floor_body, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		if t:
			_floor_velocity = t
	
	_colliders.clear()
	_on_floor = false
	
	if _floor_velocity != Vector2.ZERO and _on_floor_body.is_valid():
		var l := _clear_exclude()
		_add_exclude(_on_floor_body)
		_restate_exclude(l)
		move_and_collide(_floor_velocity * delta)
		_rm_exclude(_on_floor_body)

	# Floor snapping logic
	if floor_snap_length > 0 and velocity.y >= 0: # Only snap when falling or idle
		var params := PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + Vector2.DOWN * floor_snap_length,
			collision_mask,
			[self]
		)
		var snap_result = get_world_2d().direct_space_state.intersect_ray(params)
		if snap_result:
			var snap_normal = snap_result.normal
			var snap_angle = rad_to_deg(acos(snap_normal.dot(Vector2.UP)))
			if snap_angle <= floor_max_angle:
				global_position = snap_result.position
				velocity.y = 0

	var coll_cnt := 0
	while coll_cnt < max_slides and motion.length() > 0.01:
		var collision := move_and_collide(motion, false, 0.001, false)
		if collision:
			_last_coll = collision
			callback.call(collision)
			coll_cnt += 1
			var collision_normal = collision.get_normal()
			var floor_normal = Vector2.UP
			var coll_angle = rad_to_deg(acos(collision_normal.dot(floor_normal)))

			if coll_angle <= floor_max_angle:
				_on_floor = true
				_on_floor_body = collision.get_collider_rid()
				if slide_on_floor:
					motion = motion.slide(collision_normal)
				else:
					motion = Vector2.ZERO
					break
			elif coll_angle <= slope_max_angle:
				if slide_on_slope:
					motion = motion.slide(collision_normal)
				else:
					motion = Vector2.ZERO
					break
			elif coll_angle > 90.0 and not slide_on_ceiling:
				motion.y = max(motion.y, 0.0)
				break
			else:
				motion = motion - collision_normal * motion.dot(collision_normal)
		else:
			break

	return motion

func _add_exclude(rid: RID) -> void:
	PhysicsServer2D.body_add_collision_exception(get_rid(), rid)

func _rm_exclude(rid: RID) -> void:
	PhysicsServer2D.body_remove_collision_exception(get_rid(), rid)

func _clear_exclude() -> Array:
	var l = []
	for b in get_collision_exceptions():
		l.append(b)
		remove_collision_exception_with(b)
	return l

func _restate_exclude(l) -> void:
	for b in l:
		add_collision_exception_with(b)

func is_on_floor() -> bool:
	if _last_coll == null:
		return false
	var normal = _last_coll.get_normal()
	var angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
	return angle < floor_max_angle

func is_on_slope() -> bool:
	if _last_coll == null:
		return false
	var normal = _last_coll.get_normal()
	var angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
	return angle > floor_max_angle and angle <= slope_max_angle

func is_on_wall() -> bool:
	if _last_coll == null:
		return false
	var normal = _last_coll.get_normal()
	var angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
	return angle > max(floor_max_angle, slope_max_angle) and angle < 130.0

func is_on_ceiling() -> bool:
	if _last_coll == null:
		return false
	var normal = _last_coll.get_normal()
	return rad_to_deg(acos(normal.dot(Vector2.UP))) > 90.0

static func _empty_callable(_coll: KinematicCollision2D) -> void:
	pass