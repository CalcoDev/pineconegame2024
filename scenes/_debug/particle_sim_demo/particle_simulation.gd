extends Node2D

enum SpawnType {
	POSITION,
	BOX_RANDOM,
}

@export var camera: KongleCamera
@export var output_sprite: Sprite2D

@export_group("spawn settings")
@export var particle_count := 500
@export var spawn_type := SpawnType.POSITION
@export var spawn_position := Vector2.ZERO
@export var spawn_bounds := Rect2()
@export var random_velocity := false
@export var directed_velocity := false
@export var velocity_magnitude := 0.0

@export_group("sim settings")
@export var gravity := 9.8

@export var particle_color := Color.CYAN
@export var particle_radius := 2.0

#region Node Lifecycle
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			_rd = RenderingServer.create_local_rendering_device()
			_init_particle_buffer()
			_init_sim_shader()
			_init_display_shader()
			
			set_process(true)
			pass
		NOTIFICATION_PROCESS:
			_update_sim_shader()
			_update_disp_shader()
			_rd.submit()
			_rd.sync()

			var data := _rd.texture_get_data(_disp_output_tex_rid, 0)
			var img := Image.create_from_data(DISP_TEX_SIZE.x, DISP_TEX_SIZE.y, false, Image.FORMAT_RGBAF, data)
			(output_sprite.texture as ImageTexture).update(img)
			pass
		NOTIFICATION_PREDELETE:
			_free_particle_buffer()
			_free_sim_shader()
			_free_disp_shader()
			pass
#endregion

var _rd: RenderingDevice

#region Particle Buffer
var _particle_buffer_rid := RID()

func _init_particle_buffer() -> void:
	var particle_spawn_data := _get_spawn_particle_data()
	var particle_buffer_data := PackedByteArray()
	particle_buffer_data.append_array(PackedInt32Array([particle_spawn_data.size(), 0]).to_byte_array())
	for p in particle_spawn_data:
		var f := PackedFloat32Array()
		for i in 2: f.append(p["pos"][i])
		for i in 2: f.append(p["vel"][i])
		particle_buffer_data.append_array(f.to_byte_array())
	_particle_buffer_rid = _rd.storage_buffer_create(particle_buffer_data.size(), particle_buffer_data)

func _free_particle_buffer() -> void:
	_free_rid(_particle_buffer_rid)
#endregion

#region Simulation Shader
var _sim_rid := RID()
var _sim_pipeline_rid := RID()
var _sim_uniset_rid := RID()

func _init_sim_shader() -> void:
	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle_simulate.glsl")
	var shader_spirv := shader_source.get_spirv()
	_sim_rid = _rd.shader_create_from_spirv(shader_spirv)

	var particle_buf_uni := RDUniform.new()
	particle_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	particle_buf_uni.binding = 0
	particle_buf_uni.add_id(_particle_buffer_rid)

	var uniforms: Array[RDUniform] = [particle_buf_uni]
	_sim_uniset_rid = _rd.uniform_set_create(uniforms, _sim_rid, 0)
	_sim_pipeline_rid = _rd.compute_pipeline_create(_sim_rid)

func _get_sim_push_constant() -> PackedByteArray:
	var a := PackedByteArray()
	var f := PackedFloat32Array()
	f.append(get_process_delta_time())
	f.append(gravity)
	f.append_array([0, 0]) # padding
	a.append_array(f.to_byte_array())
	return a

func _update_sim_shader() -> void:
	@warning_ignore("INTEGER_DIVISION")
	var x_groups := (particle_count - 1) / 8 + 1
	var push_constant_data := _get_sim_push_constant()

	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _sim_pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl_rid, _sim_uniset_rid, 0)
	_rd.compute_list_set_push_constant(cl_rid, push_constant_data, push_constant_data.size())
	_rd.compute_list_dispatch(cl_rid, x_groups, 1, 1)
	_rd.compute_list_end()

func _free_sim_shader() -> void:
	_free_rid(_sim_rid)
	_free_rid(_sim_uniset_rid)
	_free_rid(_sim_pipeline_rid)
#endregion

#region Display Shader
var _disp_rid := RID()
var _disp_pipeline_rid := RID()
var _disp_uniset_rid := RID()

var _disp_output_tex_rid := RID()

