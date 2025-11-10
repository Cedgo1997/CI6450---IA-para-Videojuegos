extends RigidBody2D

const EnemyScript = preload("res://enemy.gd")

enum SteeringAlgorithm {
	STEERING_SEEK,
	STEERING_FLEE,
	STEERING_ARRIVE
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.STEERING_SEEK
@export var max_speed = 200.0
@export var max_acceleration = 100.0
@export var rotation_speed = 8.0

@export_group('Arrive Settings')
@export var target_radius = 20.0
@export var slow_radius = 120.0
@export var time_to_target = 0.1

var target: Node2D = null
var current_velocity = Vector2.ZERO
var steering_behavior = null

# ============= STEERING SEEK (Dinámico) =============
class SteeringSeek extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	
	func _init(owner: RigidBody2D, tgt: Node2D, spd: float, max_accel: float):
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

# ============= STEERING FLEE (Dinámico) =============
class SteeringFlee extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	
	func _init(owner: RigidBody2D, tgt: Node2D, spd: float, max_accel: float):
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

# ============= STEERING ARRIVE (Dinámico) =============
class SteeringArrive extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	var target_radius: float
	var slow_radius: float
	var time_to_target: float
	
	func _init(owner: RigidBody2D, tgt: Node2D, spd: float, max_accel: float, 
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
			owner_node.current_velocity = Vector2.ZERO
			return Vector2.ZERO
		
		var target_speed = max_speed
		if distance < slow_radius:
			target_speed = max_speed * (distance / slow_radius)
		
		var target_velocity = direction.normalized() * target_speed
		
		var acceleration = (target_velocity - current_velocity) / time_to_target
		
		if acceleration.length() > max_acceleration:
			acceleration = acceleration.normalized() * max_acceleration
		
		return acceleration

# ============= MÉTODOS PRINCIPALES =============
func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
	
	lock_rotation = false
	linear_damp = 0.5
	
	_initialize_steering_behavior()

func _initialize_steering_behavior():
	match algorithm:
		SteeringAlgorithm.STEERING_SEEK:
			steering_behavior = SteeringSeek.new(self, target, max_speed, max_acceleration)
		SteeringAlgorithm.STEERING_FLEE:
			steering_behavior = SteeringFlee.new(self, target, max_speed, max_acceleration)
		SteeringAlgorithm.STEERING_ARRIVE:
			steering_behavior = SteeringArrive.new(self, target, max_speed, max_acceleration,
												   target_radius, slow_radius, time_to_target)

func _physics_process(delta):
	if target == null or steering_behavior == null:
		return
	
	steering_behavior.set_current_velocity(current_velocity)
	
	var steering_output = steering_behavior.calculate_steering()
	
	current_velocity += steering_output * delta
	
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed
	
	linear_velocity = current_velocity
	
	if current_velocity.length() > 0:
		var target_rotation = current_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
