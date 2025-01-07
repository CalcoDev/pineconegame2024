extends Node2D

@export var _output_sprite: Sprite2D

var rd: RenderingDevice

var _shader_rid := RID()
var _output_tex_rid := RID()

func _ready() -> void:
	rd = RenderingServer.create_local_rendering_device()
	
	# do shader
	var shader_source: RDShaderFile = load("res://scenes/_debug/particle_sim_demo/particle.glsl")
	var shader_spirv := shader_source.get_spirv()
	_shader_rid = rd.shader_create_from_spirv(shader_spirv)

	# handle output texture data

	const TW := 320
	const TH := 240

	var img := Image.create(TW, TH, false, Image.FORMAT_RGBAF)
	_output_sprite.texture = ImageTexture.create_from_image(img)

	var f := RDTextureFormat.new()
	f.width = TW
	f.height = TH
	f.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	f.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var v := RDTextureView.new()
	_output_tex_rid = rd.texture_create(f, v, [img.get_data()])

	var tex_uniform := RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tex_uniform.binding = 0
	tex_uniform.add_id(_output_tex_rid)

	# image data uniform
	# var tex_data_data := PackedInt32Array([TW, TH]).to_byte_array()
	# var tex_data_buffer := rd.storage_buffer_create(tex_data_data.size(), tex_data_data)
	# var tex_data_uniform := RDUniform.new()
	# tex_data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	# tex_data_uniform.binding = 1
	# tex_data_uniform.add_id(tex_data_buffer)

	# uniform set
	var uniform_set := rd.uniform_set_create([tex_uniform], _shader_rid, 0)

	# pipeline
	var pipeline := rd.compute_pipeline_create(_shader_rid)

	# fire the things
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	@warning_ignore("INTEGER_DIVISION")
	rd.compute_list_dispatch(compute_list, TW / 8, TH / 8, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()
	var byte_data: PackedByteArray = rd.texture_get_data(_output_tex_rid, 0)
	_output_sprite.texture.update(Image.create_from_data(TW, TH, false, Image.FORMAT_RGBAF, byte_data))