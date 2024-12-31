class_name Player
extends CharacterBody2D

static var instance: Player = null

@export var slope_max_angle := 85.0
@export var slope_snap := true

@export_group("References")
@export var _visuals: Node2D
@export var _line: Line2D
@export var _interactor: Interactor

@export_group("Health")
@export var heatlh: HealthComponent
@export var hurtbox: HurtboxComponent

@export_group("Physics")
@export var floor_friction := 400.0
@export var slope_friction := 350.0

@export var roll_speed := 80.0
@export var roll_acceleration := 200.0
@export var roll_decelrtaion := 400.0

@export var jump_force: float = 2.0

@export_group("Yeet Settings")
@export var has_yeet: bool = true
@export var yeet_max_dist: float = 100.0
@export var yeet_display_max_dist: float = 25.0
@export var yeet_max_force: float = 250.0

@export_group("Fall")
@export var max_fall: float = 300.0
@export var gravity: float = 440.0

@export_group("States")
@export var locked: bool = false

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

func _process(_delta: float) -> void:
	# _visuals.global_position = global_position.round()
	# Dumb "top level" ahhh resets
	_line.global_rotation = 0.0

	# if Input.is_action_just_pressed("jump"):
		# cam.shake_noise(100, 100, 5, true, KongleCamera.ProcessEvent.PROCESS)
		# cam.shake_spring(Vector2.DOWN * 100, 100, 2, 0)
		# await get_tree().create_timer(2.5).timeout
		# print("Trying to reset!")
		# cam.shake_noise(100, 100, 1, true, KongleCamera.ProcessEvent.PROCESS)

	if not locked:
		if Input.is_action_just_pressed("interact"):
			_interactor.try_interact()

var _on_slope := false
var _slope_normal := Vector2.ZERO
var _was_on_slope := false

var _snap_breakout := false

func _physics_process(delta: float) -> void:
	if not locked:
		_snap_breakout = false

		velocity.y -= gravity * delta
		velocity.y = min(velocity.y, max_fall)
		if _on_slope:
			velocity = velocity.slide(_slope_normal)
		
		_handle_yeet()
		if not _yeeted:
			_handle_movement(delta)
		
		if not _is_rolling or (velocity.x * _roll_dir < 0.0 and velocity.x > roll_speed):
			if _on_slope:
				velocity = velocity.normalized() * move_toward(velocity.length(), 0.0, slope_friction * delta)
			elif is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, floor_friction * delta)

		# floor_max_angle = 80.0
		move_and_slide()
		# floor_max_angle = 15.0
		_was_on_slope = _on_slope
		_on_slope = false
		_update_directions()

		if not _snap_breakout:
			_snap_to_floor()

func _update_directions() -> void:
	for i in get_slide_collision_count():
		var res := get_slide_collision(i)
		var normal = res.get_normal()
		var coll_angle = rad_to_deg(acos(normal.dot(Vector2.UP)))
		if floor_max_angle < coll_angle and coll_angle <= slope_max_angle:
			_on_slope = true
			_slope_normal = res.get_normal()

func _snap_to_floor() -> void:
	if not is_on_floor():
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
			var floor_snap := floor_snap_length > 0.0
			if (slope_snap and coll_angle <= slope_max_angle): # (floor_snap and coll_angle <= floor_max_angle) or
				if floor_snap and coll_angle <= floor_max_angle:
					_on_slope = true
					_slope_normal = normal
					# _on_floor = true
				# _on_floor_normal = normal
				# _on_floor_rid = r.get_collider_rid()
				# _on_floor_obj_id = r.get_collider_id()
				# _on_floor_velocity = r.get_collider_velocity()
			var travel := r.get_travel()
			if travel.length() > 0.001:
				travel = Vector2.UP * Vector2.UP.dot(travel)
			else:
				travel = Vector2.ZERO
			p.from.origin += travel
			global_transform = p.from

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=
# =-=-=-=-=-=-=-=-=-=-=-=-=-= FUNCTOINS -=-=-=-=-=-==-=-=-=-=-=-=-=
var _is_rolling := false
var _jump_buffer := 0.0
var _roll_dir := 0.0
var _is_jumping := false
func _handle_movement(delta: float) -> void:
	var x := Input.get_axis("walk_left", "walk_right")
	var jump := Input.is_action_just_pressed("jump")
	_jump_buffer -= delta
	if jump:
		_jump_buffer = 0.2

	_is_rolling = abs(x) > 0.001
	_roll_dir = signf(x)
	if _is_rolling:
		var accel := roll_acceleration
		if velocity.x * x < 0.0:
			accel = roll_decelrtaion
		velocity.x = move_toward(velocity.x, x * roll_speed, accel * delta)
		# if _on_slope:
		# 	velocity = velocity.slide(_slope_normal)
		_is_rolling = true
	
	if (is_on_floor() or _on_slope) and _jump_buffer >= 0.0:
		velocity.y = -jump_force
		_snap_breakout = true
		_is_jumping = true

func _handle_yeet() -> void:
	if has_yeet and Input.is_action_just_pressed("yeet"):
		_is_yeet = true
		_yeet_drag_start = get_global_mouse_position()
	
	if not _was_yeet and _is_yeet:
		_line.visible = true
	if not _is_yeet and _was_yeet:
		_line.visible = false

	# $"Visuals".rotation = linear_velocity.angle()
	if _is_yeet:
		_yeet_drag_end = get_global_mouse_position()
		var offset = _yeet_drag_end - _yeet_drag_start
		
		var angle = -offset.angle_to(Vector2.RIGHT) - PI / 2.0
		_visuals.global_rotation = angle
		
		var dist = offset.length()
		var t = minf(dist / yeet_max_dist, 1.0)
		# var display_dist = 8.0 + t * yeet_display_max_dist
		_line.set_point_position(0, _yeet_drag_start)
		_line.set_point_position(1, _yeet_drag_end)
		if Input.is_action_just_released("yeet"):
			_was_yeet = true
			_is_yeet = false
			# Audio.map["kongle_yeet"].play()
			var dir = -offset.normalized()
			dir = dir * Vector2(1.0, 1.25)
			# _rb.linear_velocity = Vector2.ZERO
			# _rb.apply_impulse(dir * t * yeet_max_force)
			velocity = dir * t * yeet_max_force
			_snap_breakout = true

			_yeeted = true
		else:
			_was_yeet = true
	else:
		_was_yeet = _is_yeet
		if is_on_floor() or _on_slope:
			_yeeted = false
	
	if not _yeeted and not _is_yeet:
		_visuals.rotation = 0.0
	

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# -=-=-=-=-=-= HELPER FUNCTIONS -=-=-=-=-=-

# func _is_grounded() -> bool:
# 	return is_on_floor() or _on_slope

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# -=-=-=-=-=-= SIGNALS -=-=-=-=-=-
