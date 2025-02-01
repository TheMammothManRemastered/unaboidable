extends Node2D
class_name SwarmBrain

# Making this faster (if problems arise):
# easiest refactor is to push all the vector calculations into a single loop
# it'll be ugly as sin but it'll get us a slightly better runtime (still O(n^2) though)
# then if there are still problems, we can go down two paths (possibly at once!)
# 1. space partitioning
# 	split the world into a grid, boids only consider other boids in their neighborhood
#	this isn't something i've ever done before, but it, theoretically, shouldn't be THAT bad
# 2. compute shaders
#	boids are often implemented in shaders, and godot DOES support compute shaders
#	the challenge here is learning to write compute shaders lmao
#	thankfully the math is mostly just vector calculations, and shaders can do those
#	the issue I see with this is how to resolve collisions effectively, I have no idea what havoc
#	this could wreak on collisions

# the most basic boid brain, brilliantly defines basic boid behaviour
@export var separation_weight: float = 1.0
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var separation_radius: float = 30.0
@export var alignment_radius: float = 75.0
@export var cohesion_radius: float = 100.0
@export var world_boundary_weight: float = 1.0
@export var show_debug_radii: bool = false

@export var world_boundary_size: Vector2 = Vector2(1920, 1080)
@export var world_weight: float = 400.0

@export var maximum_speed: float = 400.0
@export var acceleration: float = 10.0

var boid_scene: PackedScene = preload("res://boids/boid.tscn")

var boids: Array[Boid] = []
var world_box: Vector2 = world_boundary_size / 2.0

var goal: Node2D = null

func random_unit_vector() -> Vector2:
	return Vector2.from_angle(randf() * 2.0 * PI)

# calculates the (weighted) separation vector for a single boid
func calculate_separation_vector(boid: Boid) -> Vector2:
	var separation_vector: Vector2 = Vector2.ZERO
	var n: int = 0
	
	for other in boids:
		# ignore if we are checking against ourselves
		if (boid == other):
			continue
		
		var distance: float = boid.distance_to_boid(other)
		# if we're too close, get the direction away from the other boid, weight it by its distance
		# then add it to the output vector
		if distance < separation_radius:
			var direction_away: Vector2 = other.vector_to_boid(boid, true)
			# prevent funny zero-division (unlikely to be necessary)
			separation_vector += direction_away / (distance / (separation_radius * 0.5))
			n += 1
	
	# average the result so it's not super high
	if n > 0:
		separation_vector /= float(n)
	
	return separation_vector * separation_weight

# calculates the (weighted) alignment vector for a single boid
func calculate_alignment_vector(boid: Boid) -> Vector2:
	var alignment_vector: Vector2 = Vector2.ZERO
	var n: int = 0
	
	for other in boids:
		# ignore if we are checking against ourselves
		if other == boid:
			continue
		
		# add velocities of all nearby boids
		var distance: float = boid.distance_to_boid(other)
		if distance < alignment_radius:
			alignment_vector += other.velocity
			n += 1
	
	# average the velocity
	if n > 0:
		alignment_vector /= float(n)
	
	return alignment_vector * alignment_weight

# calculates the (weighted) cohesion vector for a single boid
func calculate_cohesion_vector(boid: Boid) -> Vector2:
	var cohesion_vector: Vector2 = Vector2.ZERO
	var target_position: Vector2 = Vector2.ZERO
	var n: int = 0
	
	for other in boids:
		# ignore if we are checking against ourselves
		if other == boid:
			continue
		
		var distance: float = boid.distance_to_boid(other)
		if (distance < cohesion_radius):
			target_position += other.global_position
			n += 1
	
	if n > 0:
		target_position /= float(n)
		cohesion_vector = target_position - boid.global_position
		cohesion_vector = cohesion_vector.normalized()
	
	return cohesion_vector * cohesion_weight

# calculates the (weighted) world boundary vector for a single boid
func calculate_world_vector(boid: Boid) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	var diff_x: float = abs(boid.position.x) + world_box.x
	var diff_y: float = abs(boid.position.y) + world_box.y
	
	if boid.position.x > world_box.x:
		out.x = -1.0
	elif boid.position.x < -world_box.x:
		out.x = 1.0
	if boid.position.y > world_box.y:
		out.y = -1.0
	elif boid.position.y < -world_box.y:
		out.y = 1.0
	
	return out * world_weight

func _physics_process(delta: float) -> void:
	for boid in boids:
		var separation = calculate_separation_vector(boid)
		var alignment = calculate_alignment_vector(boid)
		var cohesion = calculate_cohesion_vector(boid)
		var world = calculate_world_vector(boid)
		
		var resultant = (separation + alignment + cohesion + world)
		if resultant.length() > acceleration:
			resultant = resultant.normalized() * acceleration
		
		boid.velocity += resultant
		cap_speed(boid)

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
		if (show_debug_radii):
			b.add_colored_radius(separation_radius, Color.RED)
			b.add_colored_radius(alignment_radius, Color.YELLOW)
			b.add_colored_radius(cohesion_radius, Color.GREEN)
		b.global_position = position
		var w = spacing.x / 2.0
		var h = spacing.y / 2.0
		b.global_position.x += randf_range(-w, w)
		b.global_position.y += randf_range(-h, h)
		b.velocity = Vector2.from_angle(randf() * PI * 2.0) * (randf() * 100.0)
		self.add_child(b)
		boids.append(b)
