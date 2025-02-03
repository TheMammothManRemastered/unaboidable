extends Node2D
class_name SwarmOverlord

# this synchronizes a number of SwarmBrains' compute shaders and calculations
# NOTE: there should only ever be one of these in a scene

var frame_count: int = 0
var frames_per_swarm_synchronization: int = 3

# set to true when the number of boids changes
var boids_out_of_date: bool = false
# references to every boid we are overlord of
var boid_objects: Array[Boid] = []
# these arrays are used to create data that gets sent to the compute shader
# they only ever get updated when the number of boids changes, do not rely on
# them for up-to-date boid information
var boid_positions: Array[Vector2] = []
var boid_velocities: Array[Vector2] = []
@export var max_speed: float = 500.0
@export var boundaries: Vector2 = Vector2(600, 300)
@export var boundary_weight: float = 35
@export var separation_radius: float = 40
@export var separation_weight: float = 30
@export var alignment_radius: float = 75
@export var alignment_weight: float = 0.2
@export var cohesion_radius: float = 150
@export var cohesion_weight: float = 0.15

# compute shader resources
var device: RenderingDevice
var compute_shader: RID
var compute_pipeline: RID
var boid_positions_buffer: RID
var boid_positions_uniform: RDUniform
var boid_velocities_buffer: RID
var boid_velocities_uniform: RDUniform
var boid_uniforms_buffer: RID
var boid_uniforms_uniform: RDUniform
var bindings: Array[RDUniform]
var uniform_set: RID

func add_boid(boid: Boid) -> void:
	boids_out_of_date = true
	boid_objects.append(boid)
	boid_positions.append(Vector2(boid.global_position))
	boid_velocities.append(Vector2(boid.velocity))

func delete_boid(boid: Boid) -> void:
	var index = boid_objects.find(boid)
	if (index == -1):
		push_warning("Tried to delete nonexistant boid")
		return
	boids_out_of_date = true
	boid_objects.remove_at(index)
	boid_positions.remove_at(index)
	boid_velocities.remove_at(index)

func create_vec2_buffer(array: Array[Vector2]) -> RID:
	var bytes: PackedByteArray = PackedVector2Array(array).to_byte_array()
	return device.storage_buffer_create(bytes.size(), bytes)

func create_float_buffer(array: Array[float]) -> RID:
	var bytes: PackedByteArray = PackedFloat32Array(array).to_byte_array()
	return device.storage_buffer_create(bytes.size(), bytes)

func create_boid_uniforms_buffer(delta: float) -> RID:
	return create_float_buffer([
		float(boid_objects.size()),
		max_speed,
		boundaries.x,
		boundaries.y,
		boundary_weight,
		separation_radius,
		separation_weight,
		alignment_radius,
		alignment_weight,
		cohesion_radius,
		cohesion_weight,
		delta
	])

func create_uniform(resource: RID, type: RenderingDevice.UniformType, binding: int):
	var uniform = RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	uniform.add_id(resource)
	return uniform

func setup_compute_shaders() -> void:
	device = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://boids/boid_compute_1.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	compute_shader = device.shader_create_from_spirv(shader_spirv)
	compute_pipeline = device.compute_pipeline_create(compute_shader)

func setup_bindings() -> void:
	boid_positions_buffer = create_vec2_buffer(boid_positions)
	boid_positions_uniform = create_uniform(boid_positions_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	boid_velocities_buffer = create_vec2_buffer(boid_velocities)
	boid_velocities_uniform = create_uniform(boid_velocities_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	boid_uniforms_buffer = create_boid_uniforms_buffer(0.0)
	boid_uniforms_uniform = create_uniform(boid_uniforms_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	bindings = [boid_positions_uniform, boid_velocities_uniform, boid_uniforms_uniform]

func update_compute_data(delta: float) -> void:
	if boids_out_of_date:
		device.free_rid(boid_positions_buffer)
		boid_positions_buffer = create_vec2_buffer(boid_positions)
		boid_positions_uniform.clear_ids()
		boid_positions_uniform.add_id(boid_positions_buffer)
		
		device.free_rid(boid_velocities_buffer)
		boid_velocities_buffer = create_vec2_buffer(boid_velocities)
		boid_velocities_uniform.clear_ids()
		boid_velocities_uniform.add_id(boid_velocities_buffer)
		boids_out_of_date = false
	
	device.free_rid(boid_uniforms_buffer)
	boid_uniforms_buffer = create_boid_uniforms_buffer(delta)
	boid_uniforms_uniform.clear_ids()
	boid_uniforms_uniform.add_id(boid_uniforms_buffer)
	uniform_set = device.uniform_set_create(bindings, compute_shader, 0)
	
	# send this to the GPU
	var compute_list := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, compute_pipeline)
	device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	device.compute_list_dispatch(compute_list, ceil(boid_objects.size() / 1024.0), 1, 1)
	device.compute_list_end()
	device.submit()

func retrieve_compute_data() -> void:
	var positions_bytes: PackedByteArray = device.buffer_get_data(boid_positions_buffer)
	var positions_floats: PackedFloat32Array = positions_bytes.to_float32_array()
	
	var velocities_bytes: PackedByteArray = device.buffer_get_data(boid_velocities_buffer)
	var velocities_floats: PackedFloat32Array = velocities_bytes.to_float32_array()
	
	for i in range(0, boid_objects.size()):
		boid_objects[i].global_position = Vector2(positions_floats[i * 2], positions_floats[i * 2 + 1])
		boid_objects[i].velocity = Vector2(velocities_floats[i * 2], velocities_floats[i * 2 + 1])

@export var boids_to_spawn: int = 20
@export var spacing: Vector2 = Vector2(200.0, 200.0)
var boid_scene = preload("res://boids/boid.tscn")
func spawn_some_boids() -> void:
	for i in range(boids_to_spawn):
		var b: Boid = boid_scene.instantiate()
		b.global_position = position
		var w = spacing.x / 2.0
		var h = spacing.y / 2.0
		b.global_position.x += randf_range(-w, w)
		b.global_position.y += randf_range(-h, h)
		b.velocity = Vector2.from_angle(randf() * PI * 2.0) * (randf() * 100.0)
		$CanvasGroup.add_child(b)
		add_boid(b)

func _ready() -> void:
	spawn_some_boids()
	
	setup_compute_shaders()
	setup_bindings()
	
	update_compute_data(0.0)

func _physics_process(delta: float) -> void:
	if (frame_count % frames_per_swarm_synchronization):
		update_compute_data(delta)
		device.sync()
	
	retrieve_compute_data()
	
	# don't forget to do this :3 or everything breaks :3
	frame_count += 1

func _exit_tree() -> void:
	# reference tracking? in my gdscript? it's more likely than you think
	device.sync()
	device.free_rid(uniform_set)
	device.free_rid(boid_positions_buffer)
	device.free_rid(boid_velocities_buffer)
	device.free_rid(boid_uniforms_buffer)
	device.free_rid(compute_pipeline)
	device.free_rid(compute_shader)
	device.free()
