extends Node2D

@export var use_render_thread := false
@export var tex_size := Vector2i(320, 240)
@export var _output_sprite: Sprite2D

@export var camera: Camera3D

#region Node Lifecycle
func _ready() -> void:
	var img := Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBAF)
	img.fill(Color.BLACK)
	_output_sprite.texture = ImageTexture.create_from_image(img)
	
	_thread_invoke(_init_compute)

func _process(_delta: float) -> void:
	# if Input.is_action_just_pressed("jump"):
	_do_render()

func _exit_tree() -> void:
	_thread_invoke(_free_compute)

func _do_render() -> void:
	if _thread_invoke(_render_compute):
		_rd.submit()
		_rd.sync()
		var data := _rd.texture_get_data(_tex_rid, 0)
		var img := Image.create_from_data(tex_size.x, tex_size.y, false, Image.FORMAT_RGBAF, data)
		(_output_sprite.texture as ImageTexture).update(img)

#endregion

#region Compute Lifecycle
var _rd: RenderingDevice
var _shader_rid := RID()
var _pipeline_rid := RID()
var _tex_rid := RID()
var _tex_uniform_set_rid := RID()

func _init_compute() -> void:
	if use_render_thread:
		_rd = RenderingServer.get_rendering_device()
	else:
		_rd = RenderingServer.create_local_rendering_device()
	
	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle.glsl")
	var shader_spirv := shader_source.get_spirv()
	_shader_rid = _rd.shader_create_from_spirv(shader_spirv)

	var tf := RDTextureFormat.new()
	tf.width = tex_size.x
	tf.height = tex_size.y
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	# var data := (_output_sprite.texture as ImageTexture).get_image().get_data()
	# assert(not data.is_empty(), "ERROR: Data is somehow empty?")
	_tex_rid = _rd.texture_create(tf, RDTextureView.new(), [])
	_rd.texture_clear(_tex_rid, Color.BLACK, 0, 1, 0, 1)

	# texture uniform
	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 0
	tex_uniform.add_id(_tex_rid)

	# uniform set
	_tex_uniform_set_rid = _rd.uniform_set_create([tex_uniform], _shader_rid, 0)

	_pipeline_rid = _rd.compute_pipeline_create(_shader_rid)

func matrix_to_bytes(t: Transform3D) -> PackedFloat32Array:
	var basis := t.basis
	var origin := t.origin
	return PackedFloat32Array([
		basis.x.x, basis.x.y, basis.x.z, 1.0,
		basis.y.x, basis.y.y, basis.y.z, 1.0,
		basis.z.x, basis.z.y, basis.z.z, 1.0,
		origin.x, origin.y, origin.z, 1.0
	])

func _render_compute() -> void:
	@warning_ignore("INTEGER_DIVISION")
	var x_groups := (tex_size.x - 1) / 8 + 1
	@warning_ignore("INTEGER_DIVISION")
	var y_groups := (tex_size.y - 1) / 8 + 1

	# push constant data
	var pc := PackedFloat32Array()
	pc.append_array(matrix_to_bytes(camera.global_transform))
	var proj := camera.get_camera_projection()
	for i in 4:
		for j in 4:
			pc.append(proj[i][j])

	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl_rid, _tex_uniform_set_rid, 0)
	_rd.compute_list_set_push_constant(cl_rid, pc.to_byte_array(), pc.size() * 4)
	_rd.compute_list_dispatch(cl_rid, x_groups, y_groups, 1)
	_rd.compute_list_end()

func _free_compute() -> void:
	_free_rid(_tex_rid)
	_free_rid(_shader_rid)
	_free_rid(_pipeline_rid)
#endregion

#region Helpers
## returns whether rid was valid and could be freed
func _free_rid(rid: RID) -> bool:
	if rid:
		_rd.free_rid(rid)
		return true
	return false

## return whether function was called instantly
func _thread_invoke(callable: Callable) -> bool:
	if use_render_thread:
		RenderingServer.call_on_render_thread(callable)
		return false
	else:
		callable.call()
		return true
#endregion