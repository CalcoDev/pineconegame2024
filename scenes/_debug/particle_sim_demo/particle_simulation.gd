extends Node2D

enum SpawnType {
	POSITION,
	BOX_RANDOM,
}

@export var camera: KongleCamera
@export var output_sprite: Sprite2D

@export_flags_2d_physics var sim_physics_layers := 0

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
			_init_textures()
			_init_particle_buffer()
			_init_table_buffer()
			_init_sim_shader()
			_init_display_shader()
			set_process(true)
		NOTIFICATION_PROCESS:
			_rd.texture_clear(_kernel_tex_rid, Color.BLACK, 0, 1, 0, 1)
			_rd.texture_clear(_output_tex_rid, Color.BLACK, 0, 1, 0, 1)
			_update_sim_shader()
			_update_disp_shader()
			_rd.submit()
			_rd. sync ()

			var data := _rd.texture_get_data(_output_tex_rid, 0)
			var img := Image.create_from_data(DISP_TEX_SIZE.x, DISP_TEX_SIZE.y, false, Image.FORMAT_RGBAF, data)
			(output_sprite.texture as ImageTexture).update(img)
		NOTIFICATION_PREDELETE:
			_free_textures()
			_free_particle_buffer()
			_free_table_buffer();
			_free_sim_shader()
			_free_disp_shader()
#endregion

var _rd: RenderingDevice

#region Output Texture

var _kernel_tex_rid := RID()
var _output_tex_rid := RID()

func _init_textures() -> void:
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

	_kernel_tex_rid = _rd.texture_create(tf, RDTextureView.new(), [])
	_output_tex_rid = _rd.texture_create(tf, RDTextureView.new(), [])

func _free_textures() -> void:
	_free_rid(_kernel_tex_rid)
	_free_rid(_output_tex_rid)

#endreigon

#region Particle Buffer
var _particle_buffer_rid := RID()

func _init_particle_buffer() -> void:
	var particle_spawn_data := _get_spawn_particle_data()
	var particle_buffer_data := PackedByteArray()
	for p in particle_spawn_data:
		var f := PackedFloat32Array()
		for i in 2: f.append(p["pos"][i])
		for i in 2: f.append(p["vel"][i])
		for i in 4: f.append(particle_color[i])
		particle_buffer_data.append_array(f.to_byte_array())
	_particle_buffer_rid = _rd.storage_buffer_create(particle_buffer_data.size(), particle_buffer_data)

func _free_particle_buffer() -> void:
	_free_rid(_particle_buffer_rid)
#endregion

#region Table Buffer
var _table_buf_rid := RID()
var _table_indices_buf_rid := RID()
var _table_counters_buf_rid := RID()

func _init_table_buffer() -> void:
	var data := PackedInt32Array()
	data.resize(50051 * 2)
	data.fill(-1)
	_table_buf_rid = _rd.storage_buffer_create(data.size() * 4, data.to_byte_array())
	data.resize(50051)
	_table_indices_buf_rid = _rd.storage_buffer_create(data.size() * 4, data.to_byte_array())
	data.resize(1)
	data.fill(0)
	_table_counters_buf_rid = _rd.storage_buffer_create(data.size() * 4, data.to_byte_array())

func _free_table_buffer() -> void:
	_free_rid(_table_buf_rid)
	_free_rid(_table_indices_buf_rid)
	_free_rid(_table_counters_buf_rid)
#endregion

#region Simulation Shader
var _sim_rid := RID()
var _sim_pipeline_rid := RID()
var _sim_uniset_rid := RID()

var _sim_table_uniset_rid := RID()

var _circle_collider_positions_buf_rid := RID()
var _circle_collider_radius_buf_rid := RID()

var _obb_coll_data_buf_rid := RID()
var _obb_coll_rot_buf_rid := RID()

