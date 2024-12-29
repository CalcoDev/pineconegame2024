class_name Interactor
extends Area2D

signal on_try_interact()
signal on_succesful_interact(interaction: InteractionComponent)

func try_interact() -> void:
	on_try_interact.emit()
	if is_instance_valid(_interaction):
		on_succesful_interact.emit(_interaction)
		_interaction.on_interacted_with.emit(self)
		@warning_ignore("redundant_await")
		await _interaction._on_interact(self)
		_interaction.on_interaction_finished.emit(self)

func _enter_tree() -> void:
	self.collision_layer |= 1 << 9
	self.collision_mask |= 1 << 9

	self.area_entered.connect(_on_area_entered)
	self.area_exited.connect(_on_area_exited)

var _interaction: InteractionComponent
func _on_area_entered(body: Node2D) -> void:
	if body is not InteractionComponent:
		return
	_init_interaction(body)

func _on_area_exited(body: Node2D) -> void:
	if body is not InteractionComponent:
		return
	if body != _interaction:
		return
	_uninit_uninteraction(_interaction)

func _init_interaction(interaction: InteractionComponent) -> void:
	if not interaction._should_show_popup(self):
		return
	_uninit_uninteraction(_interaction)
	_interaction = interaction
	_interaction._show_popup()

func _uninit_uninteraction(interaction: InteractionComponent) -> void:
	if interaction != null:
		interaction._hide_popup()