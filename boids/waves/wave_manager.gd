extends Node

# summons a new wave of boids when all boids are dead

const wave_interval: float = 1.0

var timer: Timer = null
var curr_wave: int = 0
var number_of_waves: int = 0

func _ready() -> void:
	assert(get_child_count() > 0, "wave manager has no waves")
	
	number_of_waves = get_child_count()
	
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_timeout)
	timer.one_shot = false
	
	Globals.game_started.connect(_on_game_start)

func _physics_process(delta: float) -> void:
	if SwarmOverlord.instance.are_boids_present() or timer.time_left >= 0.0:
		return
	
	timer.start(wave_interval)

func _on_game_start() -> void:
	timer.start(wave_interval)

func _on_timeout() -> void:
	print("boid count: ", SwarmOverlord.instance.boid_objects.size())
	if SwarmOverlord.instance.are_boids_present():
		return
	
	print("spawning wave ", curr_wave, " ", number_of_waves)
	
	var wave: Wave = get_children()[curr_wave]
	wave.spawn_all()
	
	curr_wave = min(curr_wave + 1, number_of_waves - 1)
	print("curr wave is now ", curr_wave)
