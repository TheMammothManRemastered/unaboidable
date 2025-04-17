extends Node

# summons a new wave of boids when all boids are dead

const wave_interval: float = 1.0

var timer: Timer = null
var curr_wave: int = 0

func _ready() -> void:
	assert(get_child_count() > 0, "wave manager has no waves")
	
	timer = Timer.new()
	timer.timeout.connect(_on_timeout)
	timer.one_shot = false
	timer.start(wave_interval)

func _on_timeout() -> void:
	if SwarmOverlord.instance.are_boids_present():
		timer.start(wave_interval)
		return
	
	var wave: Wave = get_children()[curr_wave]
	wave.spawn_all()
	
	curr_wave = min(curr_wave + 1, get_child_count() - 1)
	timer.start(wave_interval)
