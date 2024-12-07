class_name DiaLineView
extends DialogueView

@export var text_lbl: RichTextLabel
@export var speaker_sprite: AnimatedSprite2D
@export var box_animator: AnimationPlayer

var _is_shown: bool = false
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
    if not _is_shown:
        _hide(true)

func _process(delta: float) -> void:
    if _is_shown:
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


func dialogue_started() -> void:
    print("line view: started")
    _show()

func dialogue_completed() -> void:
    print("line view: completed")
    _hide()

func _run_line(line: DialogueLine, on_finished: Callable) -> void:
    _is_running = true
   
    _line = line
    text_lbl.text = _line.text
    text_lbl.visible_characters = 0
    _characters = 0.0
    
    _on_line_finished = on_finished
    
    _speaker = _runner.get_speaker(_line.speaker_name)
    if _speaker.sprite_frames == null:
        # not a real animation, just changing some sizes and visibilities
        var prev_anim := box_animator.current_animation
        var prev_time := box_animator.current_animation_position
        box_animator.play("hide_speaker")
        box_animator.seek(999.9, true)
        box_animator.play(prev_anim)
        box_animator.seek(prev_time, true)
        pass
    else:
        # not a real animation, just changing some sizes and visibilities
        var prev_anim := box_animator.current_animation
        var prev_time := box_animator.current_animation_position
        box_animator.play("show_speaker")
        box_animator.seek(999.9, true)
        box_animator.play(prev_anim)
        box_animator.seek(prev_time, true)
        speaker_sprite.sprite_frames = _speaker.sprite_frames
        speaker_sprite.play("talk")

func _show() -> void:
    _is_shown = true
    box_animator.play("show")
    await box_animator.animation_finished

func _hide(instant: bool = false) -> void:
    _is_shown = false
    box_animator.play("hide")
    if not instant:
        await box_animator.animation_finished
    else:
        box_animator.seek(999.0, true)
