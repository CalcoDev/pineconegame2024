extends Node2D

enum SpawnType {
	POSITION_OBJECT,
	POSITION_OBJECT_GRID,
	BOX_RANDOM,
}

@export var camera: KongleCamera

@export var enable_sim := true
@export var enable_bapple := true:
	set(value):
		if value == enable_bapple:
			return
		enable_bapple = value
		if enable_bapple:
			_bapple_first_frame = true
			await get_tree().create_timer(0.2).timeout
			_bapple_first_frame = false

@export_group("Bad Apple")
@export var bapple_display: Node2D
@export var bapple_video: VideoStreamPlayer
@export var bapple_audio: AudioStreamPlayer
@export var bapple_polygon_update_speed := 1.0

var _bapple_polygon_update_timer := 0.0
var _bapple_prev_poly_update_frame := 0
var _bapple_first_frame := true

@export_group("Sim Spawn Settings")
@export var particle_count := 500
@export var spawn_type := SpawnType.POSITION_OBJECT

@export_subgroup("Position Object")
@export_node_path("Node2D") var spawn_node_path := NodePath("")

@export_subgroup("Position Object Grid")
@export var particle_grid_spacing := 10.0

@export_subgroup("Bounds")
@export var spawn_bounds := Rect2()

@export_subgroup("Velocity")
@export var random_velocity := false
@export var directed_velocity := false
@export var velocity_magnitude := 0.0

@export_group("Sim Settings")
@export var sim_is_fluid_sim := true
@export var particle_sim_display: Node2D

@export_flags_2d_physics var sim_physics_layers := 0

@export var gravity := 9.8
@export var particle_color := Color.CYAN
@export var particle_radius := 2.0

const DISP_TEX_SIZE := Vector2i(320, 240) * 4

# region Node Lifecycle
func _ready() -> void:
	if enable_bapple:
		enable_bapple = false
		enable_bapple = true

func _process(_delta: float) -> void:
	if not enable_bapple or _bapple_first_frame:
		return
	
	_bapple_polygon_update_timer += _delta
	if _bapple_polygon_update_timer > bapple_polygon_update_speed:
		_bapple_polygon_update_timer = 0.0
		for child in camera.get_parent().get_children():
			if child is StaticBody2D:
				camera.get_parent().remove_child(child)

		_rd.texture_get_data_async(
			_colorkey_tex_rid, 0,
			func(bytes: PackedByteArray):
				var curr_frame := Engine.get_process_frames()
				if curr_frame < _bapple_prev_poly_update_frame:
					return
				_bapple_prev_poly_update_frame = curr_frame
				var map := BitMap.new()
				var img := Image.create_from_data(368, 272, false, Image.FORMAT_RGBAF, bytes)
				map.create_from_image_alpha(img)
				var polygons := map.opaque_to_polygons(Rect2(0, 0, 368, 272), 3)
				for p in polygons:
					var body = StaticBody2D.new()
					var coll_poly = CollisionPolygon2D.new()
					body.scale = Vector2(4, 4)
					camera.get_parent().add_child(body)
					body.add_child(coll_poly)
					coll_poly.polygon = p
		)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			set_process(true)
			_rd = RenderingServer.get_rendering_device()
			_init_textures()
			_init_particle_buffer()
			_init_table_buffer()
			_init_sim_shader()
			_init_display_shader()

			_init_colorkey_shader()

			await get_tree().create_timer(0.1).timeout
			var tex_rd := RenderingServer.texture_rd_create(_output_tex_rid)
			RenderingServer.canvas_item_add_texture_rect(particle_sim_display.get_canvas_item(), Rect2(Vector2.ZERO, DISP_TEX_SIZE), tex_rd)

			# var n_tex_rd := RenderingServer.texture_rd_create(_colorkey_tex_rid)
			# RenderingServer.canvas_item_add_texture_rect(bapple_display.get_canvas_item(), Rect2(Vector2.ZERO, DISP_TEX_SIZE), n_tex_rd)
		NOTIFICATION_PROCESS:
			if enable_sim:
				_rd.texture_clear(_kernel_tex_rid, Color.BLACK, 0, 1, 0, 1)
				_rd.texture_clear(_output_tex_rid, Color.BLACK, 0, 1, 0, 1)
				_update_sim_shader()
				_update_disp_shader()
			
			if enable_bapple:
				_update_colorkey_shader()
		NOTIFICATION_PREDELETE:
			_free_textures()
			_free_particle_buffer()
			_free_table_buffer();
			_free_sim_shader()
			_free_disp_shader()

			_free_colorkey_shader()
