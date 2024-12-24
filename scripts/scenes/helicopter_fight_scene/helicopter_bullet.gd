class_name HelicopterBullet
extends Sprite2D

@export var hitbox: HitboxComponent
var velocity := Vector2.ZERO

func _enter_tree() -> void:
	hitbox.on_hit.connect(_on_hit)

func _process(delta: float) -> void:
	global_position += velocity * delta
	if _wrap_around_bounds(global_position, 6.0):
		queue_free()

func _on_hit(_hurtbox: HurtboxComponent) -> void:
	queue_free()

func _wrap_around_bounds(vec: Vector2, epsilon: float = 2.0) -> bool:
	var size = HelicopterFightScene.instance.room.coll.shape.size * 0.5
	var pos = global_position
	if vec.x < pos.x - size.x - epsilon:
		return true
	elif vec.x > pos.x + size.x + epsilon:
		return true
	if vec.y < pos.y - size.y - epsilon:
		return true
	elif vec.y > pos.y + size.y + epsilon:
		return true
	return false
