class_name LineGraph
extends Control

const POINT_SIZE: float = 2.5
const LINE_WIDTH: float = 5

class Point:
    var x: float = 0.0
    var y: float = 0.0

    func _init(p_x: float, p_y: float) -> void:
        self.x = p_x
        self.y = p_y

# How big is one unit in pixels
@export var ppu: Vector2 = Vector2(16, 9):
    set(value):
        ppu = value
        _update_limit_display()
# How much do we increment (in value) every unit
@export var ppu_scale: Vector2 = Vector2(10, 10):
    set(value):
        ppu_scale = value
        _update_limit_display()
# Offset values to animate time
@export var scroll_offset: float = 0.0:
    set(value):
        scroll_offset = value
        _update_limit_display()

# TODO(calco): Customise display options
# @export var display_

var sample_points: Array[Point] = []

# TODO(calco): Should make sure the points are added sequentially (x wise)
# But for now we "assume" it :skull:
func add_point(p: Point) -> void:
    sample_points.append(p)

func scroll_points(amount: float) -> void:
    scroll_offset += amount

# TODO(calco): Better name (length of axis ???)
func get_axis_visible_length() -> Vector2:
    return size / ppu * ppu_scale

# TODO(calco): Ideally proper culling should occur on Y axis as well
# But too lazy to do it now
func is_in_visible_value_range(p: Point) -> bool:
    # var rp = get_render_pos(p)
    return p.x > scroll_offset and p.x < scroll_offset + get_axis_visible_length().x

# TODO(calco): Implement
# func cull_points() -> void:

var _h_start: Label = null
var _h_end: Label = null
var _v_start: Label = null
var _v_end: Label = null

func _update_limit_display() -> void:
    var axis_lengths: Vector2 = get_axis_visible_length()
    _h_start.text = str(round(scroll_offset))
    _h_end.text = str(round(scroll_offset + axis_lengths.x))
    _v_start.text = str(round(0))
    _v_end.text = str(round(axis_lengths.y))

func _process(delta: float) -> void:
    queue_redraw()

var _p_prev_x: float = 10.0

func _ready() -> void:
    _h_start = %HorizStart
    _h_start.position = Vector2.DOWN * size.y + Vector2.DOWN * 10
    _h_end = %HorizEnd
    _h_end.position = Vector2.DOWN * size.y + Vector2.RIGHT * size.x + Vector2.DOWN * 10
    _v_start = %VertStart
    _v_start.get_parent().position = Vector2.DOWN * size.y + Vector2.LEFT * 10
    _v_end = %VertEnd
    _v_end.get_parent().position = Vector2.ZERO + Vector2.LEFT * 10
    _update_limit_display()

    _p_make_point()
    # add_point(Point.new(0, 10))
    # add_point(Point.new(10, 50))
    # add_point(Point.new(20, 20))
    # add_point(Point.new(30, 40))

func _p_make_point() -> void:
    get_tree().create_timer(0.15).timeout.connect(
        func():
            var p = Point.new(_p_prev_x, randf_range(0, get_axis_visible_length().y))
            add_point(p)
            _p_prev_x += get_axis_visible_length().x / 10
            _p_make_point()
    )

func get_render_pos(p: Point) -> Vector2:
    var fp: Vector2 = Vector2(p.x, p.y)
    # Axis (convert value to units to pixels)
    fp.x = fp.x / ppu_scale.x * ppu.x
    fp.y = fp.y / ppu_scale.y * ppu.y
    # Invert Y
    fp.y = size.y - fp.y
    return fp

func _draw() -> void:
    var tl = Vector2.ZERO
    var tr = Vector2.RIGHT * size.x
    var bl = Vector2.DOWN * size.y
    var br = size

    for i in sample_points.size() - 1:
        if is_in_visible_value_range(sample_points[i]):
            var rp1 = get_render_pos(sample_points[i])
            var rp2 = get_render_pos(sample_points[i + 1])
            draw_line(rp1, rp2, Color.BLUE, LINE_WIDTH)
        else:
            break

    for p in sample_points:
        var rp = get_render_pos(p)
        if is_in_visible_value_range(p):
            draw_circle(rp, POINT_SIZE, Color.GREEN)
        else:
            break
            # draw_circle(rp, POINT_SIZE, Color.RED)

    draw_rect(Rect2(tl, size), Color.BLACK, false, LINE_WIDTH)

    draw_circle(tl, POINT_SIZE, Color.RED)
    draw_circle(tr, POINT_SIZE, Color.RED)
    draw_circle(bl, POINT_SIZE, Color.RED)
    draw_circle(br, POINT_SIZE, Color.RED)
