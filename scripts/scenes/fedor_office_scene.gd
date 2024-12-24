class_name FedorOfficeScene
extends Node2D

static var instance: FedorOfficeScene

@export var fp_left: DialogueInteraction
@export var fp_right: DialogueInteraction
@export var fedor_anim: AnimationPlayer
@export var fedor: AnimatedSprite2D

@export var mirror: Area2D

@export var big_anim: AnimationPlayer

@export var rooms: Array[Room]

var left := false
var right := false
func _enter_tree() -> void:
	instance = self

	fp_left.on_interaction_finished.connect(
		func(interactor):
			if interactor == Player.instance._interactor:
				left = true
			if left and right:
				fedor_anim.play("enter")
	)
	fp_right.on_interaction_finished.connect(
		func(interactor):
			if interactor == Player.instance._interactor:
				right = true
			if left and right:
				fedor_anim.play("enter")
	)

	for room in rooms:
		room.on_enter_room.connect(
			func():
				InteractionManager.instance._hide_all()
		)

func beign_intro_cutscene() -> void:
	Player.instance.locked = true
	Player.instance.freeze = true

func end_intro_cutscene() -> void:
	Player.instance.locked = false
	Player.instance.freeze = false

func set_pausec(v: bool) -> void:
	get_tree().paused = v

func play_dialogue(name: String) -> void:
	await DialogueManager.r.start_dialogue(name)
	set_pausec(false)
	fedor_anim.play("spawn_window")
	await fedor_anim.animation_finished
	mirror.body_entered.connect(
		func(body):
			mirror.collision_mask = 0
			if body == Player.instance:
				fedor_anim.play("byebye")
				await fedor_anim.animation_finished
				get_tree().change_scene_to_file("res://scenes/story_scenes/helicopter_fight_scene.tscn")
				InteractionManager.instance.queue_free()
				InteractionManager.instance = null
	)

func play_audio(audio: String) -> void:
	Audio.map[audio].play()

func stop_audio(audio: String) -> void:
	Audio.map[audio].stop()
