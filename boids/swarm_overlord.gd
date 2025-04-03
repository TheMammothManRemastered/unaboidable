extends Node2D
class_name SwarmOverlord

static var instance: SwarmOverlord

# NOTE: there should only ever be one of these in a scene
# NOTE: this file is kinda horrendously ugly, sorry

var frame_count: int = 0
var frames_per_swarm_synchronization: int = 3
# set to true when the number of boids changes, will cause GPU synchronization if true
var boids_out_of_date: bool = true
# references to every boid we are overlord of
var boid_objects: Array[Boid] = []
# static (unmoving) avoidance objects
var avoidance_objects: Array[CircleAvoidancePoint] = []
# array of every boid type possible, will be used when sending uniforms to the compute shader
var all_possible_boid_types = [
	SimpleBoid, StupidBoid
]
# these arrays are transformed into data for the compute shader
# keeping them packed is convenient for that purpose
var boid_positions: PackedVector2Array = PackedVector2Array([])
var boid_velocities: PackedVector2Array = PackedVector2Array([])
var boid_types: PackedInt32Array = PackedInt32Array([])
# uniform values to be sent to the compute shader
@export var max_speed: float = 500.0
@export var boundaries: Vector2 = Vector2(600, 300)
@export var boundary_weight: float = 35
# binding locations for each uniform, ensure this matches the compute shader source
const POSITION_UNIFORM_BINDING = 0
const VELOCITY_UNIFORM_BINDING = 1
const TYPE_UNIFORM_BINDING = 2
const AVOIDANCE_UNIFORM_BINDING = 3
const UNIFORMS_UNIFORM_BINDING = 4
const IMMUTABLE_TYPE_DATA_UNIFORM_BINDING = 5
const GLOBAL_GOALS_UNIFORM_BINDING = 6

# compute shader resources
var device: RenderingDevice
var compute_shader: RID
var compute_pipeline: RID
var boid_positions_buffer: RID
var boid_positions_uniform: RDUniform
var boid_velocities_buffer: RID
var boid_velocities_uniform: RDUniform
var boid_types_buffer: RID
var boid_types_uniform: RDUniform
var avoidance_objects_buffer: RID
var avoidance_objects_uniform: RDUniform
var boid_uniforms_buffer: RID
var boid_uniforms_uniform: RDUniform # this name is terrible, why did I call it this?
var immutable_type_data_buffer: RID
var immutable_type_data_uniform: RDUniform
var global_goals_buffer: RID
var global_goals_uniform: RDUniform
var bindings: Array[RDUniform]
var uniform_set: RID

func are_boids_present() -> bool:
	return boid_objects.size() != 0

func create_vec2_buffer(packed_array: PackedVector2Array) -> RID:
	var bytes: PackedByteArray = packed_array.to_byte_array()
	return device.storage_buffer_create(bytes.size(), bytes)

func create_float_buffer(array: Array[float]) -> RID:
	var bytes: PackedByteArray = PackedFloat32Array(array).to_byte_array()
	return device.storage_buffer_create(bytes.size(), bytes)

func create_int32_buffer(packed_array: PackedInt32Array) -> RID:
	var bytes: PackedByteArray = packed_array.to_byte_array()
	return device.storage_buffer_create(bytes.size(), bytes)

func create_boid_uniforms_buffer(delta: float) -> RID:
	# NOTE: these should be filled out in the SAME ORDER as specified in the compute shader!
	return create_float_buffer([
		float(boid_objects.size()),
		float(avoidance_objects.size()),
		boundaries.x,
		boundaries.y,
		global_position.x,
		global_position.y,
		boundary_weight,
		delta
	])

func create_global_goals_buffer() -> RID:
	# the global goals buffer will always have the player's position in index 0
	# ideally we'd have several more points for boids to retreat to after hitting the player
	var player_position: Vector2 = Player.instance.global_position
	return create_float_buffer([player_position.x, player_position.y])

func get_immutable_type_data(type: Object) -> Array[float]:
	return [
		type.max_speed,
		type.separation_radius,
		type.separation_weight,
		type.alignment_radius,
		type.alignment_weight,
		type.cohesion_radius,
		type.cohesion_weight,
		1.0 if type.discriminatory else 0.0
	]

