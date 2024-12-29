class_name DiaOptionView
extends DialogueView

# .x = nr of cols .y = nr of rows
@export var options_grid_size: Vector2i = Vector2i(3, 3)
@export var options_node: Node
@export var dia_box: DiaBoxView

class OptionNode:
    var hbox: HBoxContainer
    var selected: Control
    var label: RichTextLabel
    # var idx: int
    @warning_ignore("shadowed_variable")
    func _init(hbox: HBoxContainer, selected: Control, label: RichTextLabel) -> void:
        # self.idx = idx
        self.hbox = hbox
        self.selected = selected
        self.label = label
    func hide() -> void:
        self.hbox.visible = false
    func show(text: String) -> void:
        self.hbox.visible = true
        self.label.text = text
    func mark_selected() -> void:
        selected.visible = true
    func unmark_selected() -> void:
        selected.visible = false

# [idx -> Array]
# var _option_nodes: Dictionary
var _option_nodes: Array[OptionNode]
var _option_node_cols: Array[VBoxContainer]

var _is_started: bool = false
var _is_running: bool = false

var _options: Array[DialogueOption]
var _on_option_selected: Callable
var _active_options_grid_size: Vector2i = options_grid_size

var _selected_option_idx: int = 0

func _enter_tree() -> void:
    self.on_run_options.connect(_run_options)

    var opts := options_node.find_children("*", "HBoxContainer", true)
    _option_nodes = []
    _option_nodes.resize(opts.size())
    for opt: HBoxContainer in opts:
        _option_nodes[int(str(opt.name)) - 1] = OptionNode.new(opt, opt.get_child(0), opt.get_child(1))
    var opt_cols := options_node.find_children("*", "VBoxContainer", true)
    _option_node_cols = []
    for col: VBoxContainer in opt_cols:
        _option_node_cols.append(col)

func _ready() -> void:
    if not _is_running:
        dia_box.play_animation("hide_optionview", 999.0, true)

func _process(_delta: float) -> void:
    if dia_box._is_shown and _is_started:
        if _is_running:
            # invert y because array yknow
            var inp_col := int(Input.is_action_just_pressed("dia_opt_right")) - int(Input.is_action_just_pressed("dia_opt_left"))
            var inp_row := -1 * (int(Input.is_action_just_pressed("dia_opt_up")) - int(Input.is_action_just_pressed("dia_opt_down")))
            var old_idx := _selected_option_idx
            if inp_col != 0 or inp_row != 0:
                _move_idx_by_vec(inp_row, inp_col) # transposed cuz [col1, col2, col3]
                if old_idx != _selected_option_idx:
                    _option_nodes[old_idx].unmark_selected()
                    _option_nodes[_selected_option_idx].mark_selected()
            if Input.is_action_just_pressed("dia_opt_select"):
                _on_option_selected.call(_selected_option_idx)
                dia_box.play_animation("hide_optionview", 999.0, true)

func dialogue_started() -> void:
    _is_started = true

func dialogue_completed() -> void:
    _is_started = false

func _run_options(options: Array[DialogueOption], on_selected: Callable) -> void:
    _is_running = true
    dia_box.play_animation("show_optionview", 999.0, true)

    _options = options
    _on_option_selected = on_selected
    _selected_option_idx = _options[0].idx
    _show_opts()
    
    # nr of cols
    _active_options_grid_size.x = maxi(1, ceili(_options.size() as float / options_grid_size.y))
    # nr of rows
    _active_options_grid_size.y = (_options.size() % options_grid_size.y) + 1 if _active_options_grid_size.x == 1 else options_grid_size.y

func _show_opts() -> void:
    for opt in _option_nodes:
        opt.hide()
        opt.unmark_selected()
    for opt in _options:
        _option_nodes[opt.idx].show(opt.text)

    for opt_col in _option_node_cols:
        var should_hide := true
        for c in opt_col.get_children():
            if c.visible:
                should_hide = false
                break
        opt_col.visible = not should_hide

    _option_nodes[_selected_option_idx].mark_selected()

func _move_idx_by_vec(row: int, col: int) -> void:
    var curr_row: int = _selected_option_idx % options_grid_size.y
    @warning_ignore("integer_division")
    var curr_col: int = _selected_option_idx / options_grid_size.y
    var next_row: int = (curr_row + row) % _active_options_grid_size.y
    var next_col: int = (curr_col + col) % _active_options_grid_size.x
    var idx := next_col * _active_options_grid_size.y + next_row
    var orig := idx
    while idx >= _options.size():
        next_row = (curr_row + row) % _active_options_grid_size.y
        next_col = (curr_col + col) % _active_options_grid_size.x
        idx = next_col * _active_options_grid_size.y + next_row
        if idx == orig:
            orig = -1
            break
    if orig == -1:
        return
    _selected_option_idx = idx
