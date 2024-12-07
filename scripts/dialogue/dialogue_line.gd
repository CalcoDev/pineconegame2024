class_name DialogueLine

@export var speaker_name: String
@export var text: String

@warning_ignore("shadowed_variable")
func _init(speaker_name: String, text: String) -> void:
    self.speaker_name = speaker_name
    self.text = text