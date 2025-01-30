extends Node2D
class_name SwarmBrain

# parent class for all boids, defines basic behaviour
@export var coherence_weight: float = 1.0
@export var separation_weight: float = 3.5
@export var separation_distance: float = 30.0
@export var alignment_weight: float = 1.0
@export var world_boundary_weight: float = 10.0
@export var world_box_size: Vector2 = Vector2(1920, 1080)
@export var goal_weight: float = 15.4
@export var maximum_speed: float = 400.0
@export var acceleration: float = 10.0

var boid_scene: PackedScene = preload("res://boid.tscn")

var boids: Array[Boid] = []
var global_center_of_mass: Vector2
var world_box: Vector2 = world_box_size / 2.0
var goal: Node2D = null

func _physics_process(delta: float) -> void:
	global_center_of_mass = calculate_global_center_of_mass()
	
	for i in range(0, boids.size()):
		var coherence = calculate_coherence_vector(i)
		var separation = calculate_separation_vector(i)
		var alignment = calculate_alignment_vector(i)
		var world_boundary = calculate_world_boundary_vector(i)
		var goal = calculate_goal_vector(i)
		
		var resultant = (coherence * coherence_weight
		+ separation * separation_weight
		+ alignment * alignment_weight
		+ world_boundary * world_boundary_weight
		+ goal * goal_weight)
		
		boids[i].velocity += resultant# * acceleration
		cap_speed(boids[i])
		boids[i].move_and_slide()

func cap_speed(b: Boid) -> void:
	if (b.velocity.length() > maximum_speed):
		b.velocity = b.velocity.normalized() * maximum_speed

func set_goal(to: Node2D) -> void:
	goal = to

func spawn_boids(count: int, position: Vector2, spacing: Vector2) -> void:
	boids.clear()
	for i in get_children():
		i.queue_free()
	print("all children destroyed")
	for i in range(count):
		print("making boid ", i)
		var b: Boid = boid_scene.instantiate()
		b.global_position = position
		var w = spacing.x / 2.0
		var h = spacing.y / 2.0
		b.global_position.x += randf_range(-w, w)
		b.global_position.y += randf_range(-h, h)
		b.velocity = Vector2.from_angle(randf() * PI * 2.0) * (randf() * 100.0)
		self.add_child(b)
		boids.append(b)

func calculate_global_center_of_mass() -> Vector2:
	var out = Vector2.ZERO
	for boid in boids:
		out += boid.global_position
	
	return out

func calculate_local_center_of_mass(index: int) -> Vector2:
	return (global_center_of_mass - boids[index].global_position) / (boids.size() - 1)

# this calculates the center of mass for the boid swarm and biases each boid towards it
func calculate_coherence_vector(index: int) -> Vector2:
	var local_com: Vector2 = calculate_local_center_of_mass(index)
	# get direction towards the local center of mass
	return (local_com - boids[index].global_position)

func calculate_separation_vector(index: int) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	# if there are any nearby boids, move away from them (we don't want to crash)
	var boid: Boid = boids[index]
	for i in range(0, boids.size()):
		if (i == index): # don't consider ourselves
			continue
		var other_boid: Boid = boids[i]
		if (boid.global_position.distance_to(other_boid.global_position) > separation_distance):
			continue
		# we are too close to the other boid, move us away from it
		out = out - (other_boid.global_position - boid.global_position)
	# may be zero if no boids are nearby
	return out

# try to match velocity with other boids
func calculate_alignment_vector(index: int) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	for i in range(0, boids.size()):
		if (i == index):
			continue
		out += boids[i].velocity
	
	out /= boids.size() - 1
	out = (out - boids[index].velocity) / 8.0
	
	return out

func calculate_goal_vector(index: int) -> Vector2:
	if (goal == null):
		return Vector2.ZERO
	return boids[index].global_position.move_toward(goal.global_position, 999.0).normalized()

func calculate_world_boundary_vector(index: int) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	var b: Boid = boids[index]
	if b.global_position.abs().x >= world_box.x:
		out.x = b.global_position.x / -1.0
	if b.global_position.abs().y >= world_box.y:
		out.y = b.global_position.y / -1.0
	
	return out.normalized()
