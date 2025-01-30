extends Node

@export var fps := 12.0

func _ready() -> void:
	Input.flush_buffered_events()
	
	var timer = Timer.new()
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.wait_time = 1.0 / fps
	timer.timeout.connect(run_frame)
	add_child(timer)
	timer.start()
	
	self.process_mode = Node.PROCESS_MODE_DISABLED

func run_frame() -> void:
	process_mode = PROCESS_MODE_INHERIT
	await get_tree().process_frame
	process_mode = PROCESS_MODE_DISABLED
