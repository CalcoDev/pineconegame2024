class_name Helicopter
extends Node2D
# extends CharacterBody2D

@export var scene: HelicopterFightScene
@export var player_offset: Vector2 = Vector2(180, 0)

@export var charge_warn_display: Array[AnimatedSprite2D] = []

@export var anim: AnimationPlayer

@export var propeller: Node2D
@export var propeller_fire_spot: Marker2D
@export var propeller_anim: AnimationPlayer

@export var touhou_bullet_time: float = 0.2
@export var touhou_bullet_count: int = 1
@export var touhou_bullet_rand: float = 15.0
@export var touhou_bullet_prefab: PackedScene
@export var touhou_bullet_spawn: Marker2D
@export var touhou_bullet_speed: float = 20.0
@export var touhou_bullet_max_fan: float = 30.0

# different attacks
# const ST_IDLE := 1 # just move around, waiting for thing, also used in battle mode
# const ST_CHARGE := 2 # split screen in 3 vsplits, ccharge on one of them
# const ST_PROPELLER_THROW := 3 # throw propeller in funky ways
# const ST_TOUHOU := 4 # spin and SHOTO BULLET BULLET HELL WOOO
# const ST_VBRS := 5 # spawn a few vbrs that'll shoot more bullet lol
# var state := ST_IDLE

# var pos_offset := Vector2.ZERO

func _enter_tree() -> void:
	propeller_anim.play("exit")
	propeller_anim.seek(999.9, true)
	charge_warn_display[0].get_parent().visible = true
	for c in charge_warn_display:
		c.visible = false
		c.stop()

func _ready() -> void:
	global_position = player_offset

# var base := Vector2.ZERO
func _process(_delta: float) -> void:
	# charge_warn_display[0].get_parent().global_position = scene.camera.top_left_corner
	# self.global_position = scene.camera.global_position + player_offset + pos_offset
	pass

const _attacks := ["attack_charge", "attack_propeller_throw", "attack_touhou", "attack_vbrs"]
func attack() -> void:
	# var idx := randi() % _attacks.size()
	# await self.get(_attacks[idx]).call()
	# await attack_charge()
	# await attack_propeller_throw()
	await attack_touhou()

func attack_charge() -> void:
	var lane := randi() % 3

	await get_tree().create_timer(1).timeout

	var d := charge_warn_display[lane]
	var t := create_tween().set_ease(Tween.EASE_IN_OUT)
	var init_y := self.global_position.y
	t.tween_method(
		func(tt: float):
			var target: float = (d.get_child(0).global_position).y - 40.0
			self.global_position.y = lerp(init_y, target, tt),
		0.0, 1.0,
		0.5
	)
	t.play()
	await t.finished

	t = create_tween().set_ease(Tween.EASE_IN_OUT)
	t.tween_property(d, "scale", Vector2(1.0, 1.0), 0.75)
	d.scale = Vector2(0.0, 1.0)
	d.visible = true
	d.get_parent().global_position.x = self.global_position.x
	d.play("default")
	t.play()
	await t.finished
	await get_tree().create_timer(randf_range(2.5, 4.5)).timeout
	var y := d.position.y
	t = create_tween().set_ease(Tween.EASE_IN_OUT)
	t.tween_property(d, "position", Vector2(-1000.0, y), 0.5)
	var curr_y := global_position.y
	t.parallel().tween_property(self, "global_position", Vector2(-288.0, curr_y), 1.0)
	t.play()
	await t.finished
	d.position = Vector2(-353.0, y)
	d.visible = false

	t = create_tween().set_ease(Tween.EASE_IN_OUT)
	self.global_position = Vector2(240.0, curr_y)
	t.tween_property(self, "global_position", player_offset + Vector2(0, curr_y), 1.0)
	t.play()
	
	await t.finished
	await _go_to_lane(1)

signal _on_propeller_throw_done()
var _propeller_lane: int = -1
func attack_propeller_throw() -> void:
	var lane := randi() % 3
	_propeller_lane = lane
	await _go_to_lane(lane)
	anim.play("throw_propeller")
	await anim.animation_finished
	anim.play("idle_rotate")
	await _on_propeller_throw_done
	await _go_to_lane(1)

func _throw_propeller() -> void:
	propeller.global_position = propeller_fire_spot.global_position
	propeller_anim.play("enter")
	await propeller_anim.animation_finished
	propeller_anim.play("spinny_boi_" + str(_propeller_lane))
	if _propeller_lane == 1:
		propeller_anim.speed_scale = 0.3
	else:
		propeller_anim.speed_scale = 0.9
	await propeller_anim.animation_finished
	propeller_anim.speed_scale = 1.0
	propeller_anim.play("exit")
	await propeller_anim.animation_finished
	_on_propeller_throw_done.emit()

func _go_to_lane(lane: int) -> void:
	var t := create_tween().set_ease(Tween.EASE_IN_OUT)
	var init_y := self.global_position.y
	t.tween_method(
		func(tt: float):
			var target: float = (charge_warn_display[lane].get_child(0).global_position).y - 40.0
			self.global_position.y = lerp(init_y, target, tt),
		0.0, 1.0,
		0.5
	)
	t.play()
	await t.finished

func attack_touhou() -> void:
	await _go_to_lane(1)
	anim.speed_scale = 2.0
	anim.play("attack_touhou_2")

	var bullet_timer := 0.0

	var t := 0.0
	while t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		bullet_timer += get_process_delta_time()
		if bullet_timer > touhou_bullet_time:
			bullet_timer = 0.0
			for i in touhou_bullet_count:
				var signed_i := i - floori(touhou_bullet_count / 2)
				var b: HelicopterBullet = touhou_bullet_prefab.instantiate()
				b.global_position = touhou_bullet_spawn.global_position
				var rot := touhou_bullet_spawn.global_rotation
				rot += randf_range(-touhou_bullet_rand, touhou_bullet_rand)
				rot += touhou_bullet_max_fan * float(signed_i) / float(touhou_bullet_count / 2)
				b.global_rotation = rot
				b.velocity = Vector2.RIGHT.rotated(rot) * touhou_bullet_speed
				# add_child(b)
				scene.add_child(b)
	anim.speed_scale = 1.0
	anim.play("idle_rotate")
	await _go_to_lane(1)

func attack_vbrs() -> void:
	pass