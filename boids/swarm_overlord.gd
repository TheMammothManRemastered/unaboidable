extends Node2D
class_name SwarmOverlord

# this synchronizes a number of SwarmBrains' compute shaders and calculations
# NOTE: there should only ever be one of these in a scene

var frame_count: int = 0
var frames_per_swarm_synchronization: int = 4

var device: RenderingDevice
var compute_shader: RID

var boids: Array[Boid] = []

func submit_shader_data() -> void:
	# make a buffer of data for the shader to use
	var test_data := PackedFloat32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	var test_data_bytes := test_data.to_byte_array()
	var data_buffer: RID = device.storage_buffer_create(test_data_bytes.size(), test_data_bytes);
	
	# Create a uniform to assign the buffer to the rendering device
	var boid_buffer_uniform := RDUniform.new()
	boid_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	boid_buffer_uniform.binding = 0 # this needs to match the "binding" in our shader file
	boid_buffer_uniform.add_id(data_buffer)
	
	
	var info_block_uniform := RDUniform.new()
	info_block_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	info_block_uniform.binding = 1 # this needs to match the "binding" in our shader file
	info_block_uniform.add_id(data_buffer)
	
	var uniform_set := device.uniform_set_create([boid_buffer_uniform, info_block_uniform], compute_shader, 0)
	
	# now, set up the pipeline
	var pipeline := device.compute_pipeline_create(compute_shader)
	var compute_list := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	device.compute_list_dispatch(compute_list, 5, 1, 1)
	device.compute_list_end()

func _ready() -> void:
	# glean info from all swarm brains on what they support
	# translate this into parameters for compute shaders
	# and also the shader files themselves
	# make ready the pipeline
	
	device = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://boids/boid_compute_1.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	compute_shader = device.shader_create_from_spirv(shader_spirv)

var lock = false

func _physics_process(delta: float) -> void:
	if (frame_count % frames_per_swarm_synchronization):
		# we need to sync the device and send it the next batch of computations
		# since syncing is slow, we do this every X frames
		var output_bytes := device.buffer_get_data(data_buffer)
		var output := output_bytes.to_float32_array()
		print("Output: ", output)
	
	# tell the brains to update the positions of their boids each frame
	# I may move this to be performed on lesser intervals, anything in the name of performance
	# related, TODO: refactor the boids such that their velocity is stored and applied in the brains
	# this should translate to better performance when it comes to getting data out of the compute
	# shaders. the actual boid objects shouldn't do anything apart from keep track of if they hit the player
	# or, like, a wall, then signal their brain to resolve the collision
	
	# for brain in brains:
	# 	brain.update_boids()
	# Read back the data from the buffer
	# don't forget to do this :3 or everything breaks :3
	frame_count += 1
