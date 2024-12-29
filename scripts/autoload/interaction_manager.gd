class_name InteractionManager
extends Node2D

static var instance: InteractionManager = null

@export var items: Array[Node] = []

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	for item in items:
		item.scale = Vector2.ZERO
		item.visible = false

func _hide_all() -> void:
	for obj in _reserved.keys():
		hide_wobj(obj)

# every object can reserve ONE SINGLE ITNERACTION
var _reserved: Dictionary = {}
func reserve_wobj(obj: Node) -> void:
	if obj in _reserved.keys() and _reserved[obj] != null:
		return
	_reserved[obj] = _get_free_item()

func unreserve_wobj(obj: Node) -> void:
	if obj not in _reserved.keys():
		return
	_reserved[obj] = null

func _get_free_item() -> Node:
	for item in items:
		if item not in _reserved.values():
			return item
	assert(false, "Error: ran out of items to allocate!")
	return null

var _tweens: Dictionary = {}
func show_wobj(obj: Node) -> void:
	if obj not in _reserved.keys():
		return
	var item: Node = _reserved[obj]
	item.visible = true
	var t := _setup_tween(obj).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_property(item, "scale", Vector2.ONE * 1.2, 0.1)
	t.chain().tween_property(item, "scale", Vector2.ONE * 1, 0.05)
	t.play()
	await t.finished

func hide_wobj(obj: Node) -> void:
	if obj not in _reserved.keys():
		return
	var t := _setup_tween(obj).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_property(_reserved[obj], "scale", Vector2.ONE * 1.2, 0.05)
	t.chain().tween_property(_reserved[obj], "scale", Vector2.ONE * 0, 0.1)
	t.play()
	await t.finished
	_reserved[obj].visible = false

func _setup_tween(obj: Node) -> Tween:
	if obj in _tweens.keys() and is_instance_valid(_tweens[obj]):
		_tweens[obj].kill()
		_tweens[obj] = null
	_tweens[obj] = get_tree().create_tween()
	return _tweens[obj]

func update_wobj(obj: Node, world_position: Vector2) -> void:
	if obj not in _reserved.keys():
		return
	var pos := GameCamera.instance.get_screen_center_position() + (Vector2(-320, -180) / 2.0)
	_reserved[obj].global_position = (world_position - pos) * 2.0