#endregion

var _rd: RenderingDevice

#region Colorkey Shader

var _colorkey_rid := RID()
var _colorkey_pipeline_rid := RID()
var _colorkey_uniset_rid := RID()

var _colorkey_tex_rid := RID()

var _colrokey_input_samp_rid := RID()

func _init_colorkey_shader() -> void:
	var tf := RDTextureFormat.new()
	tf.width = 368
	tf.height = 272
	tf.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_colorkey_tex_rid = _rd.texture_create(tf, RDTextureView.new(), [])

	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/colorkey.glsl")
	var shader_spirv := shader_source.get_spirv()
	_colorkey_rid = _rd.shader_create_from_spirv(shader_spirv)

	var input_tex_rid := RenderingServer.texture_get_rd_texture(bapple_video.get_video_texture().get_rid())

	var samp_state := RDSamplerState.new()
	_colrokey_input_samp_rid = _rd.sampler_create(samp_state)

	var input_tex_uni := RDUniform.new()
	input_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	input_tex_uni.binding = 0
	input_tex_uni.add_id(_colrokey_input_samp_rid)
	input_tex_uni.add_id(input_tex_rid)

	var colorkey_tex_uni := RDUniform.new()
	colorkey_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	colorkey_tex_uni.binding = 1
	colorkey_tex_uni.add_id(_colorkey_tex_rid)

	_colorkey_uniset_rid = _rd.uniform_set_create([
		input_tex_uni, colorkey_tex_uni
	], _colorkey_rid, 0)

	_colorkey_pipeline_rid = _rd.compute_pipeline_create(_colorkey_rid)

var _flip := true
func _update_colorkey_shader() -> void:
	@warning_ignore("INTEGER_DIVISION")
	var x_groups := (DISP_TEX_SIZE.x - 1) / 8 + 1
	@warning_ignore("INTEGER_DIVISION")
	var y_groups := (DISP_TEX_SIZE.y - 1) / 8 + 1

	if Input.is_action_just_pressed("jump"):
		_flip = !_flip
	var push_constant_data := PackedInt32Array([int(_flip), 0, 0, 0]).to_byte_array()

	var cl_rid := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl_rid, _colorkey_pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl_rid, _colorkey_uniset_rid, 0)
	_rd.compute_list_set_push_constant(cl_rid, push_constant_data, push_constant_data.size())
	_rd.compute_list_dispatch(cl_rid, x_groups, y_groups, 1)
	_rd.compute_list_end()

func _free_colorkey_shader() -> void:
	_free_rid(_colorkey_tex_rid)
	_free_rid(_colorkey_rid)
	_free_rid(_colorkey_uniset_rid)
	_free_rid(_colorkey_pipeline_rid)

	_free_rid(_colrokey_input_samp_rid)

#endregion

#region Output Texture

var _kernel_tex_rid := RID()
var _kernel_tex_samp_rid := RID()

var _output_tex_rid := RID()

func _init_textures() -> void:
	var kernel_tex_samp_state := RDSamplerState.new()
	_kernel_tex_samp_rid = _rd.sampler_create(kernel_tex_samp_state)

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
	_free_rid(_kernel_tex_samp_rid)
	
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

