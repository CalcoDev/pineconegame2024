class_name DialogueInteraction
extends InteractionComponent

@export var node_id: String
@export var use_parent_name: bool = false
@export var incrementing: bool = false
var curr_id := 1

func _should_show_popup(_interactor: Interactor) -> bool:
    return DialogueManager.r.node_exists(_get_current_node_id())

func _on_interact(interactor: Interactor) -> void:
    var id := _get_current_node_id()
    if incrementing:
        curr_id += 1
    var s := self.process_mode
    var ss := interactor.process_mode
    self.process_mode = Node.PROCESS_MODE_ALWAYS
    interactor.process_mode = Node.PROCESS_MODE_ALWAYS
    DialogueManager.r.start_dialogue(id)
    Game.instance.pause()
    await DialogueManager.r.on_dia_complete
    Game.instance.unpause()
    self.process_mode = s
    interactor.process_mode = ss
    on_interaction_finished.emit(interactor)

func _get_current_node_id() -> String:
    var id := _get_node_id()
    return id if not incrementing else id + "_" + str(curr_id)

func _get_node_id() -> String:
    return str(get_parent().name) if use_parent_name else node_id