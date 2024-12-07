class_name DialogueLexer

class Token:
	enum {LINE, OPTION, INSTRUCTION, CODE}
	var indent: int
	var type: int
	var text: String
	@warning_ignore("shadowed_variable")
	func _init(indent, type: int, text: String):
		self.indent = indent
		self.type = type
		self.text = text

class NodeData:
	var title: String
	var tokens: Array[Token]
	
	@warning_ignore("shadowed_variable")
	func _init(title, tokens):
		self.title = title
		self.tokens = tokens
	
	func _to_string() -> String:
		var s = "title: " + title + " \n"
		for token in tokens:
			s += "\nTOKEN: \n"
			s += "indent: " + str(token.indent) + "\ntype: " + str(token.type) + "\ntext: " + token.text + "\n"
			s += "\n"
		s += "\n"
		return s
	
static func lex_file(filepath: String) -> Dictionary:
	var file := FileAccess.open(filepath, FileAccess.READ)
	assert(file != null, "Could not open filepath for dialogue!")
	var data := file.get_as_text()
	var nodes := lex_nodes(data)
	file.close()
	return nodes

static func lex_nodes(data: String) -> Dictionary:
	var nodes := {}
	var node_blocks := data.split("===")
	
	for block: String in node_blocks:
		block = block.strip_edges()
		if block.is_empty():
			continue
		
		var node := lex_node(block)
		if node != null:
			nodes[node.title] = node
	return nodes

static func lex_node(data: String) -> NodeData:
	var title := ""
	
	var spl := data.split("---")
	assert(spl.size() == 2, "Dialogue metadata issue probably. Too much or too little.")
	var meta := spl[0]
	var content := spl[1]
	
	var tokens: Array[Token] = []
	
	for line: String in meta.split("\n"):
		line = line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("title:"):
			assert(title == "", "Dialogue already has a title!")
			title = line.replace("title:", "").strip_edges()
	
	for line: String in content.split("\n"):
		var indent := count_indentation(line)
		line = line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("->"):
			tokens.append(Token.new(indent, Token.OPTION, line))
		elif line.begins_with("<<"):
			tokens.append(Token.new(indent, Token.INSTRUCTION, line))
		elif line.begins_with("$"):
			tokens.append(Token.new(indent, Token.CODE, line))
		elif line[0].is_valid_identifier():
			var spl_idx := line.find(":")
			assert(spl_idx != -1, "Could not find speaker while parsing dialogue line.")
			tokens.append(Token.new(indent, Token.LINE, line))
		else:
			assert(false, "Found unknown line beggining lol!")
			
	return NodeData.new(title, tokens)

static func count_indentation(line: String) -> int:
	var count = 0
	for i in range(line.length()):
		if line[i] == '\t':
			count += 1
		else:
			break
	return count
