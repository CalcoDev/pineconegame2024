class_name InteractionComponent
extends Area2D

signal on_interacted_with(interactor: Interactor)
signal on_interaction_finished(interactor: Interactor)

@export var show_popup: bool = true
@export var popup_location: Node2D

var _is_displayed := false
func _process(_delta: float) -> void:
	if _is_displayed:
		InteractionManager.instance.update_wobj(self, _get_popup_pos())

func _show_popup() -> void:
	InteractionManager.instance.reserve_wobj(self)
	InteractionManager.instance.show_wobj(self)
	_is_displayed = true

func _hide_popup() -> void:
	_is_displayed = false
	await InteractionManager.instance.hide_wobj(self)
	InteractionManager.instance.unreserve_wobj(self)

func _get_popup_pos() -> Vector2:
	return popup_location.global_position if is_instance_valid(popup_location) else self.global_position

# Overrides
func _should_show_popup(_interactor: Interactor) -> bool:
	return show_popup

func _on_interact(_interactor: Interactor) -> void:
	pass