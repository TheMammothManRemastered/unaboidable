extends Node2D

signal boid(int, Vector2, Vector3)

@export var number_of_boids: int = 30
@export var boid_spawn_spacing: Vector2 = Vector2(500, 500)

func _on_pressed() -> void:
	$SwarmOverlord.spawn_some_boids(number_of_boids, boid_spawn_spacing)
