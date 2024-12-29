class_name Player
extends Actor

static var instance: Player = null

@export_group("References")
@export var _visuals: Node2D
@export var _line: Line2D
@export var _interactor: Interactor

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
@export var yeet_max_force: float = 250.0

@export_group("Fall")
@export var max_fall: float = 300.0
@export var gravity: float = 440.0

@export_group("States")
@export var locked: bool = false

var grounded: bool = false
var prev_grounded: bool = false

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

func _ready() -> void:
	_visuals.scale = Vector2.ONE * 0.75

func _process(delta: float) -> void:
	# Dumb "top level" ahhh resets
	_line.global_rotation = 0.0

	prev_grounded = grounded
	grounded = is_on_floor()

	# print(is_on_slope())
	if not locked:
		if Input.is_action_just_pressed("interact"):
			_interactor.try_interact()

func _physics_process(delta: float) -> void:
	if not locked:
		velocity.y -= gravity * delta
		velocity.y = min(velocity.y, max_fall)
		
		_handle_yeet()

		velocity = move(velocity * delta) / delta
		# move_and_slide()
	pass

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-==-=-=-=-=-=-=-=
# =-=-=-=-=-=-=-=-=-=-=-=-=-= FUNCTOINS -=-=-=-=-=-==-=-=-=-=-=-=-=
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

			_yeeted = true
		else:
			_was_yeet = true
	else:
		_was_yeet = _is_yeet
		if grounded:
			_yeeted = false
	
	if not _yeeted and not _is_yeet:
		_visuals.rotation = 0.0
	

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# -=-=-=-=-=-= HELPER FUNCTIONS -=-=-=-=-=-
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# -=-=-=-=-=-= SIGNALS -=-=-=-=-=-
