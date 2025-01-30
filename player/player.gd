extends CharacterBody2D

const ACCEL := 7000.0
const MAX_WALK := 750.0
const GROUND_DECEL := 6000.0
const AIR_DECEL := 4000.0
const GRAVITY_FAST   := 4080.0
const GRAVITY_NORMAL := 2800.0
const GRAVITY_SLOW   := 1600.0
const JUMP_VELOCITY := -900.0
const SQUASH_FACTOR := 3000

@onready var visuals: Node2D = $Visuals

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		var gravity
		if Input.is_action_pressed("jump"):
			gravity = GRAVITY_SLOW
		elif Input.is_action_pressed("move_down"):
			gravity = GRAVITY_FAST
		else: gravity = GRAVITY_NORMAL
		
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jump()

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		if is_on_floor() and sign(velocity.x) != sign(direction): velocity.x *= -1
		velocity.x = move_toward(velocity.x, direction * MAX_WALK, ACCEL * delta)
	else:
		var decel = GROUND_DECEL if is_on_floor() else AIR_DECEL
		velocity.x = move_toward(velocity.x, 0, decel * delta)
		
	# squash and stretch
	if abs(velocity.y) > abs(velocity.x):
		visuals.scale.y = 1 + abs(velocity.y - velocity.x) / SQUASH_FACTOR
		visuals.scale.x = 1.0 / visuals.scale.y
	else:
		visuals.scale.x = 1 + abs(velocity.x - velocity.y) / SQUASH_FACTOR
		visuals.scale.y = 1.0 / visuals.scale.x

	move_and_slide()

func jump() -> void:
	velocity.y = JUMP_VELOCITY
