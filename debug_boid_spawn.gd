extends Button

signal boid(int, Vector2, Vector3)

func _on_pressed() -> void:
	boid.emit(20, Vector2(0, 0), Vector2(50, 50))
