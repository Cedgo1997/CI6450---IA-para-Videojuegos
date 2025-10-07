extends RigidBody2D

@export var max_speed = 200.0
@export var rotation_speed = 8.0

@export var inner_radius = 28.0
@export var outer_radius = 100.0
@export var time_to_target = 0.8
 
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

func _physics_process(delta):
	if target == null:
		return
	
	if not is_touching_player:
		var steering_velocity = kinematic_arrive()
		linear_velocity = steering_velocity
		
		if steering_velocity.length() > 0:
			var target_rotation = steering_velocity.angle()
			rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	else:
		linear_velocity = Vector2.ZERO
		
func kinematic_seek() -> Vector2:
	# Obtener la dirección hacia el objetivo
	var direction = target.global_position - global_position
	
	# Normalizar y aplicar velocidad máxima
	if direction.length() > 0:
		direction = direction.normalized()
		
	var velocity = direction * max_speed
	return velocity

func kinematic_arrive() -> Vector2:
	var direction = target.global_position - global_position
	var distance = direction.length()
	
	if distance < inner_radius:
		return Vector2.ZERO
	
	if distance > outer_radius:
		direction = direction.normalized()
		return direction * max_speed

	var target_speed = distance / time_to_target
	target_speed = min(target_speed, max_speed)
	
	direction = direction.normalized()
	var velocity = direction * target_speed
	
	return velocity

func _on_player_touched():
	is_touching_player = true
	pass

# Función que se ejecuta cuando el player emite la señal "enemy_exited"
func _on_player_fled():
	is_touching_player = false
	pass