func _init_sim_shader() -> void:
	var source = "res://scenes/_debug/particle_sim_demo/particle_simulate.glsl"
	if sim_is_fluid_sim:
		source = "res://scenes/_debug/particle_sim_demo/particle_fluid_sim.glsl"
	var shader_source: RDShaderFile = load(source)
	var shader_spirv := shader_source.get_spirv()
	_sim_rid = _rd.shader_create_from_spirv(shader_spirv)

	var particle_buf_uni := RDUniform.new()
	particle_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	particle_buf_uni.binding = 0
	particle_buf_uni.add_id(_particle_buffer_rid)

	if sim_is_fluid_sim:
		_init_sim_fluid_sim(particle_buf_uni)
	else:
		_init_sim_particle_sim(particle_buf_uni)
	
	var output_tex_uni := RDUniform.new()
	output_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_tex_uni.binding = 0
	output_tex_uni.add_id(_kernel_tex_rid)

	_sim_table_uniset_rid = _rd.uniform_set_create([
		output_tex_uni
	], _sim_rid, 1)

	_sim_pipeline_rid = _rd.compute_pipeline_create(_sim_rid)

func _update_sim_shader() -> void:
	@warning_ignore("INTEGER_DIVISION")
	var x_groups := (particle_count - 1) / 8 + 1

	var push_constant_data: PackedByteArray
	if sim_is_fluid_sim:
		_update_sim_fluid_sim()
		push_constant_data = _get_sim_fluid_push_constant()
	else:
		_update_sim_particle_sim()
		push_constant_data = _get_sim_particle_push_constant()

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

	if sim_is_fluid_sim:
		_free_sim_fluid_sim()
	else:
		_free_sim_particle_sim()

#endregion

#region Fluid Sim
func _init_sim_fluid_sim(particle_buf_uni: RDUniform) -> void:
	_sim_uniset_rid = _rd.uniform_set_create([
		particle_buf_uni,
	], _sim_rid, 0)

func _get_sim_fluid_push_constant() -> PackedByteArray:
	var a := PackedByteArray()
	var f := PackedFloat32Array()
	var i := PackedInt32Array()

	i.clear()
	i.append(particle_count)
	a.append_array(i.to_byte_array())

	f.clear()
	f.append(get_process_delta_time())
	f.append(gravity)
	f.append(particle_radius)
	a.append_array(f.to_byte_array())
	
	return a

func _update_sim_fluid_sim() -> void:
	pass

func _free_sim_fluid_sim() -> void:
	pass

#endregion

#region Particle Sim
var _circle_collider_positions_buf_rid := RID()
var _circle_collider_radius_buf_rid := RID()

var _obb_coll_data_buf_rid := RID()
var _obb_coll_rot_buf_rid := RID()

var _circle_collider_positions_data := PackedFloat32Array()
var _circle_collider_radius_data := PackedFloat32Array()
var _obb_coll_data_data := PackedFloat32Array()
var _obb_coll_rot_data := PackedFloat32Array()

var _circle_collider_cnt := 0
var _obb_collider_cnt := 0
var _poly_collider_cnt := 0

# var _polygon_collider_buf_rid 
var _poly_verts_buf_rid := RID()
var _poly_info_buf_rid := RID()

var _poly_verts_data := PackedVector2Array()
var _poly_info_data := PackedInt32Array()

func _update_sim_collider_info() -> void:
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
	
	_circle_collider_cnt = circle_colliders.size()
	_circle_collider_positions_data = PackedFloat32Array()
	for c in circle_colliders:
		for i in 2: _circle_collider_positions_data.append(c.global_position[i])
	
	_circle_collider_radius_data = PackedFloat32Array()
	for c in circle_colliders:
		_circle_collider_radius_data.append(c.shape.radius)
	
	_obb_collider_cnt = obb_colliders.size()
	_obb_coll_data_data = PackedFloat32Array()
	for c in obb_colliders:
		for i in 2: _obb_coll_data_data.append(c.global_position[i])
		for i in 2: _obb_coll_data_data.append(c.shape.size[i] / 2.0)
	
	_obb_coll_rot_data = PackedFloat32Array()
	for c in obb_colliders:
		_obb_coll_rot_data.append(c.global_rotation)

	var polygon_colliders: Array[CollisionPolygon2D] = []
	# coll = camera.get_parent().find_children("*", "CollisionPolygon2D")
	coll.clear()
	for c in camera.get_parent().get_children():
		if c is StaticBody2D and c.get_child(0) is CollisionPolygon2D:
			coll.append(c.get_child(0))
	for c: CollisionPolygon2D in coll:
		if c.get_parent() is not PhysicsBody2D:
			continue
		var p: PhysicsBody2D = c.get_parent()
		if sim_physics_layers & p.collision_layer == 0:
			continue
		polygon_colliders.append(c)
	
	_poly_collider_cnt = polygon_colliders.size()

	_poly_verts_data = PackedVector2Array()
	_poly_info_data = PackedInt32Array()
	var poly_info_offset := 0
	for poly in polygon_colliders:
		var poly_count := poly.polygon.size()
		for p in poly.polygon:
			_poly_verts_data.append(poly.global_position + p * poly.global_scale)
		_poly_info_data.append(poly_count)
		_poly_info_data.append(poly_info_offset)
		poly_info_offset += poly_count

