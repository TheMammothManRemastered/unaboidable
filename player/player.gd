class_name Player extends CharacterBody2D

##- Constants -##
const ACCEL := 4000.0
const MAX_WALK := 750.0
const GROUND_DECEL := 6000.0
const AIR_DECEL := 4000.0
const JUMP_CHARGE_NORMAL_DECEL := 4000.0
const JUMP_CHARGE_SLOW_DECEL := 1200.0

const GRAVITY_FAST   := 4080.0
const GRAVITY_NORMAL := 2800.0

const JUMP_MIN := 200.0
const JUMP_MAX := 1300.0
const JUMP_MAX_CHARGE_TIME := 0.3

const SQUASH_FACTOR := 3000

const WALL_CLING_SPEED := 50.0
const WALL_CLING_DECEL := 10000.0
const WALL_SKID_DECEL := 7000.0
const WALL_SKID_SPEED := 300.0
const WALL_JUMP_SPEED := Vector2(800.0, 1000.0)

##- Instance Variables -##
var jump_charge_time := 0.0
var squish = 1.0
var delayed_squish = squish
var facing_direction := +1 ## -1 if facing left, +1 if facing right
var time_on_floor := 0.0
var active_coroutine: PlayerCoroutines

##- Nodes -##
@onready var visuals: Node2D = %Visuals
@onready var jump_particles: CPUParticles2D = %JumpParticles
@onready var player_sprite: AnimatedSprite2D = %PlayerSprite
@onready var wall_jump_particles: CPUParticles2D = %WallJumpParticles
@onready var left_wall_area: Area2D = %LeftWallArea
@onready var right_wall_area: Area2D = %RightWallArea

@onready var dash_attack: HittingArea = %DashAttack

static var instance: Player

func _init() -> void:
	instance = self

func _process(delta: float) -> void:
	if not control_locked():
		movement_update(delta)
		walljump_update(delta)
	
	# facing direction
	if is_on_floor():
		if velocity.x < 0: facing_direction = -1
		elif velocity.x > 0: facing_direction = +1
	
	# attacks
	if not moves_prevented():
		if Input.is_action_just_pressed("primary"):
			if Input.is_action_pressed("move_down"):
				new_coroutine().dive_attack()
			else:
				new_coroutine().main_attack()
		elif Input.is_action_just_pressed("special"):
			new_coroutine().special_attack()
	
	# set current AnimatedSprite2D animation
	set_animation()
	
	# squash and stretch
	if not is_on_floor():
		squish = 1 + abs(velocity.y) / 3000
	else:
		if squish > 1.0:
			squish = 1.0 / squish
		else:
			squish = move_toward(squish, 1.0, delta)
	
	delayed_squish = lerp(delayed_squish, squish, 1 - exp(-15 * delta))
	#delayed_squish = move_toward(delayed_squish, squish, 5.0 * delta)
	
	visuals.scale.y = delayed_squish
	visuals.scale.x = 1 / delayed_squish
	visuals.scale.x *= facing_direction

	# time on floor
	if is_on_floor(): time_on_floor += delta
	else: time_on_floor = 0.0

	# finalize
	move_and_slide()

func movement_update(delta: float) -> void:
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
		jump_particles.restart()
	
	# 	- jump charge
	var is_charging_jump = Input.is_action_pressed("jump") and is_on_floor()
	if is_charging_jump:
		jump_charge_time += delta
		var jump_progress = min(jump_charge_time / JUMP_MAX_CHARGE_TIME, 1.0)
		squish = lerp(1.0, 0.7, jump_progress)
	else:
		jump_charge_time = 0.0

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	if is_charging_jump:
		var inputting_forwards = sign(direction) == sign(velocity.x)
		var decel = JUMP_CHARGE_SLOW_DECEL if inputting_forwards else JUMP_CHARGE_NORMAL_DECEL
		velocity.x = move_toward(velocity.x, 0, decel * delta)
	elif direction != 0 and not is_charging_jump:
		# instant reverse
		if is_on_floor():
			if sign(velocity.x) != sign(direction): velocity.x *= -1
		
		velocity.x = move_toward(velocity.x, direction * MAX_WALK, ACCEL * delta)
	else:
		var decel = GROUND_DECEL if is_on_floor() else AIR_DECEL
		velocity.x = move_toward(velocity.x, 0, decel * delta)


func walljump_update(delta: float) -> void:
	if not is_on_floor():
		var  left_wall =  left_wall_area.has_overlapping_bodies()
		var right_wall = right_wall_area.has_overlapping_bodies()
		if left_wall or right_wall:
			var clinging = Input.is_action_pressed("move_left" if left_wall else "move_right")
			var normal = +1 if left_wall else -1
			
			facing_direction = normal
			
			var min_fall = WALL_CLING_SPEED if clinging else WALL_SKID_SPEED
			var decel = WALL_CLING_DECEL if clinging else WALL_SKID_DECEL
			if velocity.y > min_fall:
				velocity.y = move_toward(velocity.y, min_fall, decel * delta)
			
			if Input.is_action_just_pressed("jump"):
				wall_jump(normal)

func set_animation() -> void:
	if is_animation_overriding(): return
	
	var on_wall = left_wall_area.has_overlapping_bodies() or right_wall_area.has_overlapping_bodies()
	
	if is_on_floor():
		if Input.is_action_pressed("jump"):
			player_sprite.play("crouch")
			player_sprite.frame = 0 if jump_charge_time < JUMP_MAX_CHARGE_TIME else 1
		elif abs(velocity.x) > 0:
			player_sprite.play("run")
		else:
			player_sprite.play("idle")
	else:
		if on_wall:
			player_sprite.play("wall")
		else:
			player_sprite.animation = "jump"
			if velocity.y < -500: player_sprite.frame = 0
			elif velocity.y < -200: player_sprite.frame = 1
			elif velocity.y < 200: player_sprite.frame = 2
			elif velocity.y < 500: player_sprite.frame = 3
			else: player_sprite.frame = 4

func wall_jump(normal: int) -> void:
	velocity.x = WALL_JUMP_SPEED.x * normal
	if velocity.y > 0: velocity.y = 0
	velocity.y -= WALL_JUMP_SPEED.y
	
	wall_jump_particles.scale.x = normal
	wall_jump_particles.restart()

func hurt(damage: int = 1) -> void:
	print("player was hurt!")
	
	if active_coroutine != null and active_coroutine.hurt_override != null:
		active_coroutine.awaiting_hurt_override
		return
	
	print("ouch!")

func new_coroutine() -> PlayerCoroutines:
	if active_coroutine != null:
		active_coroutine.queue_free()
	
	var co = PlayerCoroutines.new(self)
	add_child(co)
	active_coroutine = co
	return co

func control_locked() -> bool:
	if active_coroutine == null: return false
	else: return active_coroutine.control_lock

func moves_prevented() -> bool:
	if active_coroutine == null: return false
	else: return active_coroutine.prevent_moves or active_coroutine.control_lock

func gravity_scale() -> float:
	if active_coroutine == null: return 1.0
	else: return active_coroutine.gravity_scale

func is_animation_overriding() -> bool:
	if active_coroutine == null: return false
	else: return active_coroutine.animation_override
