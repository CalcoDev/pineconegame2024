class_name MovingPlatformPoint
extends Marker2D

enum LoopType {
    NONE,
    TO_PREVIOUS,
    WRAP_AROUND
}

@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var loop: LoopType = LoopType.NONE

func poll_move_type_begin() -> void:
    return