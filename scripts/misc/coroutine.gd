class_name Coroutine

static func is_node_valid(node: Node) -> bool:
	return is_instance_valid(node) and is_instance_valid(node.get_tree()) and is_instance_valid(node.owner)

static func is_instance_valid(coro: Coroutine) -> bool:
	return is_instance_valid(coro) and is_instance_valid(coro.context) and not coro.context.cancelled

# const BIND_CTX: int = 542 # wax quail => b64 => hex => +
class Ctx extends RefCounted:
	var coro: Coroutine = null
	var cancelled:
		get():
			return coro.cancelled
	var started:
		get():
			return coro.started
	func _init(coroutine: Coroutine) -> void:
		coro = coroutine
	func is_valid() -> bool:
		return Coroutine.is_instance_valid(coro)

signal on_completed()
signal on_cancelled()

var to_await: Callable
var started: bool = false
var cancelled: bool = false
var context: Ctx = Ctx.new(self)

func bind_ctx(callable: Callable) -> Callable:
	return callable.bind(context)

func run() -> bool: # returns (completed)
	started = true
	cancelled = false

	await _call_to_await()
	if not context.is_valid() or cancelled:
		on_cancelled.emit()
		return false
	else:
		on_completed.emit()
		return true

# CALCO: This actually only has an effect if first param of to_await is of type coroutine
func stop() -> void:
	if started:
		cancelled = true

func _call_to_await():
	await to_await.call()

#region API
static func make_single(bind_context: bool, awaitable: Callable) -> Coroutine:
	var c := Coroutine.new()
	c.to_await = c.bind_ctx(awaitable) if bind_context else awaitable
	return c

func single(awaitable: Callable) -> void:
	to_await = awaitable
	await run()

func first_of(awaitables: Array[Callable], stop_on_finish: bool) -> int:
	var coroutines: Array[Coroutine] = []
	
	var finished: Array[bool] = []
	finished.resize(awaitables.size())
	var index: Array[int] = [-1]
	var mark_as_finished = func(idx: int):
		if self == null:
			return
		finished[idx] = true
		index[0] = idx
		on_completed.emit()

	for idx in awaitables.size():
		var c = Coroutine.new()
		c.to_await = awaitables[idx]

		var mark_current = func():
			mark_as_finished.call(idx)
		
		c.on_completed.connect(mark_current)
		coroutines.append(c)
	
	for c in coroutines:
		c.run()
	
	await on_completed

	if stop_on_finish:
		for i in coroutines.size():
			if i == index[0]:
				continue
			coroutines[i].stop()

	return index[0]
#endregion