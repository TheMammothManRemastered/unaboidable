extends Node
class_name Wave

@export var quantities: Array[int] = []
@export var use_weights: bool = false
@export var weights: Array[float] = []
@export var max_spawns: int = 0

var boid_scenes = []
var rng: RandomNumberGenerator = null

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	
	if use_weights:
		assert(weights.size() == get_child_count(), "Weights array size invalid")
	else:
		assert(quantities.size() == get_child_count(), "Quantities array size invalid")
	
	for c in get_children():
		boid_scenes.append(c.boid_scene)
		c.queue_free()

func spawn_boid(scene: PackedScene) -> void:
	var overlord: SwarmOverlord = SwarmOverlord.instance
	var b: Boid = scene.instantiate()
	b.global_position = Vector2(0, 0)
	var w = 600
	var h = 600
	b.global_position.x += randf_range(-w, w)
	b.global_position.y += randf_range(-h, h)
	b.velocity = Vector2.from_angle(randf() * PI * 2.0) * (randf() * 20.0)
	overlord.get_canvas_group().add_child(b)
	overlord.queue_add_boid(b)

func spawn_weighted() -> void:
	for c in range(max_spawns):
		var bs: PackedScene = boid_scenes[rng.rand_weighted(PackedFloat32Array(weights))]
		spawn_boid(bs)

func spawn_fixed() -> void:
	for i in range(quantities.size()):
		var bs: PackedScene = boid_scenes[i]
		for c in range(quantities[i]):
			spawn_boid(bs)

func spawn_all() -> void:
	if use_weights:
		spawn_weighted()
	else:
		spawn_fixed()
