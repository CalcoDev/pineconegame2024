extends Node

@export var runner: DialogueRunner
# var runner := DialogueRunner.new()

func _ready() -> void:
    runner.prepare_dialogue("res://resources/dialogue/dia_sample.txt")
    runner.start_dialogue()
    # get_tree().create_timer(0.2).timeout.connect(func(): runner.start_dialogue())