func _init_sim_particle_sim(particle_buf_uni: RDUniform) -> void:
	_update_sim_collider_info()

	_circle_collider_positions_buf_rid = _rd.storage_buffer_create(
		_circle_collider_positions_data.size() * 4,
		_circle_collider_positions_data.to_byte_array()
	)
	var circ_coll_pos_buf_uni := RDUniform.new()
	circ_coll_pos_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	circ_coll_pos_buf_uni.binding = 1
	circ_coll_pos_buf_uni.add_id(_circle_collider_positions_buf_rid)
	
	_circle_collider_radius_buf_rid = _rd.storage_buffer_create(
		_circle_collider_radius_data.size() * 4,
		_circle_collider_radius_data.to_byte_array()
	)
	var circ_coll_rad_buf_uni := RDUniform.new()
	circ_coll_rad_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	circ_coll_rad_buf_uni.binding = 2
	circ_coll_rad_buf_uni.add_id(_circle_collider_radius_buf_rid)

	_obb_coll_data_buf_rid = _rd.storage_buffer_create(
		_obb_coll_data_data.size() * 4,
		_obb_coll_data_data.to_byte_array()
	)
	var obb_coll_data_buf_uni := RDUniform.new()
	obb_coll_data_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	obb_coll_data_buf_uni.binding = 3
	obb_coll_data_buf_uni.add_id(_obb_coll_data_buf_rid)
	
	_obb_coll_rot_buf_rid = _rd.storage_buffer_create(
		_obb_coll_rot_data.size() * 4,
		_obb_coll_rot_data.to_byte_array()
	)
	var obb_coll_rot_buf_uni := RDUniform.new()
	obb_coll_rot_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	obb_coll_rot_buf_uni.binding = 4
	obb_coll_rot_buf_uni.add_id(_obb_coll_rot_buf_rid)

	# var poly_verts := _poly_verts_data.to_byte_array()
	var poly_verts = PackedFloat32Array()
	poly_verts.resize(100000)
	poly_verts = poly_verts.to_byte_array()
	_poly_verts_buf_rid = _rd.storage_buffer_create(poly_verts.size(), poly_verts)
	var poly_verts_buf_uni := RDUniform.new()
	poly_verts_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	poly_verts_buf_uni.binding = 5
	poly_verts_buf_uni.add_id(_poly_verts_buf_rid)

	var poly_info = PackedFloat32Array()
	poly_info.resize(100000)
	poly_info = poly_info.to_byte_array()
	_poly_info_buf_rid = _rd.storage_buffer_create(poly_info.size(), poly_info)
	var poly_info_buf_uni := RDUniform.new()
	poly_info_buf_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	poly_info_buf_uni.binding = 6
	poly_info_buf_uni.add_id(_poly_info_buf_rid)

	_sim_uniset_rid = _rd.uniform_set_create([
		particle_buf_uni,
		circ_coll_pos_buf_uni, circ_coll_rad_buf_uni,
		obb_coll_data_buf_uni, obb_coll_rot_buf_uni,
		poly_verts_buf_uni, poly_info_buf_uni
	], _sim_rid, 0)

