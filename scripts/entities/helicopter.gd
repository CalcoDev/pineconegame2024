class_name Helicopter
extends CharacterBody2D

@export var scene: HelicopterFightScene
@export var player_offset: Vector2 = Vector2(180, 0)

# different attacks
const ST_IDLE := 1 # just move around, waiting for thing, also used in battle mode
const ST_CHARGE := 2 # split screen in 3 vsplits, ccharge on one of them
const ST_PROPELLER_THROW := 3 # throw propeller in funky ways
const ST_TOUHOU := 4 # spin and SHOTO BULLET BULLET HELL WOOO
const ST_VBRS := 5 # spawn a few vbrs that'll shoot more bullet lol

var state := ST_IDLE

func _ready() -> void:
	pass

var base := Vector2.ZERO
func _process(_delta: float) -> void:
	self.global_position = scene.camera.global_position + player_offset

func move(motion: Vector2):
	var col = move_and_collide(Vector2.RIGHT * motion.x)
	if col != null:
		var norm = col.get_normal()
		var dir = get_perpendicular(norm)
		var ang = norm.angle_to(motion)
		if ang > 0:
			dir.x *= -1
			dir.y *= -1
		# if PI - abs(ang) > deg_to_rad(WallSlideAngle):
		# 	move_and_collide(dir * col.get_remainder().length())
	col = move_and_collide(Vector2.DOWN * motion.y)
	if col != null:
		var norm = col.get_normal()
		var dir = get_perpendicular(norm)
		var ang = norm.angle_to(motion)
		if ang > 0:
			dir.x *= -1
			dir.y *= -1
		# if PI - abs(ang) > deg_to_rad(WallSlideAngle):
		# 	move_and_collide(dir * col.get_remainder().length())
 
func v2_v3(vec):
	return Vector2(vec.x, vec.z)

func v3_v2(vec):
	return Vector3(vec.x, 0, vec.y)

func get_perpendicular(vec):
	return v2_v3(Vector3.UP.cross(v3_v2(vec)))
