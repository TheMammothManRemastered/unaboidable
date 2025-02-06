extends Line2D

@export var frames: Array[Texture]
@export var frames_per_second: float

var current_frame := 0

@onready var timer: Timer = $Timer

func _ready() -> void:
	timer.wait_time = 1 / frames_per_second
	texture = frames[current_frame]

func _on_timer_timeout() -> void:
	current_frame = (current_frame + 1) % frames.size()
	texture = frames[current_frame]
