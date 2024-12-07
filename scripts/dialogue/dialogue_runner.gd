class_name DialogueRunner
extends Node

# runs when a command is run
signal on_command(command: String)
# runs when dialogue is entirely finished
signal on_dia_complete()
# runs when new dialogue is started
signal on_dia_start()
# runs when current node finished
signal on_node_complete()
# runs when a new node starts
signal on_node_start()

@export var dialogue_views: Array[DialogueView] = []
@export var run_selected_option_as_line: bool = false

# todo(calco): this shouhld be moved from here
@export_dir var speakers_directory: String = ""
# [name -> DialogueSpeakerRes]
var _speakers: Dictionary = {}

var current_node_name: String = ""
var is_running: bool = false

# dict[string, array[callable]]
var _command_handlers: Dictionary = {}

# dict[string, Array[Parser.Token]]
var _dialogue_nodes_tokens: Dictionary = {}

# adds a function to handle custom command. cutscenes and stuff.
# might be scrapped in favour of gdscript thing
func add_command_handler(command: String, handler: Callable) -> void:
    _command_handlers.get_or_add(command, []).append(handler)

# removes a function to handle custom command. cutscenes and stuff.
# might be scrapped in favour of gdscript thing
func remove_command_handler(command: String, handler: Callable) -> void:
    if command not in _command_handlers:
        return
    var idx := (_command_handlers[command] as Array[Callable]).find(handler)
    if idx == -1:
        return
    (_command_handlers[command] as Array[Callable]).remove_at(idx)

# loads all nodes from a dialogue and prepares them for being ran.
func prepare_dialogue(filepath: String) -> void:
    var file := FileAccess.open(filepath, FileAccess.READ)
    assert(file != null, "Could not open filepath for dialogue!")
    var raw_file := file.get_as_text()
    
    var lexed_nodes_dict := DialogueLexer.lex_nodes(raw_file)
    for node: DialogueLexer.NodeData in lexed_nodes_dict.values():
        var parsed_dict := DialogueParser.parse_node(node)
        assert(node.title not in _dialogue_nodes_tokens, "Node title already present!")
        _dialogue_nodes_tokens[node.title] = parsed_dict["tokens"]
    file.close()

# removes all loaded dialogue nodes
func clear_dialogue() -> void:
    _dialogue_nodes_tokens.clear()

# check whether node is loaded
func node_exists(title: String) -> bool:
    return title in _dialogue_nodes_tokens

# starts playing a node from the loaded list
func start_dialogue(node_title: String = "main") -> void:
    if not is_running:
        is_running = true
        _start_dialogue()
    current_node_name = node_title
    await _start_node_coro()
    stop()

# stops playing a node from the loaded list
func stop() -> void:
    is_running = false
    _complete_dialogue()

func _start_node_coro() -> void:
    var current: DialogueParser.Token = _dialogue_nodes_tokens[current_node_name][0]
    while current != null:
        match current.type:
            DialogueParser.Token.LINE:
                var line := current as DialogueParser.TokenLine
                var state := {"sum": 0}
                var on_finished := func():
                    state["sum"] += 1
                var cnt = _views_run_line(line.dia_line, on_finished)
                while state["sum"] < cnt:
                    await get_tree().process_frame
            DialogueParser.Token.OPTION:
                var opt := current as DialogueParser.TokenOption
                # TODO(calco): We can only handle a single selectio atm lol
                var state := {"sum": 0, "index": 0}
                var on_finished := func(index: int):
                    state["sum"] += 1
                    state["index"] = index
                var cnt := _views_run_options(opt.generate_dialogue_options(), on_finished)
                while state["sum"] < cnt:
                    await get_tree().process_frame
                current = opt.options[state["index"]].next
                continue # break out of loopo as I mannually asign next
            DialogueParser.Token.INSTRUCTION:
                var instr := current as DialogueParser.TokenInstruction
                print("command: ", instr.value)
                # on_command.emit(instr.)
            DialogueParser.Token.CODE:
                var code := current as DialogueParser.TokenCode
                print("code: ", code.value)
        current = current.next

func _start_dialogue() -> void:
    on_dia_start.emit()
    for view in dialogue_views:
        view._runner = self # todo(calco): should be somwhere else but ynknow
        view.dialogue_started()

func _complete_dialogue() -> void:
    on_dia_complete.emit()
    for view in dialogue_views:
        view.dialogue_completed()

func _views_run_line(line: DialogueLine, on_finished: Callable) -> int:
    var s: int = 0
    for view in dialogue_views:
        if view.can_handle_line():
            view.run_line.emit(line, on_finished)
            s += 1
    return s

func _views_run_options(options: Array[DialogueOption], on_selected: Callable) -> int:
    var s: int = 0
    for view in dialogue_views:
        if view.can_handle_options():
            view.run_options.emit(options, on_selected)
            s += 1
    return s

func _enter_tree() -> void:
    _load_speakers()

func get_speaker(speaker_name: String) -> DialogueSpeakerRes:
    assert(speaker_name in _speakers, "Could not find speaker!")
    return _speakers[speaker_name]

func _load_speakers() -> void:
    var dir_q = []
    var speakers_dir = DirAccess.open(speakers_directory)
    dir_q.append([speakers_dir, speakers_directory])
    while len(dir_q) > 0:
        var dir = dir_q[0][0]
        var path = dir_q[0][1]
        dir_q.remove_at(0)
        dir.list_dir_begin()
        var file_path = dir.get_next()
        while file_path != "":
            var full_path = path + "/" + file_path
            if dir.current_is_dir():
                dir_q.append([DirAccess.open(full_path), full_path])
                file_path = dir.get_next()
                continue
            var res = ResourceLoader.load(full_path)
            if res is DialogueSpeakerRes:
                _speakers[res.name] = res
            file_path = dir.get_next()
