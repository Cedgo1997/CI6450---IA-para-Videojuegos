extends RigidBody2D

enum SteeringAlgorithm {
	SEEK,
	ARRIVE,
	WANDER
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.ARRIVE
@export var max_speed = 200.0
@export var rotation_speed = 8.0

@export_group("Arrive Settings")
@export var inner_radius = 28.0
@export var outer_radius = 100.0
@export var time_to_target = 0.8

@export_group("Wander Settings")
@export var max_rotation = 2.0
@export var min_rotation = 0.5 # Rango mínimo para variación
@export var max_rotation_limit = 3.0 # Rango máximo para variación
# Estos valores definen qué tan drástica será la rotación
@export var wander_min_turn_angle = deg_to_rad(45) # mínimo de grads de diferencia
@export var wander_max_turn_angle = deg_to_rad(90) # máximo de grados de diferencia

var wander_orientation = 0.0
var wander_target_orientation = 0.0

var target: Node2D = null
var is_touching_player = false
	
func _ready():
	# Buscar al jugador en la escena
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0] 
		
		target.enemy_entered.connect(_on_player_touched)
		target.enemy_exited.connect(_on_player_fled)
	# Configurar el RigidBody2D para control manual
	lock_rotation = false
	_start_new_wander_timer()

func _physics_process(delta):
	if target == null:
		return
	
	var steering_velocity = Vector2.ZERO
		
	match algorithm:
		SteeringAlgorithm.SEEK:
			if target:
				steering_velocity = kinematic_seek()
		SteeringAlgorithm.ARRIVE:
			if target:
				steering_velocity = kinematic_arrive()
		SteeringAlgorithm.WANDER:
			steering_velocity = kinematic_wander()
		
	linear_velocity = steering_velocity
		
	if steering_velocity.length() > 0:
		var target_rotation = steering_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
			
func kinematic_seek() -> Vector2:
	var direction = target.global_position - global_position
	if direction.length() > 0:
		direction = direction.normalized()
		
	var velocity = direction * max_speed
	return velocity

func kinematic_arrive() -> Vector2:
	var direction = target.global_position - global_position
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
	
func kinematic_wander() -> Vector2:
	wander_orientation = lerp_angle(wander_orientation, wander_target_orientation, 0.05)
	rotation = wander_orientation
	var velocity = Vector2.RIGHT.rotated(rotation) * max_speed
	return velocity

func random_binomial() -> float:
	return randf() - randf()

func _on_player_touched():
	is_touching_player = true
	pass

# Función que se ejecuta cuando el player emite la señal "enemy_exited"
func _on_player_fled():
	is_touching_player = false
	pass

func _start_new_wander_timer():
	var interval = randf_range(0.5, 1)
	$RotationTimer.start(interval)

func _on_rotation_timer_timeout() -> void:
	max_rotation = randf_range(min_rotation, max_rotation_limit)
	var turn_angle = randf_range(wander_min_turn_angle, wander_max_turn_angle)
	if randf() < 0.5:
		turn_angle *= -1  # a veces hacia la izquierda, a veces hacia la derecha

	wander_target_orientation = wrapf(wander_orientation + turn_angle, -PI, PI)
	_start_new_wander_timer()
