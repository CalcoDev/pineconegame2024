extends Node2D

@export var debug_display: Node2D

@export_group("Simulation Settings")
@export var particle_count := 500
@export var particle_radius := 2.0
@export var particle_smoothing_radius := 20.0

@export var gravity := 0.0
@export var velocity_magnitude := 0.0

@export var target_density := 0.0
@export var pressure_multiplier := 10.0

@export var particle_color := Color()
@export var negative_pressure := Color()
@export var positive_pressure := Color()
@export var correct_pressure := Color()

@export_group("Spawn Settings")
@export var spawn_random := false
@export_node_path("Node2D") var spawn_node_path := NodePath("")
@export var particle_grid_spacing := 10.0

const TEXS := Vector2i(320, 240) * 4

var _rd: RenderingDevice

var _shaders: Array[ComputeShader] = []

var _particle_shader: ComputeShader
var _density_shader: ComputeShader
var _debug_draw_shader: ComputeShader

var _density_tex_shader: ComputeShader
var _density_tex := RID()

# shared buffers
var _particle_pos_buffer := RID() # store particle position
var _particle_vel_buffer := RID() # store particle velocity

var _density_buffer := RID() # store density at particle position

# debug drawing
var _debug_draw_kernel := RID()
var _debug_draw_output := RID()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			set_process(true)
			_rd = RenderingServer.get_rendering_device()

			@warning_ignore("INTEGER_DIVISION")
			var x_groups := (TEXS.x - 1) / 8 + 1
			@warning_ignore("INTEGER_DIVISION")
			var y_groups := (TEXS.y - 1) / 8 + 1

			_init_shared_buffers()
			_debug_draw_kernel = _make_texture(
				TEXS.x, TEXS.y,
				RenderingDevice.DataFormat.DATA_FORMAT_R32G32B32A32_SFLOAT,
				_ALL_TEX_BITS
			)
			_debug_draw_output = _make_texture(
				TEXS.x, TEXS.y,
				RenderingDevice.DataFormat.DATA_FORMAT_R32G32B32A32_SFLOAT,
				_ALL_TEX_BITS
			)

			const PATH := "res://scenes/_debug/fluid_simulation/shaders"
			_particle_shader = ComputeShader.new(
				_rd, PATH + "/particle_pass.glsl", Vector3i(64, 1, 1),
				_get_particle_shader_push_data
			)
			_particle_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0, [_particle_pos_buffer]
			))
			_particle_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1, [_particle_vel_buffer]
			))
			_particle_shader.add_uniform(1, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [_debug_draw_kernel]
			))
			_particle_shader.build_uniform_sets()

			_density_shader = ComputeShader.new(
				_rd, PATH + "/density_pass.glsl", Vector3i(64, 1, 1),
				_get_density_shader_push_data
			)
			_density_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0, [_particle_pos_buffer]
			))
			_density_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1, [_density_buffer]
			))
			_density_shader.build_uniform_sets()

			_density_tex = _make_texture(
				TEXS.x, TEXS.y,
				RenderingDevice.DataFormat.DATA_FORMAT_R32G32B32A32_SFLOAT,
				_ALL_TEX_BITS
			)
			
			_density_tex_shader = ComputeShader.new(
				_rd, PATH + "/density_texture_pass.glsl", Vector3i(x_groups, y_groups, 1),
				_get_density_tex_shader_push_data
			)
			_density_tex_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0, [_particle_pos_buffer]
			))
			_density_tex_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_IMAGE, 1, [_density_tex]
			))
			_density_tex_shader.build_uniform_sets()

			_debug_draw_shader = ComputeShader.new(
				_rd, PATH + "/debug_draw.glsl", Vector3i(x_groups, y_groups, 1),
				_get_debug_draw_shader_push_data
			)
			_debug_draw_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [_debug_draw_kernel]
			))
			_debug_draw_shader.add_uniform(0, _make_uniform(
				RenderingDevice.UNIFORM_TYPE_IMAGE, 1, [_debug_draw_output]
			))
			_debug_draw_shader.build_uniform_sets()

			_shaders.assign([_particle_shader, _density_shader, _density_tex_shader, _debug_draw_shader])

			await get_tree().create_timer(0.1).timeout
			_bind_texture_to_canvas_item(debug_display.get_canvas_item(), _density_tex, Rect2(Vector2.ZERO, TEXS))
			_bind_texture_to_canvas_item(debug_display.get_canvas_item(), _debug_draw_output, Rect2(Vector2.ZERO, TEXS))
		NOTIFICATION_PROCESS:
			_rd.texture_clear(_debug_draw_kernel, Color.BLACK, 0, 1, 0, 1)
			_rd.texture_clear(_debug_draw_output, Color.TRANSPARENT, 0, 1, 0, 1)

			# var particle_spawn_data := _get_particle_spawn_data()
			# var p_pos_data := PackedByteArray()
			# var p_vel_data := PackedByteArray()
			# for p in particle_spawn_data:
			# 	var f := PackedFloat32Array()
			# 	for i in 2: f.append(p["pos"][i])
			# 	p_pos_data.append_array(f.to_byte_array())
			# 	f.clear()
			# 	for i in 2: f.append(p["vel"][i])
			# 	p_vel_data.append_array(f.to_byte_array())
			# _rd.buffer_update(_particle_pos_buffer, 0, p_pos_data.size(), p_pos_data)
			# _rd.buffer_update(_particle_vel_buffer, 0, p_vel_data.size(), p_vel_data)

			for shader in _shaders:
				shader.update_shader()
		NOTIFICATION_PREDELETE:
			for shader in _shaders:
				shader.free_shader()
			_free_rid(_particle_pos_buffer)
			_free_rid(_particle_vel_buffer)
			_free_rid(_density_buffer)
			_free_rid(_debug_draw_kernel)
			_free_rid(_debug_draw_output)
			_free_rid(_density_tex)