func create_immutable_type_data_buffer() -> RID:
	var unpacked: Array[float] = []
	for type in all_possible_boid_types:
		unpacked.append_array(get_immutable_type_data(type))
	var packed: PackedFloat32Array = PackedFloat32Array(unpacked)
	var bytes: PackedByteArray = packed.to_byte_array()
	return device.storage_buffer_create(bytes.size(), bytes)

func setup_avoidance_uniform() -> void: 
	# make a byte array for the avoidance objects
	# omfg i need to handle BYTE ALIGNMENT in GDSCRIPT
	# structure of the shader's AvoidanceObject struct:
	#	vec2 position
	#	float major_radius
	#	float minor_radius
	# floats are 32 bits each, and vec2s are 64 bits each (two floats)
	# conveniently, this makes each AvoidanceObject 128 bits (16 bytes)
	# and they align tightly
	var floats_buffer: Array[float] = []
	floats_buffer.resize(max(avoidance_objects.size() * 4, 4))
	
	for i in range(avoidance_objects.size()):
		var buffer_index: int = i * 4
		var curr_object: CircleAvoidancePoint = avoidance_objects[i]
		floats_buffer[buffer_index] = curr_object.global_position.x
		floats_buffer[buffer_index + 1] = curr_object.global_position.y
		floats_buffer[buffer_index + 2] = curr_object.major_radius
		floats_buffer[buffer_index + 3] = curr_object.minor_radius
		print("adding avoidance object at", floats_buffer[buffer_index], ", ", floats_buffer[buffer_index + 1],
		" with ", floats_buffer[buffer_index + 2], floats_buffer[buffer_index + 3])
	
	avoidance_objects_buffer = create_float_buffer(floats_buffer)
	avoidance_objects_uniform = create_uniform(avoidance_objects_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, AVOIDANCE_UNIFORM_BINDING)

func setup_immutable_type_data_uniform() -> void:
	immutable_type_data_buffer = create_immutable_type_data_buffer()
	immutable_type_data_uniform = create_uniform(immutable_type_data_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, IMMUTABLE_TYPE_DATA_UNIFORM_BINDING)

func create_uniform(resource: RID, type: RenderingDevice.UniformType, binding: int) -> RDUniform:
	var uniform = RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	uniform.add_id(resource)
	return uniform

func create_empty_uniform(type: RenderingDevice.UniformType, binding: int) -> RDUniform:
	var uniform = RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	return uniform

func setup_compute_shaders() -> void:
	device = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://boids/boid_compute_2.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	compute_shader = device.shader_create_from_spirv(shader_spirv)
	compute_pipeline = device.compute_pipeline_create(compute_shader)

func setup_bindings() -> void:
	boid_positions_uniform = create_empty_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, POSITION_UNIFORM_BINDING)
	boid_velocities_uniform = create_empty_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, VELOCITY_UNIFORM_BINDING)
	boid_uniforms_uniform = create_empty_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, UNIFORMS_UNIFORM_BINDING)
	boid_types_uniform = create_empty_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, TYPE_UNIFORM_BINDING)
	global_goals_uniform = create_empty_uniform(RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, GLOBAL_GOALS_UNIFORM_BINDING)
	
	setup_avoidance_uniform()
	setup_immutable_type_data_uniform()
	
	bindings = [boid_positions_uniform, boid_velocities_uniform, 
		boid_types_uniform, avoidance_objects_uniform, 
		boid_uniforms_uniform, immutable_type_data_uniform, 
		global_goals_uniform]

func set_uniform(uniform: RDUniform, resource: RID) -> void:
	var to_clear = uniform.get_ids()
	for c in to_clear:
		device.free_rid(c)
	uniform.clear_ids()
	uniform.add_id(resource)

func update_compute_data(delta: float) -> void:
	if not are_boids_present():
		return
	
	if boids_out_of_date:
		boid_positions_buffer = create_vec2_buffer(boid_positions)
		set_uniform(boid_positions_uniform, boid_positions_buffer)
		
		boid_velocities_buffer = create_vec2_buffer(boid_velocities)
		set_uniform(boid_velocities_uniform, boid_velocities_buffer)
		
		boid_types_buffer = create_int32_buffer(boid_types)
		set_uniform(boid_types_uniform, boid_types_buffer)
		boids_out_of_date = false
	
	global_goals_buffer = create_global_goals_buffer()
	set_uniform(global_goals_uniform, global_goals_buffer)
	
	boid_uniforms_buffer = create_boid_uniforms_buffer(delta)
	set_uniform(boid_uniforms_uniform, boid_uniforms_buffer)
	uniform_set = device.uniform_set_create(bindings, compute_shader, 0)
	
	# send this to the GPU
	var compute_list := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, compute_pipeline)
	device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	device.compute_list_dispatch(compute_list, ceil(boid_objects.size() / 1024.0), 1, 1)
	device.compute_list_end()
	device.submit()

