class_name InteractionManager
extends Node2D

static var instance: InteractionManager = null

@export var items: Array[Node] = []
var _used_items := []
var _item_tweens: Array[Tween] = []

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	for itmidx in items.size():
		hide_item(itmidx)

func reserve_item(prev: int) -> int:
	for itmidx in items.size():
		if items[itmidx] not in _used_items:
			_used_items.append(items[itmidx])
			return itmidx
	#assert(false, "No more free items damn.")
	return prev

func free_item(item: int) -> void:
	var idx := _used_items.find(items[item])
	if idx == -1:
		return
	_used_items.remove_at(idx)

func display_item(item: int) -> void:
	items[item].visible = true
	if item <= _item_tweens.size():
		_item_tweens.resize(item + 1)
	if is_instance_valid(_item_tweens[item]):
		_item_tweens[item].kill()
		_item_tweens[item] = null
	_item_tweens[item] = get_tree().create_tween()

	var t := _item_tweens[item]
	t.set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_property(items[item], "scale", Vector2.ONE * 1.2, 0.1)
	t.chain().tween_property(items[item], "scale", Vector2.ONE * 1, 0.05)
	t.play()
	await t.finished

func hide_item(item: int) -> void:
	if item <= _item_tweens.size():
		_item_tweens.resize(item + 1)
	if is_instance_valid(_item_tweens[item]):
		_item_tweens[item].kill()
		_item_tweens[item] = null
	_item_tweens[item] = get_tree().create_tween()
	var t := _item_tweens[item]
	t.set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_property(items[item], "scale", Vector2.ONE * 1.2, 0.05)
	t.chain().tween_property(items[item], "scale", Vector2.ONE * 0, 0.1)
	t.play()
	await t.finished
	items[item].visible = false
	

func update_item(item: int, world_position: Vector2) -> void:
	var pos := GameCamera.instance.get_screen_center_position() + (Vector2(-320, -180) / 2.0)
	# var pos := GameCamera.instance.get_screen_center_position()
	items[item].global_position = (world_position - pos) * 2.0
