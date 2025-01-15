extends Node2D

var _rd: RenderingDevice
var _sorter: ComputeShader

var _numbers = [1, 4, 2, 7, 3, 5, 6, 8, 9]
var _buffer_rid := RID()

func _ready() -> void:
	_rd = RenderingServer.create_local_rendering_device()

	_numbers.resize(randi_range(50, 100))
	for i in _numbers.size():
		_numbers[i] = randi()

	var bytes := PackedInt32Array(_numbers).to_byte_array()
	_buffer_rid = _rd.storage_buffer_create(bytes.size(), bytes)

	_sorter = ComputeShader.new(
		_rd, "res://scenes/_debug/fluid_simulation/shaders/bitonic_sort.glsl",
		_get_sort_push_constant_data # will be replaced manually later
	)

	_sorter.add_uniform(0, _make_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0, [_buffer_rid]))
	_sorter.build_uniform_sets()

	_numbers.shuffle()

func _make_uniform(type: RenderingDevice.UniformType, binding: int, ids: Array[RID]) -> RDUniform:
	var uni := RDUniform.new()
	uni.uniform_type = type
	uni.binding = binding
	for id in ids:
		uni.add_id(id)
	return uni

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_sort(_numbers)
		_rd.submit()
		_rd.sync()

		print("INITIAL ARRAY: ", PackedInt32Array(_numbers))
		var buffer_data := _rd.buffer_get_data(_buffer_rid, 0, _numbers.size() * 4)
		print("AFTER SORT: ", buffer_data.to_int32_array())

func _exit_tree() -> void:
	_sorter.free_shader()
	_rd.free_rid(_buffer_rid)

func _get_next_power_of_two(n: int) -> int:
	if n <= 0:
		return 1
	n -= 1
	n |= n >> 1
	n |= n >> 2
	n |= n >> 4
	n |= n >> 8
	n |= n >> 16
	return n + 1

func _get_sort_push_constant_data(num_entries: int, group_width: int, group_height: int, step_index: int) -> PackedByteArray:
	return PackedInt32Array([num_entries, group_width, group_height, step_index]).to_byte_array()

func _sort(values: Array) -> void:
	@warning_ignore("integer_division")
	var num_pairs := _get_next_power_of_two(values.size()) / 2
	var num_stages := floori(log(num_pairs * 2) / log(2))
	for stage in num_stages:
		for step in stage + 1:
			var group_width := 1 << (stage - step)
			var group_height := 2 * group_width - 1
			_sorter.get_push_constant_data = _get_sort_push_constant_data.bind(values.size(), group_width, group_height, step)
			_sorter.update_shader(num_pairs, 1, 1)
