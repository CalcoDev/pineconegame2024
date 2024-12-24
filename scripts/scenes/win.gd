extends Node2D

@export var bplay: Button
@export var bquit: Button

func _enter_tree() -> void:
	bplay.pressed.connect(
		func():
			get_tree().change_scene_to_file("res://scenes/story_scenes/made_with_kongle.tscn")
	)
	bquit.pressed.connect(
		func():
			get_tree().quit()
	)

# func _ready() -> void:
# 	Audio.map["gojo"].play()

# func _exit_tree() -> void:
# 	Audio.map["gojo"].stop()