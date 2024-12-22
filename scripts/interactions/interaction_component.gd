class_name InteractionComponent
extends Area2D

@export var popup: Node2D
var is_displayed := false
var itm: int = -1

var should_show_popup: bool = false:
	set(value):
		if not value and show_popup:
			hide_popup()
		elif value and not show_popup:
			show_popup()
		should_show_popup = value

func _enter_tree() -> void:
	self.collision_layer |= 1 << 9
	self.collision_mask |= 1 << 9

func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	self.area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	if is_displayed and itm >= 0 and should_show_popup:
		InteractionManager.instance.update_item(itm, _get_popup_pos())

func _get_popup_pos() -> Vector2:
	return popup.global_position if is_instance_valid(popup) else self.global_position

func _on_area_entered(body: Node2D) -> void:
	if body is not Interactor:
		return
	is_displayed = true
	itm = InteractionManager.instance.reserve_item(itm)
	if itm == -1:
		print("gosh oh golly")
	should_show_popup = true
	show_popup()
	body.on_try_interact.connect(_on_interact)

func _on_area_exited(body: Node2D) -> void:
	if body is not Interactor:
		return
	if not is_displayed:
		return
	await hide_popup()
	is_displayed = false
	should_show_popup = false
	InteractionManager.instance.free_item(itm)
	itm = -1
	body.on_try_interact.disconnect(_on_interact)

func show_popup() -> void:
	InteractionManager.instance.display_item(itm)

func hide_popup() -> void:
	await InteractionManager.instance.hide_item(itm)

func _on_interact(_interactor: Interactor) -> void:
	pass