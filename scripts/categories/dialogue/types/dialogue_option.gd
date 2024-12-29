class_name DialogueOption

var idx: int
var text: String
@warning_ignore("shadowed_variable")
func _init(idx: int, text: String):
    self.idx = idx
    self.text = text
