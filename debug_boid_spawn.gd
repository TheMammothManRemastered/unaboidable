extends Node2D

signal boid(int, Vector2, Vector3)

func _on_pressed() -> void:
	boid.emit(20, Vector2(0, 0), Vector2(50, 50))

func _on_button_2_pressed() -> void:
	$SwarmBrain.set_goal(null)

func _set_goal_1() -> void:
	print("now targeting goal 1")
	$SwarmBrain.set_goal($Goal1)

func _set_goal_2() -> void:
	print("now targeting goal 2")
	$SwarmBrain.set_goal($Goal2)
