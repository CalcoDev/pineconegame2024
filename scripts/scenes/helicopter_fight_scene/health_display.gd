class_name HealthDisplay
extends Control

@export var bar: ProgressBar
@export var health: HealthComponent

func _ready() -> void:
    health.on_health_changed.connect(changed)
    await get_tree().create_timer(0.1).timeout
    changed(health.max_health, health.max_health, health.max_health)

func changed(_previous: float, current: float, maximum: float) -> void:
    bar.min_value = 0.0
    bar.max_value = maximum
    bar.value = current