func _init_sim_shader() -> void:
	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle_simulate.glsl")
	var shader_spirv := shader_source.get_spirv()
	_sim_rid = _rd.shader_create_from_spirv(shader_spirv)

	var particle_buf_uni := RDUniform.new()
	particle_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	particle_buf_uni.binding = 0
	particle_buf_uni.add_id(_particle_buffer_rid)

	var circle_colliders: Array[CollisionShape2D] = []
	var obb_colliders: Array[CollisionShape2D] = []
	var coll := camera.get_parent().find_children("*", "CollisionShape2D")
	for c: CollisionShape2D in coll:
		if c.get_parent() is not PhysicsBody2D:
			continue
		var p: PhysicsBody2D = c.get_parent()
		if sim_physics_layers & p.collision_layer == 0:
			continue
		if c.shape is CircleShape2D:
			circle_colliders.append(c)
		elif c.shape is RectangleShape2D:
			obb_colliders.append(c)
	
	var circle_collider_positions_data := PackedFloat32Array()
	for c in circle_colliders:
		for i in 2: circle_collider_positions_data.append(c.global_position[i])
	_circle_collider_positions_buf_rid = _rd.storage_buffer_create(
		circle_collider_positions_data.size() * 4,
		circle_collider_positions_data.to_byte_array()
	)
	var circ_coll_pos_buf_uni := RDUniform.new()
	circ_coll_pos_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	circ_coll_pos_buf_uni.binding = 1
	circ_coll_pos_buf_uni.add_id(_circle_collider_positions_buf_rid)
	
	var circle_collider_radius_data := PackedFloat32Array()
	for c in circle_colliders:
		circle_collider_radius_data.append(c.shape.radius)
	_circle_collider_radius_buf_rid = _rd.storage_buffer_create(
		circle_collider_radius_data.size() * 4,
		circle_collider_radius_data.to_byte_array()
	)
	var circ_coll_rad_buf_uni := RDUniform.new()
	circ_coll_rad_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	circ_coll_rad_buf_uni.binding = 2
	circ_coll_rad_buf_uni.add_id(_circle_collider_radius_buf_rid)

	var obb_coll_data_data := PackedFloat32Array()
	for c in obb_colliders:
		for i in 2: obb_coll_data_data.append(c.global_position[i])
		for i in 2: obb_coll_data_data.append(c.shape.size[i] / 2.0)
	_obb_coll_data_buf_rid = _rd.storage_buffer_create(
		obb_coll_data_data.size() * 4,
		obb_coll_data_data.to_byte_array()
	)
	var obb_coll_data_buf_uni := RDUniform.new()
	obb_coll_data_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	obb_coll_data_buf_uni.binding = 3
	obb_coll_data_buf_uni.add_id(_obb_coll_data_buf_rid)
	
	var obb_coll_rot_data := PackedFloat32Array()
	for c in obb_colliders:
		obb_coll_rot_data.append(c.global_rotation)
	_obb_coll_rot_buf_rid = _rd.storage_buffer_create(
		obb_coll_rot_data.size() * 4,
		obb_coll_rot_data.to_byte_array()
	)
	var obb_coll_rot_buf_uni := RDUniform.new()
	obb_coll_rot_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	obb_coll_rot_buf_uni.binding = 4
	obb_coll_rot_buf_uni.add_id(_obb_coll_rot_buf_rid)

	_sim_uniset_rid = _rd.uniform_set_create([
		particle_buf_uni,
		circ_coll_pos_buf_uni, circ_coll_rad_buf_uni,
		obb_coll_data_buf_uni, obb_coll_rot_buf_uni
	], _sim_rid, 0)
	
	# var table_buf_uni := RDUniform.new()
	# table_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	# table_buf_uni.binding = 0
	# table_buf_uni.add_id(_table_buf_rid)
	
	# var table_indices_buf_uni := RDUniform.new()
	# table_indices_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	# table_indices_buf_uni.binding = 1
	# table_indices_buf_uni.add_id(_table_indices_buf_rid)
	
	# var table_counters_buf_uni := RDUniform.new()
	# table_counters_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	# table_counters_buf_uni.binding = 2
	# table_counters_buf_uni.add_id(_table_counters_buf_rid)

	var output_tex_uni := RDUniform.new()
	output_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_tex_uni.binding = 0
	output_tex_uni.add_id(_kernel_tex_rid)

	_sim_table_uniset_rid = _rd.uniform_set_create([
		# table_buf_uni, table_indices_buf_uni, table_counters_buf_uni
		output_tex_uni
	], _sim_rid, 1)

	_sim_pipeline_rid = _rd.compute_pipeline_create(_sim_rid)

