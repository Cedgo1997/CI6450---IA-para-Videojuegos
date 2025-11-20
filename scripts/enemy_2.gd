extends CharacterBody2D

const EnemyScript = preload("res://scripts/enemy.gd")
const EnemyEnums = preload("res://scripts/enums/enemy_enums.gd")

@export var algorithm: EnemyEnums.DynamicAlgorithm = EnemyEnums.DynamicAlgorithm.STEERING_SEEK
@export var max_speed = 200.0
@export var max_acceleration = 100.0
@export var rotation_speed = 8.0

@export_group('Arrive Settings')
@export var target_radius = 20.0
@export var slow_radius = 120.0
@export var time_to_target = 0.1

@export_group('Obstacle Avoidance')
@export var enable_obstacle_avoidance: bool = true
@export var lookahead_distance: float = 150.0
@export var avoid_distance: float = 50.0

var target: Node2D = null
var current_velocity = Vector2.ZERO
var steering_behavior = null

class SteeringSeek extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	
	func _init(owner: CharacterBody2D, tgt: Node2D, spd: float, max_accel: float):
		super(owner, tgt, spd)
		max_acceleration = max_accel
		current_velocity = Vector2.ZERO
	
	func set_current_velocity(vel: Vector2):
		current_velocity = vel
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
		
		var result = target.global_position - owner_node.global_position
		
		if result.length() > 0:
			result = result.normalized()
		
		result *= max_acceleration
		
		return result

class SteeringFlee extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	
	func _init(owner: CharacterBody2D, tgt: Node2D, spd: float, max_accel: float):
		super(owner, tgt, spd)
		max_acceleration = max_accel
		current_velocity = Vector2.ZERO
	
	func set_current_velocity(vel: Vector2):
		current_velocity = vel
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
		
		var result = owner_node.global_position - target.global_position
		
		if result.length() > 0:
			result = result.normalized()
		
		result *= max_acceleration
		
		return result

class SteeringArrive extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	var target_radius: float
	var slow_radius: float
	var time_to_target: float
	
	func _init(owner: CharacterBody2D, tgt: Node2D, spd: float, max_accel: float, 
			   tgt_radius: float, slw_radius: float, ttt: float):
		super(owner, tgt, spd)
		max_acceleration = max_accel
		current_velocity = Vector2.ZERO
		target_radius = tgt_radius
		slow_radius = slw_radius
		time_to_target = ttt
	
	func set_current_velocity(vel: Vector2):
		current_velocity = vel
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
		
		var direction = target.global_position - owner_node.global_position
		var distance = direction.length()
		
		if distance < target_radius:
			current_velocity = Vector2.ZERO
			return Vector2.ZERO
		
		var target_speed = max_speed
		if distance < slow_radius:
			target_speed = max_speed * (distance / slow_radius)
		
		var target_velocity = direction.normalized() * target_speed
		
		var acceleration = (target_velocity - current_velocity) / time_to_target
		
		if acceleration.length() > max_acceleration:
			acceleration = acceleration.normalized() * max_acceleration
		
		return acceleration

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
	
	_initialize_steering_behavior()

func _initialize_steering_behavior():
	if target == null:
		return
	
	var speed_val: float = 200.0
	if max_speed != null:
		speed_val = max_speed as float
	
	var accel_val: float = 100.0
	if max_acceleration != null:
		accel_val = max_acceleration as float
	
	match algorithm:
		EnemyEnums.DynamicAlgorithm.STEERING_SEEK:
			steering_behavior = SteeringSeek.new(self, target, speed_val, accel_val)
		EnemyEnums.DynamicAlgorithm.STEERING_FLEE:
			steering_behavior = SteeringFlee.new(self, target, speed_val, accel_val)
		EnemyEnums.DynamicAlgorithm.STEERING_ARRIVE:
			var tgt_radius_val: float = 20.0
			if target_radius != null:
				tgt_radius_val = target_radius as float
			
			var slw_radius_val: float = 120.0
			if slow_radius != null:
				slw_radius_val = slow_radius as float
			
			var ttt_val: float = 0.1
			if time_to_target != null:
				ttt_val = time_to_target as float
			
			steering_behavior = SteeringArrive.new(self, target, speed_val, accel_val,
												   tgt_radius_val, slw_radius_val, ttt_val)

func _physics_process(delta):
	if target == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
			_initialize_steering_behavior()
		return
	
	if steering_behavior == null:
		_initialize_steering_behavior()
		if steering_behavior == null:
			return
	
	steering_behavior.set_current_velocity(current_velocity)
	
	var steering_output = Vector2.ZERO
	
	if enable_obstacle_avoidance:
		var avoidance_force = get_obstacle_avoidance_force()
		if avoidance_force.length() > 0:
			steering_output = avoidance_force
		else:
			steering_output = steering_behavior.calculate_steering()
	else:
		steering_output = steering_behavior.calculate_steering()
	
	current_velocity += steering_output * delta
	
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed
	
	velocity = current_velocity
	move_and_slide()
	
	if current_velocity.length() > 0:
		var target_rotation = current_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func get_obstacle_avoidance_force() -> Vector2:
	if current_velocity.length() < 0.1:
		return Vector2.ZERO
	
	var ray_direction = current_velocity.normalized()
	var collision_info = detect_collision_single_ray(ray_direction, lookahead_distance)
	
	if collision_info == null:
		return Vector2.ZERO
	
	var distance_to_collision = global_position.distance_to(collision_info.position)
	var urgency = 1.0 - (distance_to_collision / lookahead_distance)
	urgency = clamp(urgency, 0.0, 1.0)
	
	var avoidance_target = collision_info.position + collision_info.normal * avoid_distance
	var to_target = avoidance_target - global_position
	
	if to_target.length() < 1.0:
		return Vector2.ZERO
	
	var avoidance_force = to_target.normalized() * max_acceleration * (urgency + 0.5)
	
	return avoidance_force

func detect_collision_single_ray(ray_direction: Vector2, ray_length: float):
	var space_state = get_world_2d().direct_space_state
	var ray_end = global_position + ray_direction * ray_length
	
	var query = PhysicsRayQueryParameters2D.create(global_position, ray_end)
	query.exclude = [self]
	query.collision_mask = collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		if collider:
			var is_obstacle = false
			if collider.is_in_group("obstacle"):
				is_obstacle = true
			elif collider is StaticBody2D or collider is RigidBody2D or collider is CharacterBody2D:
				if not collider.is_in_group("player"):
					is_obstacle = true
			
			if is_obstacle:
				return {
					"position": result.position,
					"normal": result.normal
				}
	
	return null
