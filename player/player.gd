extends CharacterBody2D

##- Constants -##
const ACCEL := 4000.0
const MAX_WALK := 750.0
const GROUND_DECEL := 6000.0
const AIR_DECEL := 4000.0

const GRAVITY_FAST   := 4080.0
const GRAVITY_NORMAL := 2800.0

const JUMP_MIN := 200.0
const JUMP_MAX := 1300.0
const JUMP_MAX_CHARGE_TIME := 0.3

const SQUASH_FACTOR := 3000

##- Instance Variables -##
var jump_charge_time := 0.0
var squish = 1.0
var delayed_squish = squish
var facing_direction := +1 ## -1 if facing left, +1 if facing right

##- Nodes -##
@onready var visuals: Node2D = $Visuals
@onready var jump_particles: CPUParticles2D = $Node/CanvasGroup/JumpParticles

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		var gravity = GRAVITY_FAST if Input.is_action_pressed("move_down") else GRAVITY_NORMAL
		velocity.y += gravity * delta

	# Handle jump.
	# 	- jump release
	if Input.is_action_just_released("jump") and is_on_floor():
		var jump_progress = min(jump_charge_time / JUMP_MAX_CHARGE_TIME, 1.0)
		var jump_force = lerp(JUMP_MIN, JUMP_MAX, jump_progress)
		velocity.y = -jump_force
		jump_particles.global_position = self.global_position
		jump_particles.restart()
	
	# 	- jump charge
	if Input.is_action_pressed("jump") and is_on_floor():
		jump_charge_time += delta
		var jump_progress = min(jump_charge_time / JUMP_MAX_CHARGE_TIME, 1.0)
		squish = lerp(1.0, 0.7, jump_progress)
	else:
		jump_charge_time = 0.0
		if is_on_floor(): squish = 1.0

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		# instant reverse
		if is_on_floor() and not Input.is_action_pressed("jump"):
			if sign(velocity.x) != sign(direction): velocity.x *= -1
		
		velocity.x = move_toward(velocity.x, direction * MAX_WALK, ACCEL * delta)
	else:
		var decel = GROUND_DECEL if is_on_floor() else AIR_DECEL
		velocity.x = move_toward(velocity.x, 0, decel * delta)
	
	# facing direction
	if is_on_floor():
		if velocity.x < 0: facing_direction = -1
		elif velocity.x > 0: facing_direction = +1
	
	# squash and stretch
	if not is_on_floor():
		squish = 1 + abs(velocity.y) / 3000
	
	delayed_squish = move_toward(delayed_squish, squish, 5.0 * delta)
	
	visuals.scale.y = delayed_squish
	visuals.scale.x = 1 / delayed_squish
	visuals.scale.x *= facing_direction

	move_and_slide()
