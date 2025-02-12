extends Camera2D

@onready var center_position := position
@export_range(0, 1) var player_influence: float

func _process(delta: float) -> void:
	position = lerp(center_position, Player.instance.position, player_influence)
