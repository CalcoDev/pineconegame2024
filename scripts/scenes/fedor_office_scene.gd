extends Node2D

func beign_intro_cutscene() -> void:
	Player.instance.locked = true
	Player.instance.freeze = true

func end_intro_cutscene() -> void:
	Player.instance.locked = false
	Player.instance.freeze = false

func play_audio(audio: String) -> void:
	Audio.map[audio].play()

func stop_audio(audio: String) -> void:
	Audio.map[audio].stop()