class_name HittingArea extends Area2D

var long_hit_time := 0.0

func hit() -> void:
	print("hitting")
	for body in get_overlapping_bodies():
		print("hitting_area: hit `%s`" % body)
		body.hurt()
	
	visible = true

func long_hit(seconds: float) -> void:
	long_hit_time = seconds
	
func stop_hit(seconds: float) -> void:
	long_hit_time = 0.0

func _process(delta: float) -> void:
	if long_hit_time == 0: visible = false
	
	if long_hit_time > 0: hit()
	long_hit_time = move_toward(long_hit_time, 0, delta)
