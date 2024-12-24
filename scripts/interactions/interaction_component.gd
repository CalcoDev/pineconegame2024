class_name InteractionComponent
extends Area2D

signal on_interacted_with(interactor: Interactor)
signal on_interaction_finished(interactor: Interactor)

@export var popup: Node2D
var is_displayed := false
var itm: int = -1

var _interaction_in_progress := false

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
	self.on_interaction_finished.connect(_handle_end_interaction)

func _handle_start_interaction(interactor: Interactor) -> void:
	on_interacted_with.emit(interactor)
	_interaction_in_progress = true
	# if not _should_show_popup(interactor):
	if _try_disconnect(interactor.on_try_interact, _on_interact):
		interactor.has_interaction = false
	_try_disconnect(interactor.on_try_interact, _handle_start_interaction)

func _handle_end_interaction(_interactor: Interactor) -> void:
	_interaction_in_progress = false

func _process(_delta: float) -> void:
	if is_displayed and itm >= 0 and should_show_popup:
		InteractionManager.instance.update_item(itm, _get_popup_pos())
	if not is_displayed and _interactors.size() > 0 and not _interaction_in_progress:
		var inter_popup := false
		var displayed_interactors: Array[Interactor] = []
		for interactor in _interactors:
			if _should_show_popup(interactor):
				inter_popup = true
				displayed_interactors.append(interactor)
		if inter_popup:
			if itm == -1:
				is_displayed = true
				itm = InteractionManager.instance.reserve_item(itm, self)
			if itm == -1:
				print("gosh oh golly")
			should_show_popup = true
			show_popup()
			var has_connection := false
			for interactor in displayed_interactors:
				if not has_connection:
					if _try_connect(interactor.on_try_interact, _on_interact):
						interactor.has_interaction = true
						has_connection = true
					_try_connect(interactor.on_try_interact, _handle_start_interaction)
	if is_displayed:
		if not _interaction_in_progress and _interactors.size() > 0:
			var inter_popup := false
			var displayed_interactors: Array[Interactor] = []
			for interactor in _interactors:
				if _should_show_popup(interactor):
					inter_popup = true
					displayed_interactors.append(interactor)
				else:
					if _try_disconnect(interactor.on_try_interact, _on_interact):
						interactor.has_interaction = false
					_try_disconnect(interactor.on_try_interact, _handle_start_interaction)
					hide_popup()
					InteractionManager.instance.free_item(itm, self)
					itm = -1
			if inter_popup:
				# is_displayed = true
				if itm == -1:
					itm = InteractionManager.instance.reserve_item(itm, self)
				if itm == -1:
					print("gosh oh golly")
				should_show_popup = true
				show_popup()
				# we should already be connected ?
				var has_connection := false
				for interactor in displayed_interactors:
					if not has_connection:
						if _try_connect(interactor.on_try_interact, _on_interact):
							interactor.has_interaction = true
							has_connection = true
						_try_connect(interactor.on_try_interact, _handle_start_interaction)
		if _interactors.size() == 0 and not _called_cancelled:
			_cancel_popup()

func _try_disconnect(sig: Signal, callable: Callable) -> bool:
	if sig.is_connected(callable):
		sig.disconnect(callable)
		return true
	return false

func _try_connect(sig: Signal, callable: Callable) -> bool:
	if not sig.is_connected(callable):
		sig.connect(callable)
		return true
	return false

# coroutine so await works
var _called_cancelled := false
func _cancel_popup() -> void:
	if _called_cancelled:
		return
	_called_cancelled = true
	is_displayed = false
	should_show_popup = false
	await hide_popup()
	InteractionManager.instance.free_item(itm, self)
	itm = -1

func _get_popup_pos() -> Vector2:
	return popup.global_position if is_instance_valid(popup) else self.global_position

var _interactors: Array[Interactor] = []
func _on_area_entered(body: Node2D) -> void:
	if body is not Interactor:
		return
	_interactors.append(body)

func _on_area_exited(body: Node2D) -> void:
	if body is not Interactor:
		return
	var idx := _interactors.find(body)
	if idx == -1:
		return
	_interactors.remove_at(idx)
	if _try_disconnect(body.on_try_interact, _on_interact):
		body.has_interaction = false
	_try_disconnect(body.on_try_interact, _handle_start_interaction)

func show_popup() -> void:
	_called_cancelled = false
	InteractionManager.instance.display_item(itm)

func hide_popup() -> void:
	await InteractionManager.instance.hide_item(itm)

func _should_show_popup(_interactor: Interactor) -> bool:
	return true

func _on_interact(_interactor: Interactor) -> void:
	pass
