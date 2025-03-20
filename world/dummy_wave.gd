extends Timer

func _on_timeout() -> void:
	self.start(1)
	
	if ($SwarmOverlord.boid_objects.size() <= 0):
		$SwarmOverlord.spawn_some_boids(30, Vector2(500, 500))
