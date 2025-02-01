extends Node2D

signal boid(int, Vector2, Vector3)

@export var number_of_boids: int = 30

func _on_pressed() -> void:
	boid.emit(number_of_boids, Vector2(0, 0), Vector2(500, 500))

func _on_button_2_pressed() -> void:
	$SwarmBrain.set_goal(null)

func _set_goal_1() -> void:
	print("now targeting goal 1")
	$SwarmBrain.set_goal($Goal1)

func _set_goal_2() -> void:
	print("now targeting goal 2")
	$SwarmBrain.set_goal($Goal2)
