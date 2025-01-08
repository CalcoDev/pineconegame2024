extends Node2D

@export var use_render_thread := false
@export var tex_size := Vector2i(320, 240)
@export var _output_sprite: Sprite2D

@export var camera: Camera3D
@export var skybox_texture: Texture2D

@export var rotate_speed := 10.0

#region Node Lifecycle
func _ready() -> void:
	var img := Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBAF)
	img.fill(Color.BLACK)
	_output_sprite.texture = ImageTexture.create_from_image(img)
	
	_thread_invoke(_init_compute)

func _process(delta: float) -> void:
	var x = Input.get_axis("_dbg_left", "_dbg_right");
	var y = Input.get_axis("_dbg_down", "_dbg_up")
	camera.rotation_degrees.y += -x * delta * rotate_speed;
	camera.rotation_degrees.x += y * delta * rotate_speed;

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
var _uniform_set_rid := RID()

var _skybox_tex_rid := RID()
var _skybox_samp_rid := RID()

var _sphere_buffer_rid := RID()

func _init_compute() -> void:
	if use_render_thread:
		_rd = RenderingServer.get_rendering_device()
	else:
		_rd = RenderingServer.create_local_rendering_device()
	
	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle.glsl")
	var shader_spirv := shader_source.get_spirv()
	_shader_rid = _rd.shader_create_from_spirv(shader_spirv)

	# texture creation + uniform
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

	_tex_rid = _rd.texture_create(tf, RDTextureView.new(), [])
	_rd.texture_clear(_tex_rid, Color.BLACK, 0, 1, 0, 1)

	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 0
	tex_uniform.add_id(_tex_rid)

	# loading skybox + uniform
	var skybox_tf = RDTextureFormat.new()
	skybox_tf.width = skybox_texture.get_width()
	skybox_tf.height = skybox_texture.get_height()
	skybox_tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	skybox_tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	skybox_tf.depth = 1
	skybox_tf.array_layers = 1
	skybox_tf.mipmaps = 1
	skybox_tf.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT

	var skybox_data := skybox_texture.get_image()
	skybox_data.convert(Image.FORMAT_RGBAF)
	_skybox_tex_rid = _rd.texture_create(skybox_tf, RDTextureView.new(), [skybox_data.get_data()])

	var skybox_samp_state := RDSamplerState.new()
	skybox_samp_state.unnormalized_uvw = false
	_skybox_samp_rid = _rd.sampler_create(skybox_samp_state)

	var skybox_uniform := RDUniform.new()
	skybox_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	skybox_uniform.binding = 1
	skybox_uniform.add_id(_skybox_samp_rid)
	skybox_uniform.add_id(_skybox_tex_rid)

	# sphere uniforms
	var sphere_data_bytes := _get_sphere_gpu_data()
	_sphere_buffer_rid = _rd.storage_buffer_create(sphere_data_bytes.size(), sphere_data_bytes)

	var sphere_uniform := RDUniform.new()
	sphere_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	sphere_uniform.binding = 2
	sphere_uniform.add_id(_sphere_buffer_rid)

	# uniform set
	var uniforms: Array[RDUniform] = [tex_uniform, skybox_uniform, sphere_uniform]
	_uniform_set_rid = _rd.uniform_set_create(uniforms, _shader_rid, 0)

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
	var plane_width := camera.near * tan(deg_to_rad(camera.fov * 0.5)) * 2.0
	var plane_height := plane_width * 4 / 3;
	var view_params := Vector3(plane_width, plane_height, -camera.near)
	for i in 3:
		pc.append(view_params[i])
	pc.append(0.0)

	var new_sphere_data := _get_sphere_gpu_data()
	_rd.buffer_update(_sphere_buffer_rid, 0, new_sphere_data.size(), new_sphere_data)

	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl_rid, _uniform_set_rid, 0)
	_rd.compute_list_set_push_constant(cl_rid, pc.to_byte_array(), pc.size() * 4)
	_rd.compute_list_dispatch(cl_rid, x_groups, y_groups, 1)
	_rd.compute_list_end()

func _free_compute() -> void:
	_free_rid(_tex_rid)
	_free_rid(_shader_rid)
	_free_rid(_pipeline_rid)
	_free_rid(_skybox_samp_rid)
	_free_rid(_skybox_tex_rid)
#endregion

#region Helpers
func _get_sphere_gpu_data() -> PackedByteArray:
	var spheres := camera.get_parent().find_children("*", "ParticleSimSphere")
	var sphere_data := PackedFloat32Array()
	for sphere: ParticleSimSphere in spheres:
		for i in 3:
			sphere_data.append(sphere.global_position[i])
		sphere_data.append(sphere.radius)
		for i in 4:
			sphere_data.append(sphere.color[i])
	var sphere_data_bytes := PackedByteArray()
	sphere_data_bytes.append_array(PackedInt32Array([spheres.size(), 0, 0, 0]).to_byte_array())
	sphere_data_bytes.append_array(sphere_data.to_byte_array())
	return sphere_data_bytes

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