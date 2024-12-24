class_name Player
extends RigidBody2D

static var instance: Player = null

@export_group("References")
#@export var _rb: RigidBody2D
@export var _visuals: Node2D
@export var _line: Line2D
@export var _gc: Area2D
@export var _interactor: Interactor

# @export var shader: ShaderMaterial
@export var sprite: AnimatedSprite2D
var shader: ShaderMaterial:
	get():
		return sprite.material

@export_group("Health")
@export var heatlh: HealthComponent
@export var hurtbox: HurtboxComponent

@export_group("Movement")
@export var roll_speed: float = 2.0
@export var jump_force: float = 2.0

@export_group("Yeet Settings")
@export var has_yeet: bool = true
@export var yeet_max_dist: float = 100.0
@export var yeet_display_max_dist: float = 25.0
@export var yeet_max_force: float = 300.0

@export_group("Fall")
@export var limit_fall: bool = false
@export var max_fall: float = 20

@export_group("States")
@export var locked: bool = false

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
	# _gc.top_level = true
	_gc.body_entered.connect(_entered_ground)
	_gc.body_exited.connect(_exited_ground)
	#_rb.top_level = true

	hurtbox.on_hit.connect(_on_hit)

func _ready() -> void:
	_visuals.scale = Vector2.ONE * 0.75

func _process(_detal: float) -> void:
	if not locked:
		_gc.global_rotation = 0.0
		
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
			
			var angle = -offset.angle_to(Vector2.RIGHT) - PI / 2.0
			self._visuals.global_rotation = angle
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
				dir = dir * Vector2(1.0, 1.25)
				# TODO(calco): Disable visuals
				# TODO(calco): Apply force and stuff
				_rb.linear_velocity = Vector2.ZERO
				_rb.apply_impulse(dir * t * yeet_max_force)

				_yeeted = true
			else:
					_was_yeet = true
		else:
			_was_yeet = _is_yeet
			if is_ground:
				_yeeted = false
		
		if _yeeted:
			var angle = self.linear_velocity.angle_to(Vector2.RIGHT)
			self._visuals.global_rotation = angle
		else:
			if not _is_yeet:
				self._visuals.rotation = 0.0
		
		if Input.is_action_just_pressed("interact"):
			_interactor.try_interact()
	
	if self.linear_velocity.y > max_fall:
		self.linear_velocity.y = max_fall

func _on_hit(_damage: float, _by: Node2D) -> void:
	var t := create_tween().set_ease(Tween.EASE_IN_OUT)
	t.tween_property(shader, "shader_parameter/solid_color", Color.WHITE, 0.05)
	t.parallel().tween_property(shader, "shader_parameter/outline_color", Color.RED, 0.05)
	t.tween_property(shader, "shader_parameter/solid_color", Color.TRANSPARENT, 0.05)
	t.parallel().tween_property(shader, "shader_parameter/outline_color", Color.TRANSPARENT, 0.05)
	t.tween_property(shader, "shader_parameter/solid_color", Color.WHITE, 0.05)
	t.parallel().tween_property(shader, "shader_parameter/outline_color", Color.RED, 0.05)
	t.tween_property(shader, "shader_parameter/solid_color", Color.TRANSPARENT, 0.05)
	t.parallel().tween_property(shader, "shader_parameter/outline_color", Color.TRANSPARENT, 0.05)
	t.play()
	GameCamera.instance.shake(5.0, 50.0, 15.0, 0.25)
	Game.instance.hitstop(0.1)
	self.linear_velocity = Vector2.ZERO
	await t.finished

func _physics_process(delta: float) -> void:
	if not locked:
		if is_ground:
			var inp_x := Input.get_axis("walk_left", "walk_right")
			if abs(inp_x) > 0.02:
				self.linear_velocity.x = move_toward(self.linear_velocity.x, inp_x * roll_speed / delta, 20)
			else:
				self.linear_velocity.x = move_toward(self.linear_velocity.x, 0.0, 0.2)
			if Input.is_action_just_pressed("jump"):
				self.global_position.y -= 1
				self.linear_velocity.y = 0.0
				self.apply_impulse(Vector2.UP * jump_force)
		if Input.is_action_pressed("fall"):
			if self.collision_mask & 8:
				self.collision_mask = self.collision_mask & 0xFFFFFFF7
		else:
			if not self.collision_mask & 8:
				self.collision_mask = self.collision_mask | 0x8

var _is_ground_coll := false
var _grounds: Array = [] # faster for smaller values lmfao
func _entered_ground(body: Node2D) -> void:
	var idx := _grounds.find(body)
	if idx != -1:
		return
	_grounds.append(body)
	_is_ground_coll = true
	# print("Touched ground: ", body.name)

func _exited_ground(body: Node2D) -> void:
	var idx := _grounds.find(body)
	if idx == -1:
		return
	# print("Removed ground: ", body.name)
	_grounds.remove_at(idx)
	if _grounds.size() == 0:
		_is_ground_coll = false
		# print("is false")

func MoveAndCollide(motion: Vector2):
	var col = move_and_collide(Vector2.RIGHT * motion.x)
	if col != null:
		var norm = col.get_normal()
		var dir = get_perpendicular(norm)
		var ang = norm.angle_to(motion)
		if ang > 0:
			dir.x *= -1
			dir.y *= -1
		# if PI - abs(ang) > deg_to_rad(WallSlideAngle):
		# 	move_and_collide(dir * col.get_remainder().length())
	col = move_and_collide(Vector2.DOWN * motion.y)
	if col != null:
		var norm = col.get_normal()
		var dir = get_perpendicular(norm)
		var ang = norm.angle_to(motion)
		if ang > 0:
			dir.x *= -1
			dir.y *= -1
		# if PI - abs(ang) > deg_to_rad(WallSlideAngle):
		# 	move_and_collide(dir * col.get_remainder().length())
 
func v2_v3(vec):
	return Vector2(vec.x, vec.z)

func v3_v2(vec):
	return Vector3(vec.x, 0, vec.y)

func get_perpendicular(vec):
	return v2_v3(Vector3.UP.cross(v3_v2(vec)))
