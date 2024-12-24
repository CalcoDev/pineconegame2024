extends AnimatedSprite2D

@export var spr: AnimatedSprite2D
@export var speed: float = 2.0

var h := 0.0
func _process(delta: float) -> void:
	h += delta * speed
	(material as ShaderMaterial).set("shader_parameter/outline_color", Color.from_hsv(h, 1.0, 0.76, 1.0))
	(spr.material as ShaderMaterial).set("shader_parameter/outline_color", Color.from_hsv(h, 1.0, 0.76, 1.0))
	(material as ShaderMaterial).set("shader_parameter/solid_color", Color.from_hsv(h + 0.5, 1.0, 0.76, 0.4))
	(spr.material as ShaderMaterial).set("shader_parameter/solid_color", Color.from_hsv(h + 0.5, 1.0, 0.76, 0.4))
