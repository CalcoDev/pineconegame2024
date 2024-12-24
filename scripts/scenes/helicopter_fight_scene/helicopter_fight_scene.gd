class_name HelicopterFightScene
extends Node2D

static var instance: HelicopterFightScene

@export_group("Scene Refs")
@export var player: Player
@export var helicopter: Helicopter
@export var room: Room
@export var camera: GameCamera
@export var parallax: ParallaxBackground
# @export var parallax: Array[ParallaxLayer] = []

@export var speed_lines: ColorRect

@export_group("Battle System")
# @export_subgroup("Screen")
# @export var 

@export_subgroup("Dialogue")
@export var dialogue: DialogueRunner
@export var dia_view: DialogueView
@export var dia_view_pos_anim: AnimationPlayer

@export_subgroup("Options Display")
@export var anim: AnimationPlayer
@export var kongle_select_opt: Control
@export var options: Array[TextureRect] = []

@export_group("Values")
@export var hue_shift_speed := 0.3
@export var parallax_add_speed := Vector2(1.0, 1.0)
@export var parallax_sin_freq := 2.0
@export var parallax_sin_ampl := 50.0

const ST_PLAYER := 0
const ST_ENEMY_ATK := 1

var state: int = ST_PLAYER
var turn_count: int = 0

var is_over: bool = false

var is_paused: bool = false

var helicopter_curr_line := 0

var _max_tok_fight := -1
var _max_tok_item := -1
var _max_tok_act := -1
var _max_tok_mercy := -1

func _enter_tree() -> void:
	dialogue.prepare_dialogue("res://resources/dialogue/dia_helicopter_battle.txt")
	_max_tok_fight = _load_and_save_toks("res://resources/dialogue/dia_fail_fight.txt")
	_max_tok_item = _load_and_save_toks("res://resources/dialogue/dia_fail_item.txt")
	_max_tok_act = _load_and_save_toks("res://resources/dialogue/dia_fail_act.txt")
	_max_tok_mercy = _load_and_save_toks("res://resources/dialogue/dia_fail_mercy.txt")

	instance = self

func _load_and_save_toks(filepath: String) -> int:
	var toks := dialogue.prepare_dialogue(filepath)
	var tok_max := -1
	for tok in toks:
		var t: String = tok.split("_")[-1]
		var it := int(t)
		if it == 0 and t != '0':
			assert(false, "what? this shouldnt happen ???")
		tok_max = maxi(tok_max, it)
	return tok_max

func _ready() -> void:
	anim.play("battle_screen_exit")
	anim.seek(999.9, true)
	# start_battle()
	await get_tree().create_timer(1).timeout
	_enemy_attack()
	dia_view.on_run_line.connect(_run_dialogue_line)

var __offset_sin := 0.0
var __base_offset := Vector2.ZERO
var __offset := Vector2.ZERO
var __player_offset := Vector2.ZERO
func _process(delta: float) -> void:
	if not is_paused:
		var wrapped := _wrap_around_bounds(player.global_position, 4.0)
		if not player.global_position.is_equal_approx(wrapped):
			player.global_position = wrapped
		__offset_sin += delta * parallax_sin_freq
		__base_offset += delta * parallax_add_speed * (-1.0 if player.linear_velocity.x > 0 else 1.0)
		__offset.y = sin(__offset_sin) * parallax_sin_ampl
		__player_offset -= player.linear_velocity * delta
		parallax.scroll_base_offset = __base_offset + __offset + __player_offset

func _wrap_around_bounds(vec: Vector2, epsilon: float = 2.0) -> Vector2:
	var size = room.coll.shape.size * 0.5
	var pos = global_position

	if vec.x < pos.x - size.x - epsilon:
		vec.x = pos.x + size.x + epsilon * 0.75
	elif vec.x > pos.x + size.x + epsilon:
		vec.x = pos.x - size.x - epsilon * 0.75

	if vec.y < pos.y - size.y - epsilon:
		vec.y = pos.y + size.y + epsilon * 0.75
	elif vec.y > pos.y + size.y + epsilon:
		vec.y = pos.y - size.y - epsilon * 0.75

	return vec

