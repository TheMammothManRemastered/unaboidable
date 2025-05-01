class_name WaveDisplay extends CanvasLayer

@onready var label: Label = %Label

static var instance: WaveDisplay

func _init() -> void:
	instance = self

func _ready() -> void:
	label.modulate.a = 0.0

func display_wave(wave_num: int) -> void:
	label.text = "WAVE "
	label.modulate.a = 1.0
	
	await get_tree().create_timer(.33, false).timeout
	
	label.text = "WAVE %s" % wave_num
	
	await get_tree().create_timer(.66, false).timeout
	
	label.text = "FIGHT!"
	label.modulate.a = 1.0
	
	await create_tween().tween_property(label, "modulate:a", 0.0, 0.66).finished
