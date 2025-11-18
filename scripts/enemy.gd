extends RigidBody2D

enum SteeringAlgorithm {
	SEEK,
	ARRIVE,
	WANDER
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.ARRIVE
@export var max_speed = 100.0
@export var rotation_speed = 8.0

@export_group("Arrive Settings")
@export var inner_radius = 28.0
@export var outer_radius = 100.0
@export var time_to_target = 0.8

@export_group("Wander Settings")
@export var max_rotation = 2.0
@export var min_rotation = 0.5 
@export var max_rotation_limit = 3.0 
@export var wander_min_turn_angle = deg_to_rad(45) 
@export var wander_max_turn_angle = deg_to_rad(90)

var target: Node2D = null
var is_touching_player = false

var steering_behavior = null

class KinematicSteering:
	var owner_node: Node2D
	var target: Node2D
	var max_speed: float
	
	func _init(owner: Node2D, tgt: Node2D, spd: float):
		owner_node = owner
		target = tgt
		max_speed = spd
	
	func calculate_steering() -> Vector2:
		return Vector2.ZERO

class KinematicSeek extends KinematicSteering:
	func _init(owner: Node2D, tgt: Node2D, spd: float):
		super(owner, tgt, spd)
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
			
		var direction = target.global_position - owner_node.global_position
		if direction.length() > 0:
			direction = direction.normalized()
		
		var velocity = direction * max_speed
		return velocity

class KinematicArrive extends KinematicSteering:
	var inner_radius: float
	var outer_radius: float
	var time_to_target: float
	var is_touching_player: bool
	
	func _init(owner: Node2D, tgt: Node2D, spd: float, inner_r: float, outer_r: float, ttt: float):
		super(owner, tgt, spd)
		inner_radius = inner_r
		outer_radius = outer_r
		time_to_target = ttt
		is_touching_player = false
	
	func set_touching_player(touching: bool):
		is_touching_player = touching
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
			
		var direction = target.global_position - owner_node.global_position
		var distance = direction.length()
		
		if distance < inner_radius or is_touching_player:
			return Vector2.ZERO
		
		if distance > outer_radius:
			direction = direction.normalized()
			return direction * max_speed
			
		var target_speed = distance / time_to_target
		target_speed = min(target_speed, max_speed)
		
		direction = direction.normalized()
		var velocity = direction * target_speed
		
		return velocity

class KinematicWander extends KinematicSteering:
	var wander_orientation: float = 0.0
	var wander_target_orientation: float = 0.0
	var min_rotation: float
	var max_rotation_limit: float
	var wander_min_turn_angle: float
	var wander_max_turn_angle: float
	var rotation_timer: Timer
	
	func _init(owner: Node2D, tgt: Node2D, spd: float, min_rot: float, max_rot_limit: float, 
			   min_turn: float, max_turn: float, timer: Timer):
		super(owner, tgt, spd)
		min_rotation = min_rot
		max_rotation_limit = max_rot_limit
		wander_min_turn_angle = min_turn
		wander_max_turn_angle = max_turn
		rotation_timer = timer
		
		rotation_timer.timeout.connect(_on_rotation_timer_timeout)
		_start_new_wander_timer()
	
	func calculate_steering() -> Vector2:
		wander_orientation = lerp_angle(wander_orientation, wander_target_orientation, 0.05)
		owner_node.rotation = wander_orientation
		var velocity = Vector2.RIGHT.rotated(owner_node.rotation) * max_speed
		return velocity
	
	func _start_new_wander_timer():
		var interval = randf_range(0.5, 1)
		rotation_timer.start(interval)
	
	func _on_rotation_timer_timeout():
		var turn_angle = randf_range(wander_min_turn_angle, wander_max_turn_angle)
		if randf() < 0.5:
			turn_angle *= -1
		wander_target_orientation = wrapf(wander_orientation + turn_angle, -PI, PI)
		_start_new_wander_timer()

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0] 
		
		target.enemy_entered.connect(_on_player_touched)
		target.enemy_exited.connect(_on_player_fled)
	
	lock_rotation = false
	_initialize_steering_behavior()

func _initialize_steering_behavior():
	match algorithm:
		SteeringAlgorithm.SEEK:
			steering_behavior = KinematicSeek.new(self, target, max_speed)
		SteeringAlgorithm.ARRIVE:
			steering_behavior = KinematicArrive.new(self, target, max_speed, 
													inner_radius, outer_radius, time_to_target)
		SteeringAlgorithm.WANDER:
			steering_behavior = KinematicWander.new(self, target, max_speed, 
													min_rotation, max_rotation_limit,
													wander_min_turn_angle, wander_max_turn_angle,
													$RotationTimer)

func _physics_process(delta):
	if not steering_behavior:
		return
		
	var steering_velocity = steering_behavior.calculate_steering()
	linear_velocity = steering_velocity
	
	if algorithm != SteeringAlgorithm.WANDER and steering_velocity.length() > 0:
		var target_rotation = steering_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func _on_player_touched():
	is_touching_player = true
	if steering_behavior is KinematicArrive:
		steering_behavior.set_touching_player(true)

func _on_player_fled():
	is_touching_player = false
	if steering_behavior is KinematicArrive:
		steering_behavior.set_touching_player(false)
