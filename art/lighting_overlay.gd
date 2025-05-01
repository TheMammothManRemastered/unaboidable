extends TextureRect

@onready var base_position := position

func _process(delta: float) -> void:
	if Engine.get_frames_drawn() % 4 == 0:
		random_move()
	
	if Player.instance.is_dead:
		create_tween().tween_property(self, "modulate", Color.BLACK, 2.0)
		if modulate.r < .1:
			get_tree().reload_current_scene()
			Engine.time_scale = 1.0

func random_move() -> void:
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 20 + base_position
	rotation_degrees = randf_range(-1, 1) * 2
