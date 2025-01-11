class_name ComputeShader

var _path := ""

var _rd: RenderingDevice

var _shader_rid := RID()
var _pipeline_rid := RID()

var _dispatch_size := Vector3i(8, 8, 1)

var get_push_constant_data: Callable

@warning_ignore("shadowed_variable")
func _init(rd: RenderingDevice, path: String, dispatch_size: Vector3i, get_push_constant_data: Callable = _DEFAULT_PUSH_DATA, no_init: bool = false) -> void:
	self._rd = rd
	self._path = path
	self._dispatch_size = dispatch_size
	self.get_push_constant_data = get_push_constant_data

	if not no_init:
		init_shader()

var _uniform_set_rids: Dictionary[int, RID] = {}
var _uniform_data: Dictionary

## doesn;t actually add, just prepares
func add_uniform(set_index: int, uniform: RDUniform) -> void:
	_uniform_data.get_or_add(set_index, []).append(uniform)

## actually creates all uniforms accorindgly
func build_uniform_sets() -> void:
	for idx: int in _uniform_data:
		var uniforms = _uniform_data[idx]
		_uniform_set_rids[idx] = _rd.uniform_set_create(uniforms, _shader_rid, idx)

func init_shader() -> void:
	var source: RDShaderFile = load(_path)
	var spirv := source.get_spirv()
	_shader_rid = _rd.shader_create_from_spirv(spirv)

	_pipeline_rid = _rd.compute_pipeline_create(_shader_rid, [])

# func get_push_constant_data() -> PackedByteArray:
# 	return PackedByteArray()

func update_shader() -> void:
	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _pipeline_rid)
	for idx in _uniform_set_rids:
		_rd.compute_list_bind_uniform_set(cl_rid, _uniform_set_rids[idx], idx)
	# if get_push_constant_data:
	var push_constant_data: PackedByteArray = get_push_constant_data.call()
	_rd.compute_list_set_push_constant(cl_rid, push_constant_data, push_constant_data.size())
	_rd.compute_list_dispatch(cl_rid, _dispatch_size.x, _dispatch_size.y, _dispatch_size.z)
	_rd.compute_list_end()

func free_shader() -> void:
	_free_rid(_shader_rid)
	_free_rid(_pipeline_rid)

	for idx in _uniform_set_rids:
		_free_rid(_uniform_set_rids[idx])

func get_path() -> String:
	return _path

func get_rid() -> RID:
	return _shader_rid

## returns whether rid was valid and could be freed
func _free_rid(rid: RID) -> bool:
	if rid and rid != RID():
		_rd.free_rid(rid)
		return true
	return false

static func _DEFAULT_PUSH_DATA() -> PackedByteArray:
	return PackedByteArray()