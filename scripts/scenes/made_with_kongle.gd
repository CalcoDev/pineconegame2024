extends Node2D

func start() -> void:
	Audio.map["intro_kongle_slide"].play()
	await get_tree().create_timer((1.1 - 0.4) / 0.4).timeout
	Audio.map["intro_kongle_slide"].stop()
	await get_tree().create_timer((1.23 - 1.1) / 0.4).timeout
	Audio.map["intro_kongle_slide"].play()

func next_scene() -> void:
	Audio.map["intro_kongle_slide"].stop()
	get_tree().change_scene_to_file("res://scenes/story_scenes/fedor_office_scene.tscn")