class_name DiaLineView
extends DialogueView

@export var text_lbl: RichTextLabel
@export var speaker_sprite: AnimatedSprite2D
@export var dia_box: DiaBoxView

var _is_started: bool = false
var _is_running: bool = false

var _line: DialogueLine
var _on_line_finished: Callable
var _speaker: DialogueSpeakerRes

var _speed: float = 10.0:
    set(value):
        _speed = value
        # speaker_sprite.speed_scale = _speed
        # box_animator.speed_scale = _speed
var _characters: float = 0.0

func _enter_tree() -> void:
    self.run_line.connect(_run_line)

func _ready() -> void:
    if not _is_running:
        dia_box.play_animation("hide_lineview", 999.0, true)

func _process(delta: float) -> void:
    if dia_box._is_shown and _is_started:
        if _is_running:
            # skip to end
            if Input.is_action_just_pressed("dia_skip"):
                _characters = text_lbl.text.length()
            # display text
            _characters += _speed * delta
            text_lbl.visible_characters = floori(_characters)
            if text_lbl.visible_ratio >= 1.0:
                _is_running = false
        # await user input
        else:
            if Input.is_action_just_pressed("dia_next"):
                _on_line_finished.call()
                dia_box.play_animation("hide_lineview", 999.0, true)

func dialogue_started() -> void:
    _is_started = true

func dialogue_completed() -> void:
    _is_started = false

func _run_line(line: DialogueLine, on_finished: Callable) -> void:
    _is_running = true

    dia_box.play_animation("show_lineview", 999.0, true)
   
    _line = line
    text_lbl.text = _line.text
    text_lbl.visible_characters = 0
    _characters = 0.0
    
    _on_line_finished = on_finished
    
    _speaker = _runner.get_speaker(_line.speaker_name)
        # not a real animation, just changing some sizes and visibilities
    if _speaker.sprite_frames == null:
        dia_box.play_animation("hide_speaker", 999.0, true)
    else:
        dia_box.play_animation("show_speaker", 999.0, true)
        speaker_sprite.sprite_frames = _speaker.sprite_frames
        speaker_sprite.play("talk")
