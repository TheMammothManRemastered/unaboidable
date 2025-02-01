extends Node2D
class_name SwarmOverlord

# this synchronizes a number of SwarmBrains' compute shaders and calculations
# NOTE: there should only ever be one of these in a scene

var frame_count: int = 0
var frames_per_swarm_synchronization: int = 4

var device: RenderingDevice

func _ready() -> void:
	# glean info from all swarm brains on what they support
	# translate this into parameters for compute shaders
	# and also the shader files themselves
	# make ready the pipeline
	pass

func _physics_process(delta: float) -> void:
	if (frame_count % frames_per_swarm_synchronization):
		# we need to sync the device and send it the next batch of computations
		# since syncing is slow, we do this every X frames
		pass
	
	# tell the brains to update the positions of their boids each frame
	# I may move this to be performed on lesser intervals, anything in the name of performance
	# related, TODO: refactor the boids such that their velocity is stored and applied in the brains
	# this should translate to better performance when it comes to getting data out of the compute
	# shaders. the actual boid objects shouldn't do anything apart from keep track of if they hit the player
	# or, like, a wall, then signal their brain to resolve the collision
	
	# for brain in brains:
	# 	brain.update_boids()
	
	# don't forget to do this :3 or everything breaks :3
	frame_count += 1
