class_name DialogueView
extends Node

# TODO(calco): shouldn't be here but yeah
@warning_ignore("unused_private_class_variable")
var _runner: DialogueRunner

# all are called by dialogue runner
func dialogue_completed():
    pass
func dialogue_started():
    pass

# NOTE(calco): Using signals as they allow for better overriding behaviour.
# aka I can check if it "was" overriden
signal run_line(line: DialogueLine, on_finished: Callable)
signal run_options(options: Array[DialogueOption], on_selected: Callable)

func can_handle_line() -> bool:
    return run_line.get_connections().size() > 0

func can_handle_options() -> bool:
    return run_options.get_connections().size() > 0
