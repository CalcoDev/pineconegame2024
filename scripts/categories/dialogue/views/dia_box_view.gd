class_name DiaBoxView
extends DialogueView

@export var box_animator: AnimationPlayer
@export var view_animator: AnimationPlayer
var _is_shown: bool = false

func _enter_tree() -> void:
    if not _is_shown:
        _hide(true)

func play_animation(animation: String, seek: float = 0.0, _resume_old: bool = false) -> void:
    #var prev_anim := view_animator.current_animation
    #var prev_time := view_animator.current_animation_position
    view_animator.play(animation)
    view_animator.seek(seek, true)
    #if resume_old:
        #view_animator.play(prev_anim)
        #view_animator.seek(prev_time, true)

func dialogue_started() -> void:
    _show()
    
func dialogue_completed() -> void:
    _hide()

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