func _get_sim_particle_push_constant() -> PackedByteArray:
	var a := PackedByteArray()
	var f := PackedFloat32Array()
	var i := PackedInt32Array()

	f.clear()
	f.append(get_process_delta_time())
	f.append(gravity)
	f.append(particle_radius)
	a.append_array(f.to_byte_array())
	
	i.clear()
	i.append(_circle_collider_cnt)
	i.append(_obb_collider_cnt)
	i.append(_poly_collider_cnt)
	
	i.append(particle_count)

	i.append_array([0]) # padding
	
	a.append_array(i.to_byte_array())

	return a

func _update_sim_particle_sim() -> void:
	var p_circ := _circle_collider_cnt
	var p_obb := _obb_collider_cnt
	
	_update_sim_collider_info()

	# _poly_verts_buf_rid
	var poly_verts := _poly_verts_data.to_byte_array()
	_rd.buffer_update(_poly_verts_buf_rid, 0, poly_verts.size(), poly_verts)
	var poly_info := _poly_info_data.to_byte_array()
	_rd.buffer_update(_poly_info_buf_rid, 0, poly_info.size(), poly_info)

	if p_circ == _circle_collider_cnt:
		_rd.buffer_update(
			_circle_collider_positions_buf_rid, 0,
			_circle_collider_positions_data.size() * 4,
			_circle_collider_positions_data.to_byte_array()
		)
		_rd.buffer_update(
			_circle_collider_radius_buf_rid, 0,
			_circle_collider_radius_data.size() * 4,
			_circle_collider_radius_data.to_byte_array()
		)
	else:
		# TODOcalco
		pass
	if p_obb == _obb_collider_cnt:
		_rd.buffer_update(
			_obb_coll_data_buf_rid, 0,
			_obb_coll_data_data.size() * 4,
			_obb_coll_data_data.to_byte_array()
		)
		_rd.buffer_update(
			_obb_coll_rot_buf_rid, 0,
			_obb_coll_rot_data.size() * 4,
			_obb_coll_rot_data.to_byte_array()
		)
	else:
		# TODOcalco
		pass

func _free_sim_particle_sim() -> void:
	_free_rid(_circle_collider_positions_buf_rid)
	_free_rid(_circle_collider_radius_buf_rid)
	
	_free_rid(_obb_coll_data_buf_rid)
	_free_rid(_obb_coll_rot_buf_rid)
	
	_free_rid(_poly_verts_buf_rid)
	_free_rid(_poly_info_buf_rid)
#endregion


#region Display Shader
var _disp_rid := RID()
var _disp_pipeline_rid := RID()
var _disp_uniset_rid := RID()

var _disp_table_uniset_rid := RID()

func _init_display_shader() -> void:
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

	# var kernel_tex_uni := RDUniform.new()
	# kernel_tex_uni.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	# kernel_tex_uni.binding = 0
	# kernel_tex_uni.add_id(_kernel_tex_samp_rid)
	# kernel_tex_uni.add_id(_kernel_tex_rid)
	
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
	if rid and rid != RID():
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
		SpawnType.POSITION_OBJECT:
			for p in particle_count:
				var pos := (get_node(spawn_node_path) as Node2D).global_position
				var vel := Vector2.ZERO
				if random_velocity:
					vel = random_point_on_unit_circle() * velocity_magnitude
				if directed_velocity:
					vel = Vector2.UP * velocity_magnitude
				dict.append({"pos": pos, "vel": vel})
		SpawnType.POSITION_OBJECT_GRID:
			var effective_spacing = particle_grid_spacing + 2 * particle_radius
			var cols = int(ceil(sqrt(particle_count)))
			var rows = int(ceil(float(particle_count) / cols))
			var start_pos = (get_node(spawn_node_path) as Node2D).global_position
			start_pos -= Vector2(cols - 1, rows - 1) * effective_spacing * 0.5
			for row in range(rows):
				for col in range(cols):
					if len(dict) >= particle_count:
						break
					var pos = start_pos + Vector2(col, row) * effective_spacing
					var vel = Vector2.ZERO
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
