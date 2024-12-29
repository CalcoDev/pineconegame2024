class_name DialogueCommand

var raw: String
var cmd: String
var args: Array[String]
@warning_ignore("shadowed_variable")
func _init(raw: String, cmd: String, args: Array[String]) -> void:
    self.raw = raw
    self.cmd = cmd
    self.args = args