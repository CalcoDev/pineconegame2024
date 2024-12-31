extends Node2D

@export var bouncing_ball: Control

@export var time_speed := 10.0
@export var scrollback := 100.0

@export var x_line: Line2D
@export var y_line: Line2D

@export var spring := 1.0:
	set(value):
		spring = value
		_spr.spring = spring
@export var damp := 1.0:
	set(value):
		damp = value
		_spr.damp = damp

var _t := 0.0
var _spr := Spring2D.new(1, 1)
func _ready() -> void:
	_spr = Spring2D.new(spring, damp)
	test.bind("a", "b").bind("c").call()

func test(a, b, c) -> void:
	print(a, b, c)

var _pos := Vector2.ZERO
func _process(delta: float) -> void:
	_t += delta * time_speed

	bouncing_ball.global_position = Vector2(418, 120) + Vector2.UP * (sin(_t / 4) - 1.0) / 2.0 * 150.0
	
	# y_pos = _y_spring.tick(delta, y_pos)
	if Input.is_action_just_pressed("jump"):
		var m := (get_global_mouse_position() - Vector2(320, 240)).normalized() * 40
		_spr.velocity = m / delta
	_pos = _spr.tick(delta, _pos)

	x_line.add_point(Vector2(0, _pos.x / 2.0))
	y_line.add_point(Vector2(0, _pos.y / 2.0))

	for i in x_line.get_point_count():
		var p := x_line.get_point_position(i)
		x_line.set_point_position(i, Vector2(p.x - delta * scrollback, p.y))
	for i in y_line.get_point_count():
		var p := y_line.get_point_position(i)
		y_line.set_point_position(i, Vector2(p.x - delta * scrollback, p.y))