func _run_dialogue_line(line: DialogueLine, _on_finished: Callable) -> void:
	dia_view_pos_anim.play(line.speaker_name)

func start_battle() -> void:
	is_over = false
	state = ST_PLAYER
	turn_count = 0
	while not is_over:
		turn_count += 1
		await do_turn()
	anim.play("battle_end")
	await anim.animation_finished

func do_turn() -> void:
	if not is_paused:
		_pause_world()
	await _show_player_ui()
	await _player_do_action()
	await _enemy_say_lines()
	await _enemy_attack()
	player.global_position = Vector2.ZERO
	player.rotation = 0.0

func _pause_world() -> void:
	player.locked = true
	player.freeze = true
	player.global_position = player.global_position.round()
	speed_lines.visible = false

func _unpause_world() -> void:
	player.locked = false
	player.freeze = false
	speed_lines.visible = true

func _show_player_ui() -> void:
	if turn_count == 1:
		anim.play("battle_begin")
		await anim.animation_finished
	kongle_select_opt.visible = false
	anim.play("battle_screen_enter")
	await anim.animation_finished

func _player_do_action() -> void:
	kongle_select_opt.visible = true
	
	var confirmed_opt := -1
	var selected_hue := 0.0
	
	var offset_sin := 0.0
	var base_offset := parallax.scroll_base_offset
	var offset := Vector2.ZERO

	var opt := 0
	_select_opt(opt)
	while confirmed_opt < 0:
		await get_tree().process_frame
		# update selected option
		options[opt].modulate = Color.from_hsv(selected_hue, 0.90, 0.85, 1.0)
		selected_hue += get_process_delta_time() * hue_shift_speed
		# update parallax background
		offset_sin += get_process_delta_time() * parallax_sin_freq
		base_offset += get_process_delta_time() * parallax_add_speed
		offset.y = sin(offset_sin) * parallax_sin_ampl
		parallax.scroll_base_offset = base_offset + offset

		var curr_opt := opt
		if Input.is_action_just_pressed("dia_opt_left"):
			curr_opt = (4 + (curr_opt - 1)) % 4
		if Input.is_action_just_pressed("dia_opt_right"):
			curr_opt = (4 + (curr_opt + 1)) % 4
		if curr_opt != opt:
			_deselect_deopt(opt)
			opt = curr_opt
			_select_opt(opt)
		if Input.is_action_just_pressed("dia_opt_select"):
			confirmed_opt = curr_opt

	_deselect_deopt(confirmed_opt)
	kongle_select_opt.visible = false
	await _handle_opt(confirmed_opt)

func _handle_opt(opt: int) -> void:
	match opt:
		0: # fight
			print("you fought. you won?")
			await dialogue.start_dialogue("try_fight_" + str(randi() % (_max_tok_fight + 1)))
		1: # item
			print("you used an item?")
			await dialogue.start_dialogue("try_item_" + str(randi() % (_max_tok_item + 1)))
		2: # act
			print("you acted (nikolas?!?!?)")
			await dialogue.start_dialogue("try_act_" + str(randi() % (_max_tok_act + 1)))
		3: # mercy
			print("no mercy.  cant spare a helicopter")
			await dialogue.start_dialogue("try_mercy_" + str(randi() % (_max_tok_mercy + 1)))

func _deselect_deopt(opt: int) -> void:
	options[opt].modulate = Color.hex(0xffffffff)

func _select_opt(opt: int) -> void:
	# TODO(calco): play some audio thing
	options[opt].modulate = Color.hex(0xffffffff) # make it chroma inside update lmfao
	kongle_select_opt.global_position = options[opt].get_child(0).global_position

func _enemy_say_lines() -> void:
	var id := "helicopter_" + str(helicopter_curr_line)
	if dialogue.node_exists(id):
		await dialogue.start_dialogue(id)
		helicopter_curr_line += 1

func _enemy_attack() -> void:
	anim.play("battle_screen_exit")
	await anim.animation_finished
	_unpause_world()
	await helicopter.attack()
