class_name PlayerCoroutines extends Node2D

const ATTACK_LUNGE_SPEED := 1500.0
const ATTACK_LUNGE_TIME := 0.4

const DIVE_SPEED := 1500.0
const DIVE_LAND_SPEED := 1500.0
const DIVE_MAX_SLIDE_TIME := 0.5

var _buffered_action := ActionType.NONE
var _active_timer: SceneTreeTimer
var _p: Player

var control_lock := false
var gravity_scale := 1.0
var prevent_moves := false
var hurt_override := false
var animation_override := false
var awaiting_hurt_override := false # set by the player on hurt if hurt_override is true

func _init(player: Player):
	_p = player

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("primary"): _buffered_action = ActionType.PRIMARY
	elif event.is_action_pressed("special"): _buffered_action = ActionType.SPECIAL
	elif event.is_action_pressed("jump"): _buffered_action = ActionType.JUMP

func _nearest_homing_targets(max_distance: float) -> Array[Node2D]:
	var boids: Array[Node2D]
	boids.assign(get_tree().get_nodes_in_group("boids"))
	if boids.is_empty(): return []
	boids.sort_custom(func(a, b): return _p.global_position.distance_to(a.global_position) < _p.global_position.distance_to(b.global_position))
	return boids.filter(func(a): return _p.global_position.distance_to(a.global_position) <= max_distance)
	return boids

func _lowest_arc_homing_targets(direction: Vector2, max_distance: float) -> Array[Node2D]:
	var boids: Array[Node2D]
	boids.assign(get_tree().get_nodes_in_group("boids"))
	if boids.is_empty(): return []
	boids.sort_custom(func(a, b):
		return angle_difference(direction.angle(), _p.global_position.angle_to(a.global_position))\
		< angle_difference(direction.angle(), _p.global_position.angle_to(a.global_position))
	)
	return boids.filter(func(a): return _p.global_position.distance_to(a.global_position) <= max_distance)

func _timer_step(seconds: float) -> bool:
	if _active_timer == null:
		_active_timer = get_tree().create_timer(seconds, false)
		return true
	else:
		await get_tree().process_frame
		if _active_timer.time_left == 0:
			_active_timer = null
			return false
		else:
			return true

func _set_player_position(position: Vector2) -> void:
	_p.move_and_collide(position - _p.position)

func main_attack() -> void:
	const MAX_HOME_DISTANCE := 500.0
	const SPEED_PER_PX := 200.0
	const LUNGE_DISTANCE := 300.0
	const HOMING_EXTRA_DISTANCE := 40.0
	const DECEL_TIME := 0.3
	const FIXED_TIME := 0.2
	
	control_lock = true
	
	animation_override = true
	_p.player_sprite.play("punch")
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var distance = LUNGE_DISTANCE
	if direction == Vector2.ZERO:
		var homing_targets = _nearest_homing_targets(MAX_HOME_DISTANCE)
		if not homing_targets.is_empty():
			direction = _p.global_position.direction_to(homing_targets[0].global_position)
			distance = _p.global_position.distance_to(homing_targets[0].global_position) + HOMING_EXTRA_DISTANCE
		else:
			direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	_p.velocity = Vector2.ZERO
	if direction.x != 0: _p.facing_direction = sign(direction.x)
	
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
	t.tween_method(_set_player_position, _p.position, _p.position + direction * distance, DECEL_TIME)
	
	_p.dash_attack.long_hit(DECEL_TIME)
	await _timer(FIXED_TIME)
	
	t.kill()
	queue_free()

func dive_attack() -> void:
	gravity_scale = 0.0
	
	var lr = Input.get_axis("move_left", "move_right")
	var direction = Vector2(lr, 2)
	_p.velocity = direction * DIVE_SPEED
	
	while not _p.is_on_floor():
		await get_tree().process_frame
		_p.velocity.x = lr * DIVE_LAND_SPEED
		_p.dash_attack.hit()
		
	
	var slide_time = 0.0
	while Input.is_action_pressed("move_down") and slide_time < DIVE_MAX_SLIDE_TIME and _p.velocity.x != 0:
		_p.velocity.x = lr * DIVE_LAND_SPEED
		await get_tree().process_frame
		slide_time += get_process_delta_time()
		_p.dash_attack.hit()
	
	queue_free()

func special_attack() -> void:
	const CHARGE_TIME := .3
	print("Special Attack")
	
	control_lock = true
	hurt_override = true
	_p.velocity = Vector2.ZERO
	
	animation_override = true
	_p.player_sprite.play("dash_charge")
	
	var attack: ChargedDashAttack = load("res://player/attacks/charged_dash/charged_dash_attack.tscn").instantiate()
	add_child(attack)
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	while await _timer_step(CHARGE_TIME):
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input != Vector2.ZERO: direction = input.normalized()
	
	if direction.x != 0: _p.facing_direction = sign(direction.x)
	
	if direction.y > .2:
		_p.new_coroutine().dive_attack()
	else:
		const ATK_DURATION := 0.3
		const SWING_COUNT := 4
		const SWING_INTERVAL := 0.1
		const SWING_DISTANCE := 190
		attack.attack()
		for i in range(SWING_COUNT):
			if i != 0: await _timer(SWING_INTERVAL)
			
			_p.move_and_collide(direction * SWING_DISTANCE)
			
			var slice = preload("res://player/sprites/slices/slice.tscn").instantiate()
			slice.index = i
			slice.direction = direction
			slice.position = _p.get_parent().to_local(_p.global_position)
			_p.add_sibling(slice)
		
		const END_SPEED_X = 450
		const END_SPEED_Y = 1200
		_p.velocity.x = direction.x * END_SPEED_X
		_p.velocity.y = direction.y * END_SPEED_Y
	
	print("attacking!")
	
	queue_free()

func special_perry() -> void:
	pass
	#print("perry!")
	#_p.perry_attack.hit()

func special_knives() -> void:
	#const MAX_DIST := 1000.0
	print("knives!")
	#var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#input.
	#var targets = _nearest_homing_targets()
	#pass

#func special_chain_throw() -> void:
	#const MAX_CHAIN_DISTANCE := 1000.0
	#const GRAPPLE_SPEED := 600.0
	#const GRAPPLE_ACCEL := 5000.0
	#const GRAPPLE_RELEASE_SPEED := 1800.0
	#print("Special Chain Throw")
	#
	#control_lock = false
	#prevent_moves = true
	#
	#var chained = _nearest_homing_target(MAX_CHAIN_DISTANCE)
	#
	#while chained != null:
		#var grapple_dir = _p.global_position.direction_to(chained.global_position)
		#_p.velocity = _p.velocity.move_toward(grapple_dir * GRAPPLE_SPEED, GRAPPLE_ACCEL * get_process_delta_time())
		#
		#if not Input.is_action_pressed("special"): # release grapple
			#_p.velocity = grapple_dir * GRAPPLE_RELEASE_SPEED
			#break
		#
		#await get_tree().process_frame
	#
	#queue_free()

func _timer(seconds: float):
	await get_tree().create_timer(seconds, false).timeout

enum ActionType {
	NONE,
	PRIMARY,
	SPECIAL,
	JUMP,
}
