extends Sprite2D

func _process(delta: float) -> void:
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	position += Vector2(550, 300)
	rotation_degrees = randf_range(-1, 1) * .2