func retrieve_compute_data() -> void:
	if not are_boids_present():
		return
	
	var positions_bytes: PackedByteArray = device.buffer_get_data(boid_positions_buffer)
	var positions_floats: PackedFloat32Array = positions_bytes.to_float32_array()
	
	var velocities_bytes: PackedByteArray = device.buffer_get_data(boid_velocities_buffer)
	var velocities_floats: PackedFloat32Array = velocities_bytes.to_float32_array()
	
	# types are never gonna get changed in-shader, nor will immutable type data, so we don't retrieve them
	
	for i in range(0, boid_objects.size()):
		if (i * 2 >= positions_floats.size() or i * 2 >= velocities_floats.size()):
			return
		var curr_position: Vector2 = Vector2(positions_floats[i * 2], positions_floats[i * 2 + 1])
		var curr_velocity: Vector2 = Vector2(velocities_floats[i * 2], velocities_floats[i * 2 + 1])
		boid_objects[i].global_position = curr_position
		boid_objects[i].velocity = curr_velocity
		boid_positions[i] = curr_position
		boid_velocities[i] = curr_velocity



# QUEUE OPERATIONS - boid adding/removal is handled here
var boid_add_queue = []
var boid_remove_queue = []

func queue_add_boid(b: Boid) -> void:
	boid_add_queue.push_back(b)

func queue_remove_boid(b: Boid) -> void:
	boid_remove_queue.push_back(b)

func add_boid(b: Boid) -> void:
	boid_objects.append(b)
	boid_positions.append(b.global_position)
	boid_velocities.append(b.velocity)
	boid_types.append(b.class_id)
	boids_out_of_date = true

func remove_boid(b: Boid) -> void:
	var i = boid_objects.find(b)
	if (i == -1):
		return
	boid_objects.remove_at(i)
	boid_positions.remove_at(i)
	boid_velocities.remove_at(i)
	boid_types.remove_at(i)
	boids_out_of_date = true

func process_queues() -> void:
	while boid_add_queue.size() > 0:
		var b: Boid = boid_add_queue.pop_front()
		add_boid(b)
		b.on_overlord_added()
	while boid_remove_queue.size() > 0:
		var b: Boid = boid_remove_queue.pop_front()
		remove_boid(b)
		b.on_overlord_removed()





# this is a debug function
var boid_scene = preload("res://boids/boid_types/simple_boid.tscn")
var boid_scene2 = preload("res://boids/boid_types/stupid_boid.tscn")
func spawn_some_boids(boids_to_spawn, spacing) -> void:
	for i in range(boids_to_spawn):
		var b: Boid = boid_scene2.instantiate() if randf_range(0.0, 1.0) > 0.5 else boid_scene.instantiate()
		b.global_position = Vector2(0, 0)
		var w = spacing.x / 2.0
		var h = spacing.y / 2.0
		b.global_position.x += randf_range(-w, w)
		b.global_position.y += randf_range(-h, h)
		b.velocity = Vector2.from_angle(randf() * PI * 2.0) * (randf() * 20.0)
		$CanvasGroup.add_child(b)
		queue_add_boid(b)
	print("all boids are added")






func set_avoidance_objects() -> void:
	for child: CircleAvoidancePoint in $AvoidanceObjects.get_children():
		avoidance_objects.append(child)

func _ready() -> void:
	instance = self
	
	set_avoidance_objects()
	
	setup_compute_shaders()
	setup_bindings()
	
	# for testing, spawn boids right away
	spawn_some_boids(30, Vector2(500, 500))

func _physics_process(delta: float) -> void:
	# NOTE: boids being added or removed is only processed every X frames
	#if ((frame_count % frames_per_swarm_synchronization) == 0 or boids_out_of_date):
	process_queues()
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

func _on_button_pressed() -> void:
	pass # Replace with function body.
