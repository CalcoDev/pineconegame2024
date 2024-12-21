class_name Interactor
extends Area2D

signal on_try_interact(interactor: Interactor)

func try_interact() -> void:
    on_try_interact.emit(self)