const DISP_TEX_SIZE := Vector2i(320, 240)
func _init_display_shader() -> void:
	var img := Image.create(DISP_TEX_SIZE.x, DISP_TEX_SIZE.y, false, Image.FORMAT_RGBAF)
	img.fill(Color.BLACK)
	output_sprite.texture = ImageTexture.create_from_image(img)

	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle_display.glsl")
	var shader_spirv := shader_source.get_spirv()
	_disp_rid = _rd.shader_create_from_spirv(shader_spirv)

	var tf := RDTextureFormat.new()
	tf.width = DISP_TEX_SIZE.x
	tf.height = DISP_TEX_SIZE.y
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

	_disp_output_tex_rid = _rd.texture_create(tf, RDTextureView.new(), [])
	_rd.texture_clear(_disp_output_tex_rid, Color.BLACK, 0, 1, 0, 1)

	var output_tex_uni := RDUniform.new()
	output_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_tex_uni.binding = 0
	output_tex_uni.add_id(_disp_output_tex_rid)
 
	var particle_buf_uni := RDUniform.new()
	particle_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	particle_buf_uni.binding = 1
	particle_buf_uni.add_id(_particle_buffer_rid)

	var uniforms: Array[RDUniform] = [output_tex_uni, particle_buf_uni]
	_disp_uniset_rid = _rd.uniform_set_create(uniforms, _disp_rid, 0)
	_disp_pipeline_rid = _rd.compute_pipeline_create(_disp_rid)

func _get_disp_push_constant() -> PackedByteArray:
	var a := PackedByteArray()
	var i := PackedInt32Array()
	var cam_top_left := Vector2i(camera.get_top_left())
	var cam_size := Vector2i(camera._get_scaled_camera_size())
	i.append_array([cam_top_left.x, cam_top_left.y])
	i.append_array([cam_size.x, cam_size.y])
	a.append_array(i.to_byte_array())
	var f := PackedFloat32Array()
	f.append_array([particle_color.r, particle_color.g, particle_color.b])
	f.append(particle_radius)
	a.append_array(f.to_byte_array())
	return a

func _update_disp_shader() -> void:
	@warning_ignore("INTEGER_DIVISION")
	var x_groups := (DISP_TEX_SIZE.x - 1) / 8 + 1
	@warning_ignore("INTEGER_DIVISION")
	var y_groups := (DISP_TEX_SIZE.y - 1) / 8 + 1
	var push_constant_data := _get_disp_push_constant()

	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _disp_pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl_rid, _disp_uniset_rid, 0)
	_rd.compute_list_set_push_constant(cl_rid, push_constant_data, push_constant_data.size())
	_rd.compute_list_dispatch(cl_rid, x_groups, y_groups, 1)
	_rd.compute_list_end()

func _free_disp_shader() -> void:
	_free_rid(_disp_rid)
	_free_rid(_disp_output_tex_rid)
	_free_rid(_disp_uniset_rid)
	_free_rid(_disp_pipeline_rid)
#endregion

#region Compute Helpers
## returns whether rid was valid and could be freed
func _free_rid(rid: RID) -> bool:
	if rid:
		_rd.free_rid(rid)
		return true
	return false
#endregion

#region Particle Helpers
func random_point_on_unit_circle() -> Vector2:
	var angle = randf() * PI * 2.0
	return Vector2(cos(angle), sin(angle))

func _get_spawn_particle_data() -> Array:
	var dict := []
	match spawn_type:
		SpawnType.POSITION:
			for p in particle_count:
				var pos := spawn_position
				var vel := Vector2.ZERO
				if random_velocity:
					vel = random_point_on_unit_circle() * velocity_magnitude
				if directed_velocity:
					vel = Vector2.UP * velocity_magnitude
				dict.append({"pos": pos, "vel": vel})
		SpawnType.BOX_RANDOM:
			for p in particle_count:
				var off := Vector2(
					randf_range(0.0, spawn_bounds.size.x),
					randf_range(0.0, spawn_bounds.size.y)
				)
				var pos := spawn_bounds.position + off
				var vel := Vector2.ZERO
				if random_velocity:
					vel = random_point_on_unit_circle() * velocity_magnitude
				if directed_velocity:
					vel = (pos - spawn_bounds.get_center()).normalized()
				dict.append({"pos": pos, "vel": vel})
	return dict
#endregion
