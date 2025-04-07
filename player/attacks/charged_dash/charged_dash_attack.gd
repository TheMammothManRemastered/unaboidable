class_name ChargedDashAttack extends Node2D

var current_display := Vector2.ZERO

var allow_input := true

@onready var aim_indicator: Line2D = %AimIndicator
@onready var hitting_area: HittingArea = %HittingArea

func _process(delta: float) -> void:
	if not allow_input:
		aim_indicator.scale = lerp(aim_indicator.scale, Vector2.ZERO, 10 * delta)
		return
	
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	current_display = lerp(current_display, input, 20 * delta)
	aim_indicator.rotation = current_display.angle()
	aim_indicator.scale = Vector2.ONE * current_display.length()

func attack() -> void:
	hitting_area.long_hit(INF)
	allow_input = false