func _get_sim_push_constant(circ_coll_cnt: int, obb_coll_cnt: int) -> PackedByteArray:
	var a := PackedByteArray()
	var f := PackedFloat32Array()
	var i := PackedInt32Array()

	f.clear()
	f.append(get_process_delta_time())
	f.append(gravity)
	f.append(particle_radius)
	a.append_array(f.to_byte_array())
	
	i.clear()
	i.append(circ_coll_cnt)
	i.append(obb_coll_cnt)
	i.append(particle_count)

	i.append_array([0, 0]) # padding
	
	a.append_array(i.to_byte_array())

	return a

func _update_sim_shader() -> void:
	@warning_ignore("INTEGER_DIVISION")
	var x_groups := (particle_count - 1) / 8 + 1
	var push_constant_data := _get_sim_push_constant(5, 2)

	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _sim_pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl_rid, _sim_uniset_rid, 0)
	_rd.compute_list_bind_uniform_set(cl_rid, _sim_table_uniset_rid, 1)
	_rd.compute_list_set_push_constant(cl_rid, push_constant_data, push_constant_data.size())
	_rd.compute_list_dispatch(cl_rid, x_groups, 1, 1)
	_rd.compute_list_end()

func _free_sim_shader() -> void:
	_free_rid(_sim_rid)
	_free_rid(_sim_uniset_rid)
	_free_rid(_sim_pipeline_rid)

	_free_rid(_circle_collider_positions_buf_rid)
	_free_rid(_circle_collider_radius_buf_rid)
	
	_free_rid(_obb_coll_data_buf_rid)
	_free_rid(_obb_coll_rot_buf_rid)
#endregion

#region Display Shader
var _disp_rid := RID()
var _disp_pipeline_rid := RID()
var _disp_uniset_rid := RID()

var _disp_table_uniset_rid := RID()


const DISP_TEX_SIZE := Vector2i(320, 240)
func _init_display_shader() -> void:
	var img := Image.create(DISP_TEX_SIZE.x, DISP_TEX_SIZE.y, false, Image.FORMAT_RGBAF)
	img.fill(Color.BLACK)
	output_sprite.texture = ImageTexture.create_from_image(img)

	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle_display.glsl")
	var shader_spirv := shader_source.get_spirv()
	_disp_rid = _rd.shader_create_from_spirv(shader_spirv)
 
	var particle_buf_uni := RDUniform.new()
	particle_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	particle_buf_uni.binding = 0
	particle_buf_uni.add_id(_particle_buffer_rid)

	_disp_uniset_rid = _rd.uniform_set_create([
		particle_buf_uni
	], _disp_rid, 0)
	
	var kernel_tex_uni := RDUniform.new()
	kernel_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	kernel_tex_uni.binding = 0
	kernel_tex_uni.add_id(_kernel_tex_rid)

	var output_tex_uni := RDUniform.new()
	output_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_tex_uni.binding = 1
	output_tex_uni.add_id(_output_tex_rid)

	_disp_table_uniset_rid = _rd.uniform_set_create([
		kernel_tex_uni, output_tex_uni
	], _disp_rid, 1)

	_disp_pipeline_rid = _rd.compute_pipeline_create(_disp_rid)

func _get_disp_push_constant() -> PackedByteArray:
	var a := PackedByteArray()
	var i := PackedInt32Array()
	var f := PackedFloat32Array()
	
	var cam_top_left := Vector2i(camera.get_top_left())
	var cam_size := Vector2i(camera._get_scaled_camera_size())
	i.clear()
	i.append_array([cam_top_left.x, cam_top_left.y])
	i.append_array([cam_size.x, cam_size.y])
	a.append_array(i.to_byte_array())
	
	f.clear()
	f.append_array([particle_color.r, particle_color.g, particle_color.b])
	f.append(particle_radius)
	a.append_array(f.to_byte_array())
	
	i.clear()
	i.append(particle_count)
	i.append_array([0, 0, 0]) # padding
	a.append_array(i.to_byte_array())
	
	
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
	_rd.compute_list_bind_uniform_set(cl_rid, _disp_table_uniset_rid, 1)
	_rd.compute_list_set_push_constant(cl_rid, push_constant_data, push_constant_data.size())
	_rd.compute_list_dispatch(cl_rid, x_groups, y_groups, 1)
	_rd.compute_list_end()

func _free_disp_shader() -> void:
	_free_rid(_disp_rid)
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
