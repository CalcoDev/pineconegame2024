class_name Actor
extends StaticBody2D

@export_group("Movement Options")
## Allow sliding down on floors
@export var slide_on_floor := false
## Allow sliding down on slopes
@export var slide_on_slope := false


## Maximum angle at which a surface is considered a floor
@export var floor_max_angle := 30.0
## Maximum angle at which a surface is considered a slope
@export var slope_max_angle := 90.0

## Allow moving on a slope as if it were a floor.
@export var floor_block_on_slope := false

## Snap down when on floors
@export var floor_snap := true
## Snap down when on slopes
@export var slope_snap := true
## Floor and Slope snap length
@export var floor_snap_length := 1.0

## ????
@export var slide_on_ceiling := true

var velocity := Vector2.ZERO

var _last_coll: KinematicCollision2D

var _on_floor := false
var _was_on_floor := false

var _on_floor_normal := Vector2.ZERO
var _on_floor_rid: RID = RID()
var _on_floor_obj_id: int = 0
var _on_floor_velocity := Vector2.ZERO

var _on_slope := false

var _on_wall := false
var _on_wall_normal := Vector2.ZERO

var _on_ceiling := false

var _colliders := []

var _last_motion := Vector2.ZERO

func move(motion: Vector2, callback: Callable = _empty_callable, max_slides: int = 4) -> Vector2:
	var motion_slide_up := motion.slide(Vector2.UP)

	var delta = get_process_delta_time() if not Engine.is_in_physics_frame() else get_physics_process_delta_time()

	if _on_floor and _on_floor_rid.is_valid():
		var bs := PhysicsServer2D.body_get_direct_state(_on_floor_rid)
		_on_floor_velocity = bs.get_velocity_at_local_position(global_transform.origin - bs.transform.origin)
	else:
		_on_floor_velocity = Vector2.ZERO
		_on_floor_rid = RID()
	
	_colliders.clear()

	_last_motion = Vector2.ZERO
	_was_on_floor = _on_floor
	_on_floor = false
	_on_slope = false
	_on_wall = false
	_on_ceiling = false
	
	if not _on_floor_velocity.is_zero_approx() and _on_floor_rid.is_valid():
		var l := _clear_exclude()
		_add_exclude(_on_floor_rid)
		_restate_exclude(l)
		var k := move_and_collide(_on_floor_velocity * delta)
		if k:
			_set_collision_direction(k)
		_rm_exclude(_on_floor_rid)

	# var vel_dir_facing_up := velocity.dot(Vector2.UP) > 0.0
	var vel_dir_facing_up := motion.dot(Vector2.UP) > 0.0

	var coll_cnt := 0
	while coll_cnt < max_slides and motion.length() > 0.01:
		var result := move_and_collide(motion, false, 0.001, false)
		_last_motion = result.get_travel() if result else motion
		if result:
			_last_coll = result
			_set_collision_direction(result)
			coll_cnt += 1

			if _on_floor and not slide_on_floor and (velocity.normalized() + Vector2.UP).length() < 0.01:
				if result.get_travel().length() <= 0.001 + 0.00001:
					global_transform.origin -= result.get_travel()
				# velocity = Vector2.ZERO
				_last_motion = Vector2.ZERO
				motion = Vector2.ZERO
				break
			
			if result.get_remainder().is_zero_approx():
				motion = Vector2.ZERO
				break
			
			if floor_block_on_slope and _on_slope and motion_slide_up.dot(result.get_normal()) <= 0:
				if _was_on_floor and not _on_floor and not vel_dir_facing_up:
					if result.get_travel().length() <= 0.001:
						global_transform.origin -= result.get_travel()
					_snap_to_floor()
					# velocity = Vector2.ZERO
					_last_motion = Vector2.ZERO
					motion = Vector2.ZERO
					break
				elif not _on_floor:
					motion = Vector2.UP * Vector2.UP.dot(result.get_remainder())
					motion = motion.slide(result.get_normal())
				else:
					motion = result.get_remainder()
			# todo calco handle constant speed thing 
			elif (not _on_floor or slide_on_floor) and (not _on_slope or slide_on_slope) and (not _on_ceiling or slide_on_ceiling or not vel_dir_facing_up):
				# var slide_motion := result.get_remainder().slide(result.get_normal())
				var slide_motion := motion.slide(result.get_normal())
				# velocity not motion
				if slide_motion.dot(motion) > 0.0:
					motion = slide_motion
				else:
					# print("this thing ran!")
					motion = Vector2.ZERO
				if slide_on_ceiling and _on_ceiling:
					if vel_dir_facing_up:
						# velocity not motion
						motion = motion.slide(result.get_normal())
					else:
						# velocity not motion
						motion = Vector2.UP * Vector2.UP.dot(motion)
			else:
				motion = result.get_remainder()
				if _on_ceiling and not slide_on_ceiling and vel_dir_facing_up:
					# velocity not motion
					motion = motion.slide(Vector2.UP)
					# motion = motion.slide(Vector2.UP)
			
			_last_motion = result.get_travel()
			var st := {"motion": motion}
			callback.call(result, st)
			motion = st["motion"]

			var other := result.get_collider()
			if other is RigidBody2D:
				other.apply_central_impulse(-result.get_normal() * 200)
			
		
		if not result or motion.is_zero_approx():
			break

	_snap_to_floor()

	# todo calco scale some stuff

	return motion

