class_name PlayerCamera
extends Node2D

@export var player: Player

# func _notification(what: int) -> void:
#     match what:
#         NOTIFICATION_INTERNAL_PROCESS:
#             global_position = player.global_position
    
# func _enter_tree() -> void:
#     set_process_internal(true)

func _process(_delta: float) -> void:
    # position = position.lerp(player.velocity / 10, delta * 10)
#     global_position = player.global_position
    # print(global_position)
    pass