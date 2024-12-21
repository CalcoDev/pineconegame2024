class_name DialogueInteraction
extends InteractionComponent

@export var node_id: String

func _on_interact(_interactor: Interactor) -> void:
    should_show_popup = false
    DialogueManager.r.start_dialogue(node_id)