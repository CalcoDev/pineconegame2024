class_name DialogueRunner

func prepare_file(filepath: String) -> void:
	var file := FileAccess.open(filepath, FileAccess.READ)
	assert(file != null, "Could not open filepath for dialogue!")
	var raw_file := file.get_as_text()
	
	var lexed = DialogueLexer.lex_nodes()
	
	file.close()