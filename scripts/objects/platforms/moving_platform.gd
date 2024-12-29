class_name MovingPlatform
extends PhysicsBody2D

@export var move_speed: float = 20.0

var _points: Array[MovingPlatformPoint]

func _enter_tree() -> void:
	var pts = find_children("*", "MovingPlatformPoint", false)
	_points.assign(pts)
	for point in _points:
		var p := point.global_position
		var r := point.global_rotation
		point.top_level = true
		point.global_position = p
		point.global_rotation = r

func _ready() -> void:
	_go_points()

func _go_points() -> void:
	var idx := 0
	while true:
		if idx <= 0:
			while idx + 1 < _points.size():
				if idx > 0:
					await _points[idx].poll_move_type_begin()
				idx += 1
				await _go_to_point(idx)
			match _points[idx].loop:
				MovingPlatformPoint.LoopType.NONE:
					break
				MovingPlatformPoint.LoopType.TO_PREVIOUS:
					continue
				MovingPlatformPoint.LoopType.WRAP_AROUND:
					idx = (idx + 1) % _points.size() - 1
					continue
		if idx + 1 == _points.size():
			while idx > 0:
				if idx < _points.size():
					await _points[idx].poll_move_type_begin()
				idx -= 1
				await _go_to_point(idx)
			if _points[idx].loop == MovingPlatformPoint.LoopType.NONE:
				break
			match _points[idx].loop:
				MovingPlatformPoint.LoopType.NONE:
					break
				MovingPlatformPoint.LoopType.TO_PREVIOUS:
					continue
				MovingPlatformPoint.LoopType.WRAP_AROUND:
					idx = (_points.size() + idx - 1) % _points.size() - 1
					continue
		
func _go_to_point(idx: int) -> void:
	var target := _points[idx].global_position
	var dist := global_position.distance_to(target)
	var t := create_tween()
	t.set_trans(_points[idx].trans_type)
	t.set_ease(_points[idx].ease_type)
	t.tween_property(self, "global_position", target, dist / move_speed)
	t.play()
	await t.finished
	if not Coroutine.is_node_valid(self):
		return
