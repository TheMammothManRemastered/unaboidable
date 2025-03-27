extends CanvasLayer

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("start_game"):
		Globals.game_started.emit()
		queue_free()
