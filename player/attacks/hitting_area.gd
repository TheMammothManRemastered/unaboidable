class_name HittingArea extends Area2D

@export var max_hits: int = 1000

var things_hit := 0
var long_hit_time := 0.0

func hit() -> void:
	for body in get_overlapping_bodies():
		if things_hit >= max_hits: break
		
		things_hit += 1
		print("hit! things_hit = ", things_hit)
		body.hurt()
	
	visible = true

func long_hit(seconds: float) -> void:
	long_hit_time = seconds
	things_hit = 0
	
func stop_hit() -> void:
	long_hit_time = 0.0

func _process(delta: float) -> void:
	if long_hit_time == 0:
		visible = false
	
	if long_hit_time > 0: hit()
	long_hit_time = move_toward(long_hit_time, 0, delta)
