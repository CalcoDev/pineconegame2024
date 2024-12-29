class_name Coroutine

static func is_node_valid(node: Node) -> bool:
	return is_instance_valid(node) and is_instance_valid(node.get_tree()) and is_instance_valid(node.owner)

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

signal on_completed()
signal on_cancelled()

var to_await: Callable
var started: bool = false
var cancelled: bool = false

var context: Ctx = Ctx.new(self)

func bind_ctx(callable: Callable) -> Callable:
	return callable.bind(context)

var _raw: bool = true
func run() -> bool: # returns (completed)
	started = true
	cancelled = false

	if _raw:
		await call_to_await()
		on_completed.emit()
		return true
	else:
		var await_finish = func():
			await call_to_await()
			if not cancelled:
				on_completed.emit()
		var await_cancelled = func():
			await on_cancelled
		var c = Coroutine.new()
		c._raw = false
		c.first_of([await_finish, await_cancelled], false)
		var was_cancelled = await c.run()
		return not was_cancelled

# CALCO: This actually only has an effect if first param of to_await is of type coroutine
func stop() -> void:
	if started:
		cancelled = true

func call_to_await():
	if to_await.get_argument_count() == 1:
		await to_await.call(context)
	else:
		await to_await.call()

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