func _get_particle_shader_push_data() -> PackedByteArray:
	var a := PackedByteArray()
	a.append_array(PackedInt32Array([particle_count]).to_byte_array())
	a.append_array(PackedFloat32Array([particle_radius, gravity, get_process_delta_time()]).to_byte_array())
	return a

func _get_density_shader_push_data() -> PackedByteArray:
	var a := PackedByteArray()
	a.append_array(PackedInt32Array([particle_count]).to_byte_array())
	a.append_array(PackedFloat32Array([particle_smoothing_radius]).to_byte_array())
	a.append_array(PackedInt32Array([0, 0]).to_byte_array()) # padding
	return a

func _get_density_tex_shader_push_data() -> PackedByteArray:
	var a := PackedByteArray()
	a.append_array(PackedInt32Array([particle_count]).to_byte_array())
	a.append_array(PackedFloat32Array([particle_smoothing_radius]).to_byte_array())
	# a.append_array(PackedInt32Array([0]).to_byte_array()) # padding
	a.append_array(PackedFloat32Array([target_density / 1000.0, pressure_multiplier]).to_byte_array())
	a.append_array(_encode_color(negative_pressure))
	a.append_array(_encode_color(positive_pressure))
	a.append_array(_encode_color(correct_pressure))
	return a

func _encode_color(color: Color, limit: int = 4) -> PackedByteArray:
	var a := PackedFloat32Array()
	for i in limit: a.append(color[i])
	return a.to_byte_array()

func _get_debug_draw_shader_push_data() -> PackedByteArray:
	var a := PackedByteArray()
	a.append_array(PackedFloat32Array([particle_radius]).to_byte_array())
	a.append_array(_encode_color(particle_color, 3))
	# a.append_array(PackedInt32Array([0, 0, 0]).to_byte_array()) # padding
	return a

func _init_shared_buffers() -> void:
	var particle_spawn_data := _get_particle_spawn_data()
	var p_pos_data := PackedByteArray()
	var p_vel_data := PackedByteArray()
	for p in particle_spawn_data:
		var f := PackedFloat32Array()
		for i in 2: f.append(p["pos"][i])
		p_pos_data.append_array(f.to_byte_array())
		f.clear()
		for i in 2: f.append(p["vel"][i])
		p_vel_data.append_array(f.to_byte_array())
	_particle_pos_buffer = _rd.storage_buffer_create(p_pos_data.size(), p_pos_data)
	_particle_vel_buffer = _rd.storage_buffer_create(p_vel_data.size(), p_vel_data)

	var density_data := PackedByteArray()
	for _p in particle_spawn_data:
		density_data.append_array(PackedInt32Array([0]).to_byte_array())
	_density_buffer = _rd.storage_buffer_create(density_data.size(), density_data)

func _get_particle_spawn_data() -> Array:
	var dict := []

	if spawn_random:
		for p in particle_count:
			var off := Vector2(
				randf_range(0.0, TEXS.x),
				randf_range(0.0, TEXS.y)
			)
			var pos := off
			var vel = random_point_on_unit_circle() * velocity_magnitude
			dict.append({"pos": pos, "vel": vel})
	else:
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
				var vel = random_point_on_unit_circle() * velocity_magnitude
				dict.append({"pos": pos, "vel": vel})
	return dict

func _bind_texture_to_canvas_item(item: RID, texture: RID, rect: Rect2) -> RID:
	var tex_rd := RenderingServer.texture_rd_create(texture)
	RenderingServer.canvas_item_add_texture_rect(item, rect, tex_rd)
	return tex_rd

@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
const _ALL_TEX_BITS: RenderingDevice.TextureUsageBits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
	| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
	| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
	| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT \
	| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
func _make_texture(width: int, height: int, format: RenderingDevice.DataFormat, usage_bits: RenderingDevice.TextureUsageBits) -> RID:
	var tf := RDTextureFormat.new()
	tf.width = width
	tf.height = height
	tf.format = format
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = usage_bits
	return _rd.texture_create(tf, RDTextureView.new(), [])

func _make_uniform(type: RenderingDevice.UniformType, binding: int, ids: Array[RID]) -> RDUniform:
	var uni := RDUniform.new()
	uni.uniform_type = type
	uni.binding = binding
	for id in ids:
		uni.add_id(id)
	return uni

func _free_rid(rid: RID) -> bool:
	if rid and rid != RID():
		_rd.free_rid(rid)
		return true
	return false

func random_point_on_unit_circle() -> Vector2:
	var angle = randf() * PI * 2.0
	return Vector2(cos(angle), sin(angle))