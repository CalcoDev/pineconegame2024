extends Node

func _ready() -> void:
    var nodes = DialogueLexer.lex_file("res://resources/dialogue/dia_sample.txt")
    var d = DialogueParser.parse_node(nodes.values()[1])
    print(d)
    print(d)
