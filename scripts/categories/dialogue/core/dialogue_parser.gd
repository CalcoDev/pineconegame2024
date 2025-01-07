class_name DialogueParser

class Token:
    enum {LINE, OPTION, INSTRUCTION, CODE}
    var indent: int
    var parent: Token
    var next: Token
    var type: int
    var index: int
    @warning_ignore("shadowed_variable")
    func _init(indent: int, parent: Token, type: int):
        self.indent = indent
        self.parent = parent
        self.type = type

class TokenLine extends Token:
    var dia_line: DialogueLine
    @warning_ignore("shadowed_variable", "SHADOWED_VARIABLE_BASE_CLASS")
    func _init(indent: int, parent: Token, speaker: String, line: String):
        super(indent, parent, LINE)
        self.dia_line = DialogueLine.new(speaker, line)

class TokenOptionToken:
    var dia_option: DialogueOption
    var next: Token
    var parent: TokenOption
    @warning_ignore("shadowed_variable")
    func _init(next: Token, idx: int, text: String, parent: TokenOption):
        self.dia_option = DialogueOption.new(idx, text)
        self.next = next
        self.parent = parent

class TokenOption extends Token:
    var options: Array[TokenOptionToken]
    @warning_ignore("shadowed_variable", "SHADOWED_VARIABLE_BASE_CLASS")
    func _init(indent: int, parent: Token):
        super(indent, parent, OPTION)
    func add_option(token: TokenOptionToken) -> void:
        options.append(token)
    func generate_dialogue_options() -> Array[DialogueOption]:
        var a: Array[DialogueOption] = []
        for opt in options:
            a.append(opt.dia_option)
        return a

# basic because ... honestly this should be sth else probably
class TokenInstruction extends Token:
    var dia_command: DialogueCommand
    @warning_ignore("shadowed_variable", "SHADOWED_VARIABLE_BASE_CLASS")
    func _init(indent: int, parent: Token, value: String):
        super(indent, parent, INSTRUCTION)
        value = value.strip_edges().substr(2, len(value) - 4).strip_edges()
        var spl := value.split(" ")
        var args: Array[String] = []
        args.assign(Array(spl.slice(1)))
        self.dia_command = DialogueCommand.new(value, spl[0], args)

# really basic as Godot will handle stuff
class TokenCode extends Token:
    var value: String
    @warning_ignore("shadowed_variable", "SHADOWED_VARIABLE_BASE_CLASS")
    func _init(indent: int, parent: Token, value: String):
        super(indent, parent, CODE)
        self.value = value

class NodeData:
    var title: String
    var tokens: Array[Token]
    
    @warning_ignore("shadowed_variable")
    func _init(title, tokens):
        self.title = title
        self.tokens = tokens

static func parse_node(node: DialogueLexer.NodeData) -> Dictionary:
    var d := parse_token_from_token_list(node.tokens)
    return d

static func parse_token_from_token_list(in_tokens: Array[DialogueLexer.Token], parent: Token = null, level: int = -1) -> Dictionary:
    var tokens: Array[Token] = []
    var parent_token: Token = parent
    
    var idx: int = 0
    while idx < in_tokens.size() and (level < 0 or in_tokens[idx].indent > level):
        var tok := in_tokens[idx]
        var ctk: Token
        match tok.type:
            DialogueLexer.Token.LINE:
                var d := parse_line(tok, parent_token, idx)
                ctk = d["token"]
                idx = d["index"]
            DialogueLexer.Token.OPTION:
                var d := parse_option(tok, parent_token, idx, in_tokens)
                ctk = d["token"]
                idx = d["index"]
            DialogueLexer.Token.INSTRUCTION:
                var d := parse_instruction(tok, parent_token, idx)
                ctk = d["token"]
                idx = d["index"]
            DialogueLexer.Token.CODE:
                var d := parse_code(tok, parent_token, idx)
                ctk = d["token"]
                idx = d["index"]
        tokens.append(ctk)
        if parent_token != null:
            parent_token.next = ctk
        parent_token = ctk
    return {"token": tokens[0], "index": idx, "tokens": tokens}

static func parse_line(tok: DialogueLexer.Token, parent: Token, index: int) -> Dictionary:
    var spl := tok.text.find(":")
    var token := TokenLine.new(tok.indent, parent, tok.text.substr(0, spl).strip_edges(), tok.text.substr(spl + 1, -1).strip_edges())
    return {"token": token, "index": index + 1}
    
static func parse_option(tok: DialogueLexer.Token, parent: Token, index: int, tokens: Array[DialogueLexer.Token]) -> Dictionary:
    var tok_opt := TokenOption.new(tok.indent, parent)
    var curr_tok := tokens[index]
    var opt_idx: int = 0
    while curr_tok.type == DialogueLexer.Token.OPTION and curr_tok.indent == tok_opt.indent:
        var tok_opt_tok := TokenOptionToken.new(null, opt_idx, curr_tok.text.replace("->", "").strip_edges(), tok_opt)
        opt_idx += 1
        tok_opt.add_option(tok_opt_tok)
        if tokens.size() <= index + 1:
            index += 1
            break
        
        var next_is_same_opt := tokens[index + 1].type == DialogueLexer.Token.OPTION and tokens[index + 1].indent == curr_tok.indent
        if not next_is_same_opt and tokens[index + 1].indent > curr_tok.indent:
            var next_d := parse_token_from_token_list(tokens.slice(index + 1, tokens.size()), tok_opt, curr_tok.indent)
            index = index + next_d["index"] + 1
            tok_opt_tok.next = next_d["token"]
        else:
            index += 1
        if index < tokens.size():
            curr_tok = tokens[index]
        else:
            break
    
    return {"token": tok_opt, "index": index}

static func parse_instruction(tok: DialogueLexer.Token, parent: Token, index: int) -> Dictionary:
    var token := TokenInstruction.new(tok.indent, parent, tok.text)
    return {"token": token, "index": index + 1}

static func parse_code(tok: DialogueLexer.Token, parent: Token, index: int) -> Dictionary:
    var token := TokenCode.new(tok.indent, parent, tok.text)
    return {"token": token, "index": index + 1}