func _snap_to_floor() -> void:
	if not _on_floor:
		var l := maxf(floor_snap_length, 0.001)
		# move_and_collide()
		var p := PhysicsTestMotionParameters2D.new()
		p.from = get_global_transform()
		p.motion = -Vector2.UP * l
		p.margin = 0.001
		p.recovery_as_collision = true
		p.collide_separation_ray = true
		var r := PhysicsTestMotionResult2D.new()
		if PhysicsServer2D.body_test_motion(get_rid(), p, r):
			var normal = r.get_collision_normal()
			var coll_angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
			if (floor_snap and coll_angle <= floor_max_angle): # or (slope_snap and coll_angle <= slope_max_angle)
				if floor_snap and coll_angle <= floor_max_angle:
					_on_floor = true
				_on_floor_normal = normal
				_on_floor_rid = r.get_collider_rid()
				_on_floor_obj_id = r.get_collider_id()
				_on_floor_velocity = r.get_collider_velocity()
			var travel := r.get_travel()
			if travel.length() > 0.001:
				travel = Vector2.UP * Vector2.UP.dot(travel)
			else:
				travel = Vector2.ZERO
			p.from.origin += travel
			global_transform = p.from

func _set_collision_direction(coll: KinematicCollision2D) -> void:
	var floor_normal = Vector2.UP
	var normal = coll.get_normal()
	var coll_angle = rad_to_deg(acos(normal.dot(floor_normal)))
	if coll_angle <= floor_max_angle:
		_on_floor = true
		_on_floor_normal = normal
		_on_floor_rid = coll.get_collider_rid()
		_on_floor_obj_id = coll.get_collider_id()
		_on_floor_velocity = coll.get_collider_velocity()
	elif coll_angle <= slope_max_angle:
		# todo moving platform velocity stuff here ????
		_on_slope = true
	elif rad_to_deg(acos(normal.dot(Vector2.UP))) > 90.0:
		_on_ceiling = true
	else:
		_on_wall = true
		_on_wall_normal = normal
		# todo moving platform velocity stuff here ????

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
	return _on_floor
# 	if _last_coll == null:
# 		return false
# 	var normal = _last_coll.get_normal()
# 	var angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
# 	return angle < floor_max_angle

func is_on_slope() -> bool:
	return _on_slope
# 	if _last_coll == null:
# 		return false
# 	var normal = _last_coll.get_normal()
# 	var angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
# 	return angle > floor_max_angle and angle <= slope_max_angle

func is_on_wall() -> bool:
	return _on_wall
# 	if _last_coll == null:
# 		return false
# 	var normal = _last_coll.get_normal()
# 	var angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
# 	return angle > max(floor_max_angle, slope_max_angle) and angle < 130.0

func is_on_ceiling() -> bool:
	return _on_ceiling
# 	if _last_coll == null:
# 		return false
# 	var normal = _last_coll.get_normal()
# 	return rad_to_deg(acos(normal.dot(Vector2.UP))) > 90.0

static func _empty_callable(_coll: KinematicCollision2D, _state: Dictionary) -> void:
	pass