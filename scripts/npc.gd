extends CharacterBody2D

const EnemyBehavior = preload("res://scripts/enemy_behavior.gd")
const NPCEnums = preload("res://scripts/enums/npc_enums.gd")
const BulletScene = preload("res://scenes/bullet.tscn")
const TacticalGraph = preload("res://Tactics/tactical_graph.gd")
const TacticalLocation = preload("res://Tactics/tactical_location.gd")

@onready var item_detector = $SightArea
var navigation_agent_2d: NavigationAgent2D = null

@export var max_speed: float = 200.0
@export var max_acceleration: float = 100.0
@export var rotation_speed: float = 8.0

@export_group('Role Settings')
@export var role: NPCEnums.Role = NPCEnums.Role.PATROLMAN

@export_group('Shooting Settings')
@export var shoot_interval: float = 0.5
@export var can_shoot: bool = true
@export var bullet_speed: float = 2000.0

@export_group('Follower Settings')
@export var following_duration: float = 5.0

@export_group('Path Following Settings')
@export var path_offset: float = 5.0
@export var pathGroup: String = "npc_path"
@export var patrol_path: Path2D = null

@export_group('Tactical Pathfinding')
@export var tactical_weights: Dictionary = {
	"cobertura": 0.3,
	"visibilidad": 0.2,
	"altura": 0.1,
	"peligro": -0.5
}
@export var tactical_influence_factor: float = 50.0 ## Factor de influencia táctica. 
	# Pesos positivos (ej: cobertura) hacen que el nodo sea más atractivo (reducen el costo)
	# Pesos negativos (ej: peligro) hacen que el nodo sea menos atractivo (aumentan el costo)
@export var tactical_graph_path: NodePath = NodePath("../../TacticalGraph")
@export var path_recalculate_interval: float = 0.5

var target_apple = null
var apples_in_range = []

var current_state: NPCEnums.State = NPCEnums.State.PATROL
var previous_state: NPCEnums.State = NPCEnums.State.PATROL
var player: CharacterBody2D = null
var path_wrapper: Path = null
var follow_path_behavior: FollowPath = null
var current_velocity: Vector2 = Vector2.ZERO
var current_param: float = 0.0
var face_behavior: EnemyBehavior.RotationalBehavior = null
var current_angular_velocity: float = 0.0
var player_in_sight: bool = false
var apple_seek_behavior: SteeringSeek = null
var apple_virtual_target: Node2D = null
var shoot_timer: float = 0.0
var following_timer: float = 0.0

var tactical_graph: Node = null
var tactical_path: Array[Vector2] = []
var current_path_index: int = 0
var path_recalculate_timer: float = 0.0
var last_target_position: Vector2 = Vector2.ZERO

var viewpoint_target: Node2D = null
var at_viewpoint: bool = false
var fixed_position: Vector2 = Vector2.ZERO
var should_be_immovable: bool = false
var initial_position: Vector2 = Vector2.ZERO
var returning_to_position: bool = false

class Path:
	var path_node: Path2D
	var curve: Curve2D
	var points: Array
	var segment_count: int
	
	func _init(p: Path2D):
		path_node = p
		curve = p.curve
		points = []
		for i in range(curve.point_count):
			points.append(curve.get_point_position(i))
		segment_count = max(1, points.size() - 1)
	
	func getParam(position: Vector2, lastParam: float) -> float:
		if points.size() < 2:
			return 0.0
		
		var local_pos = path_node.to_local(position)
		var closest_segment = 0
		var min_distance = INF
		var search_start = int(lastParam) - 2
		var search_end = int(lastParam) + 2
		
		if lastParam == 0.0:
			search_start = 0
			search_end = segment_count - 1
		
		for i in range(search_start, search_end + 1):
			var seg_index = i % segment_count
			if seg_index < 0:
				seg_index += segment_count
			if seg_index >= segment_count:
				continue
			
			var p1 = points[seg_index]
			var p2 = points[(seg_index + 1) % points.size()]
			var closest_point = _closest_point_on_segment(local_pos, p1, p2)
			var distance = local_pos.distance_to(closest_point)
			
			if distance < min_distance:
				min_distance = distance
				closest_segment = seg_index
		
		return float(closest_segment)
	
	func _closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
		var ab = b - a
		var ap = point - a
		var ab_length_sq = ab.length_squared()
		if ab_length_sq == 0:
			return a
		var t = ap.dot(ab) / ab_length_sq
		t = clamp(t, 0.0, 1.0)
		return a + ab * t
	
	func getPosition(param: float) -> Vector2:
		if points.size() < 2:
			return path_node.global_position
		
		var normalized_param = fmod(param, float(segment_count))
		if normalized_param < 0:
			normalized_param += segment_count
		
		var base_segment = int(normalized_param)
		var t = normalized_param - base_segment
		base_segment = base_segment % segment_count
		var p1 = points[base_segment]
		var p2 = points[(base_segment + 1) % points.size()]
		var local_position = p1.lerp(p2, t)
		return path_node.to_global(local_position)

class SteeringSeek:
	var owner_node: Node2D
	var target: Node2D
	var max_speed: float
	var max_acceleration: float
	
	func _init(owner: Node2D, tgt: Node2D, spd: float, max_accel: float):
		owner_node = owner
		target = tgt
		max_speed = spd
		max_acceleration = max_accel
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
		var result = target.global_position - owner_node.global_position
		if result.length() > 0:
			result = result.normalized()
		result *= max_acceleration
		return result

class FollowPath:
	var character: Node2D
	var path: Path
	var path_offset: float
	var current_param: float
	var seek_behavior: SteeringSeek
	var virtual_target: Node2D
	
	func _init(owner: Node2D, p: Path, offset: float, max_spd: float, max_accel: float):
		character = owner
		path = p
		path_offset = offset
		current_param = 0.0
		virtual_target = Node2D.new()
		character.add_child(virtual_target)
		seek_behavior = SteeringSeek.new(character, virtual_target, max_spd, max_accel)
	
	func getSteering() -> Vector2:
		current_param = path.getParam(character.global_position, current_param)
		var target_param = current_param + path_offset
		var target_position = path.getPosition(target_param)
		
		var distance_to_target = character.global_position.distance_to(target_position)
		if distance_to_target < 5.0:
			current_param += 0.1
		
		virtual_target.global_position = target_position
		return seek_behavior.calculate_steering()
	
	func cleanup():
		if virtual_target:
			virtual_target.queue_free()

func _ready():
	# Guardar posición inicial (especialmente importante para GUARD)
	initial_position = global_position
	
	player = get_tree().get_first_node_in_group("player")
	item_detector.body_entered.connect(_on_apple_detected)
	item_detector.area_entered.connect(_on_apple_detected)
	item_detector.body_exited.connect(_on_apple_lost)
	item_detector.area_exited.connect(_on_apple_lost)
	
	if not patrol_path:
		var paths = get_tree().get_nodes_in_group(pathGroup)
		if paths.size() > 0:
			patrol_path = paths[0]
	
	if patrol_path:
		_initialize_path_following()
	
	face_behavior = EnemyBehavior.RotationalBehavior.new(self, 5.0, 3.0, 0.1, 0.01, 0.5)
	apple_virtual_target = Node2D.new()
	add_child(apple_virtual_target)
	apple_seek_behavior = SteeringSeek.new(self, apple_virtual_target, max_speed, max_acceleration)
	
	var sight_area = get_node_or_null("SightArea")
	if sight_area:
		sight_area.body_entered.connect(_on_sight_body_entered)
		sight_area.body_exited.connect(_on_sight_body_exited)
	
	navigation_agent_2d = get_node_or_null("NavigationAgent2D")
	_initialize_navigation_agent()
	
	if tactical_graph_path:
		tactical_graph = get_node_or_null(tactical_graph_path)
		if not tactical_graph:
			var graphs = get_tree().get_nodes_in_group("tactical_graph")
			if graphs.size() > 0:
				tactical_graph = graphs[0]
	
	# Debug: verificar inicialización del grafo táctico
	if role == NPCEnums.Role.FOLLOWER:
		if tactical_graph:
			print("NPC Follower: Grafo táctico inicializado correctamente")
		else:
			push_warning("NPC Follower: No se encontró el grafo táctico. El pathfinding táctico no funcionará.")
	
	# Inicializar viewpoint para PATROLMAN
	if role == NPCEnums.Role.PATROLMAN:
		var viewpoints = get_tree().get_nodes_in_group("PositionViewpoint1")
		if viewpoints.size() > 0:
			viewpoint_target = viewpoints[0]
		else:
			push_warning("NPC PATROLMAN: No se encontró ningún Node2D en el grupo 'PositionViewpoint1'")

func _initialize_path_following():
	if not patrol_path:
		return
	
	path_wrapper = Path.new(patrol_path)
	follow_path_behavior = FollowPath.new(self, path_wrapper, path_offset, max_speed, max_acceleration)
	
	var closest_param = path_wrapper.getParam(global_position, 0.0)
	follow_path_behavior.current_param = closest_param + 0.5

func _initialize_navigation_agent():
	if navigation_agent_2d:
		navigation_agent_2d.velocity_computed.connect(_on_navigation_agent_2d_velocity_computed)
	else:
		push_warning("No se encontró NavigationAgent2D en el NPC")

func _physics_process(delta):
	match role:
		NPCEnums.Role.PATROLMAN:
			_process_patrolman_behavior(delta)
		NPCEnums.Role.GUARD:
			_process_guard_behavior(delta)
		NPCEnums.Role.FOLLOWER:
			_process_follower_behavior(delta)

func _process_patrolman_behavior(delta):
	_update_state()
	
	match current_state:
		NPCEnums.State.PATROL:
			_process_patrol_state(delta)
		NPCEnums.State.FACE:
			_process_face_state(delta)
		NPCEnums.State.CHASE_APPLE:
			_process_chasing_apple_state(delta)
		NPCEnums.State.ATTACK:
			_process_go_to_viewpoint_state(delta)

func _process_guard_behavior(delta):
	_update_state()
	
	match current_state:
		NPCEnums.State.FACE:
			_process_face_state(delta)
		NPCEnums.State.CHASE_APPLE:
			_process_chasing_apple_state(delta)

func _process_follower_behavior(delta):
	_update_state()
	
	match current_state:
		NPCEnums.State.FOLLOW_PLAYER:
			_process_follow_player_state(delta)
		NPCEnums.State.CHASE_APPLE:
			_process_chasing_apple_state(delta)

func _update_state():
	var desired_state = _get_highest_priority_state()
	if desired_state != current_state:
		_change_state(desired_state)

func _get_highest_priority_state() -> NPCEnums.State:
	# Si hay una manzana objetivo, perseguirla (interrumpe el regreso)
	if target_apple != null and is_instance_valid(target_apple):
		returning_to_position = false  # Cancelar regreso si hay nueva manzana
		return NPCEnums.State.CHASE_APPLE
	
	# Si está regresando a la posición inicial (GUARD), mantener en CHASE_APPLE para ejecutar el regreso
	if returning_to_position and role == NPCEnums.Role.GUARD:
		return NPCEnums.State.CHASE_APPLE
	
	# Different behavior based on role
	if role == NPCEnums.Role.FOLLOWER:
		# FOLLOWER: Sigue mientras el timer esté activo
		if following_timer > 0.0:
			return NPCEnums.State.FOLLOW_PLAYER
	elif role == NPCEnums.Role.PATROLMAN:
		# PATROLMAN: Cuando ve al jugador, primero ir al viewpoint, luego FACE
		if player_in_sight:
			if viewpoint_target and is_instance_valid(viewpoint_target):
				# Verificar si ya está en el viewpoint (distancia más pequeña para llegar completamente)
				var distance_to_viewpoint = global_position.distance_to(viewpoint_target.global_position)
				if distance_to_viewpoint < 10.0:
					# Ya está en el viewpoint, hacer FACE
					at_viewpoint = true
					return NPCEnums.State.FACE
				else:
					# Ir al viewpoint primero
					at_viewpoint = false
					return NPCEnums.State.ATTACK  # Usaremos ATTACK como estado temporal para ir al viewpoint
			else:
				# No hay viewpoint, hacer FACE directamente
				return NPCEnums.State.FACE
	else:
		# Otros roles: comportamiento normal (FACE cuando ve al jugador)
		if player_in_sight:
			return NPCEnums.State.FACE
	
	return NPCEnums.State.PATROL


func _change_state(new_state: NPCEnums.State):
	previous_state = current_state
	current_state = new_state
	
	# Resetear velocidad angular cuando sale de FACE
	if previous_state == NPCEnums.State.FACE and new_state != NPCEnums.State.FACE:
		current_angular_velocity = 0.0
		should_be_immovable = false
	
	# Detener movimiento cuando entra a FACE desde ATTACK (llegó al viewpoint)
	if previous_state == NPCEnums.State.ATTACK and new_state == NPCEnums.State.FACE:
		current_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		should_be_immovable = true
		fixed_position = global_position
	
	# Resetear inmovilidad cuando sale de PATROL o FACE a otros estados
	if (previous_state == NPCEnums.State.PATROL or previous_state == NPCEnums.State.FACE) and \
	   (new_state != NPCEnums.State.PATROL and new_state != NPCEnums.State.FACE):
		should_be_immovable = false

func _process_patrol_state(delta):
	if not patrol_path or not follow_path_behavior:
		# Sin path, mantener posición fija
		should_be_immovable = true
		fixed_position = global_position
		return
	
	var steering_output = follow_path_behavior.getSteering()
	
	if steering_output.length() > 0:
		current_velocity += steering_output * delta
		
		if current_velocity.length() > max_speed:
			current_velocity = current_velocity.normalized() * max_speed
		
		velocity = current_velocity
		
		# Guardar posición antes de move_and_slide si está quieto
		if current_velocity.length() < 5.0:
			should_be_immovable = true
			fixed_position = global_position
		else:
			should_be_immovable = false
		
		# Guardar posición antes de move_and_slide para restaurarla si es necesario
		var position_before_move = global_position
		
		move_and_slide()
		
		# Restaurar posición si debería ser inamovible (previene que colisiones lo muevan)
		if should_be_immovable:
			global_position = fixed_position
			velocity = Vector2.ZERO
			current_velocity = Vector2.ZERO
		
		if current_velocity.length() > 10.0:
			var target_rotation = current_velocity.angle()
			rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	else:
		# Sin steering output, mantener posición fija
		should_be_immovable = true
		fixed_position = global_position
		velocity = Vector2.ZERO
		current_velocity = Vector2.ZERO

func _process_go_to_viewpoint_state(delta):
	if not viewpoint_target or not is_instance_valid(viewpoint_target):
		return
	
	if not navigation_agent_2d:
		return
	
	var viewpoint_position = viewpoint_target.global_position
	var distance_to_viewpoint = global_position.distance_to(viewpoint_position)
	
	# Verificar distancia real al viewpoint (más preciso que is_navigation_finished)
	if distance_to_viewpoint < 10.0:
		# Ya llegó al viewpoint, detenerse completamente
		current_velocity = current_velocity.lerp(Vector2.ZERO, 10.0 * delta)
		velocity = current_velocity
		move_and_slide()
		return
	
	# Continuar moviéndose hacia el viewpoint
	navigation_agent_2d.target_position = viewpoint_position
	
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	
	# Si el NavigationAgent dice que terminó pero aún no estamos cerca, usar dirección directa
	if navigation_agent_2d.is_navigation_finished() and distance_to_viewpoint >= 10.0:
		# Ir directamente al viewpoint si NavigationAgent ya terminó pero no estamos cerca
		var direction = (viewpoint_position - current_agent_position).normalized()
		var new_velocity = direction * max_speed
		if navigation_agent_2d.avoidance_enabled:
			navigation_agent_2d.set_velocity(new_velocity)
		else:
			_on_navigation_agent_2d_velocity_computed(new_velocity)
	else:
		var new_velocity = current_agent_position.direction_to(next_path_position) * max_speed
		if navigation_agent_2d.avoidance_enabled:
			navigation_agent_2d.set_velocity(new_velocity)
		else:
			_on_navigation_agent_2d_velocity_computed(new_velocity)
	
	move_and_slide()
	
	if velocity.length() > 10.0:
		var target_rotation = velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func _process_face_state(delta):
	if not player:
		return
	
	# En estado FACE, el NPC debe ser inamovible
	should_be_immovable = true
	fixed_position = global_position
	
	current_velocity = current_velocity.lerp(Vector2.ZERO, 5.0 * delta)
	velocity = current_velocity
	move_and_slide()
	
	# Restaurar posición para mantener inamovible
	global_position = fixed_position
	velocity = Vector2.ZERO
	current_velocity = Vector2.ZERO
	
	var target_orientation = face_behavior.face_position(player.global_position)
	var angular_acceleration = face_behavior.align_to_orientation(target_orientation, current_angular_velocity, delta)
	current_angular_velocity += angular_acceleration * delta
	rotation += current_angular_velocity * delta
	
	# Shoot while facing the player (only for GUARD role)
	if can_shoot and role == NPCEnums.Role.GUARD:
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			_shoot_bullet()
			shoot_timer = shoot_interval

func _process_follow_player_state(delta):
	if not player:
		return
	
	# Verificar que el grafo táctico esté disponible
	if not tactical_graph:
		# Fallback: usar navegación normal si no hay grafo táctico
		if not navigation_agent_2d:
			return
		navigation_agent_2d.target_position = player.global_position
		var next_path_position = navigation_agent_2d.get_next_path_position()
		var new_velocity = global_position.direction_to(next_path_position) * max_speed
		if navigation_agent_2d.avoidance_enabled:
			navigation_agent_2d.set_velocity(new_velocity)
		else:
			_on_navigation_agent_2d_velocity_computed(new_velocity)
		move_and_slide()
		if velocity.length() > 10.0:
			var target_rotation = velocity.angle()
			rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
		return
	
	if player_in_sight:
		following_timer = following_duration
	else:
		following_timer -= delta
	
	var player_position = player.global_position
	
	# Recalcular el path táctico periódicamente o si el jugador se movió significativamente
	path_recalculate_timer -= delta
	if path_recalculate_timer <= 0.0 or player_position.distance_to(last_target_position) > 50.0:
		var best_location = get_best_tactical_location_near(player_position, 150.0)
		if best_location:
			var target_pos = best_location.global_position
			tactical_path = find_tactical_path(global_position, target_pos)
			current_path_index = 0
			last_target_position = player_position
		else:
			tactical_path = find_tactical_path(global_position, player_position)
			current_path_index = 0
			last_target_position = player_position
		
		path_recalculate_timer = path_recalculate_interval
	
	# Usar directamente el tactical_path para el movimiento
	var target_position: Vector2
	if tactical_path.size() > 0 and current_path_index < tactical_path.size():
		target_position = tactical_path[current_path_index]
		
		# Avanzar al siguiente waypoint si estamos cerca del actual
		var distance_to_waypoint = global_position.distance_to(target_position)
		if distance_to_waypoint < 20.0:
			current_path_index += 1
			if current_path_index >= tactical_path.size():
				# Hemos llegado al final del path táctico
				# Si el último waypoint es cerca del jugador, ir directamente al jugador
				# Si no, recalcular el path
				if target_position.distance_to(player_position) < 30.0:
					tactical_path.clear()
					current_path_index = 0
					target_position = player_position
				else:
					# Recalcular path hacia el jugador
					tactical_path = find_tactical_path(global_position, player_position)
					current_path_index = 0
					if tactical_path.size() > 0:
						target_position = tactical_path[0]
					else:
						target_position = player_position
			else:
				target_position = tactical_path[current_path_index]
	else:
		# No hay path táctico válido, ir directamente al jugador
		target_position = player_position
	
	# Calcular velocidad usando steering seek hacia el waypoint táctico actual
	var direction = target_position - global_position
	var distance = direction.length()
	
	if distance < 5.0:
		# Ya llegamos al waypoint, detener
		current_velocity = current_velocity.lerp(Vector2.ZERO, 5.0 * delta)
	else:
		# Usar steering seek hacia el waypoint
		var desired_velocity = direction.normalized() * max_speed
		var steering = (desired_velocity - current_velocity) / 0.1  # time_to_target aproximado
		
		if steering.length() > max_acceleration:
			steering = steering.normalized() * max_acceleration
		
		current_velocity += steering * delta
		
		if current_velocity.length() > max_speed:
			current_velocity = current_velocity.normalized() * max_speed
	
	velocity = current_velocity
	move_and_slide()
	
	if velocity.length() > 10.0:
		var target_rotation = velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func _on_sight_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_sight = true
		# Si es FOLLOWER, iniciar/resetear el timer de seguimiento
		if role == NPCEnums.Role.FOLLOWER:
			following_timer = following_duration

func _on_sight_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_sight = false
		# Resetear el estado del viewpoint cuando el jugador sale de la vista
		if role == NPCEnums.Role.PATROLMAN:
			at_viewpoint = false
		
func _process_chasing_apple_state(delta):
	# Si está regresando a la posición inicial (solo para GUARD)
	if returning_to_position and role == NPCEnums.Role.GUARD:
		_return_to_initial_position(delta)
		return
	
	if target_apple == null or not is_instance_valid(target_apple):
		target_apple = null
		# Si es GUARD y no hay más manzanas, regresar a posición inicial
		if role == NPCEnums.Role.GUARD and apples_in_range.is_empty():
			returning_to_position = true
		return
	
	apple_virtual_target.global_position = target_apple.global_position
	
	var steering_output = apple_seek_behavior.calculate_steering()
	current_velocity += steering_output * delta
	
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed
	
	velocity = current_velocity
	move_and_slide()
	
	if current_velocity.length() > 0:
		var target_rotation = current_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
	if global_position.distance_to(target_apple.global_position) < 15.0:
		# Guardar referencia a la manzana antes de eliminarla
		var collected_apple = target_apple
		target_apple = null
		apples_in_range.erase(collected_apple)
		
		# Si es GUARD, después de agarrar la manzana, regresar a posición inicial
		if role == NPCEnums.Role.GUARD:
			returning_to_position = true
			print("GUARD: Manzana agarrada, regresando a posición inicial: ", initial_position)
			# No actualizar target_apple si está regresando, para evitar que persiga otra manzana
		else:
			update_target_apple()

func _on_apple_detected(area):
	if area.is_in_group("pickable"):
		if not apples_in_range.has(area):
			apples_in_range.append(area)
		# Si el GUARD está regresando, no actualizar target_apple (dejar que termine el regreso primero)
		if not (role == NPCEnums.Role.GUARD and returning_to_position):
			update_target_apple()

func _on_apple_lost(area):
	if area.is_in_group("pickable"):
		apples_in_range.erase(area)
		if area == target_apple:
			target_apple = null
		# Si el GUARD está regresando, no actualizar target_apple
		if not (role == NPCEnums.Role.GUARD and returning_to_position):
			update_target_apple()
		elif role == NPCEnums.Role.GUARD and apples_in_range.is_empty():
			# Si se perdió la última manzana y está regresando, mantener el regreso
			target_apple = null

func update_target_apple():
	# Si el GUARD está regresando, no actualizar target_apple
	if role == NPCEnums.Role.GUARD and returning_to_position:
		return
	
	if apples_in_range.is_empty():
		target_apple = null
		# Si es GUARD y no hay más manzanas, regresar a posición inicial
		if role == NPCEnums.Role.GUARD and not returning_to_position:
			returning_to_position = true
		return
	
	var closest_apple = null
	var closest_distance = INF
	
	for apple in apples_in_range:
		if is_instance_valid(apple):
			var distance = global_position.distance_to(apple.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_apple = apple
	
	if closest_apple != null:
		target_apple = closest_apple

func _return_to_initial_position(delta):
	var distance_to_initial = global_position.distance_to(initial_position)
	
	if distance_to_initial < 10.0:
		# Ya llegó a la posición inicial
		returning_to_position = false
		global_position = initial_position
		velocity = Vector2.ZERO
		current_velocity = Vector2.ZERO
		print("GUARD: Llegó a posición inicial")
		return
	
	if not navigation_agent_2d:
		# Fallback: usar steering seek directo si no hay NavigationAgent2D
		apple_virtual_target.global_position = initial_position
		var steering_output = apple_seek_behavior.calculate_steering()
		current_velocity += steering_output * delta
		
		if current_velocity.length() > max_speed:
			current_velocity = current_velocity.normalized() * max_speed
		
		velocity = current_velocity
		move_and_slide()
		
		if current_velocity.length() > 10.0:
			var target_rotation = current_velocity.angle()
			rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
		return
	
	# Usar NavigationAgent2D para regresar
	
	navigation_agent_2d.target_position = initial_position
	
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	
	if navigation_agent_2d.is_navigation_finished() and distance_to_initial >= 10.0:
		# Ir directamente a la posición inicial si NavigationAgent ya terminó pero no estamos cerca
		var direction = (initial_position - current_agent_position).normalized()
		var new_velocity = direction * max_speed
		if navigation_agent_2d.avoidance_enabled:
			navigation_agent_2d.set_velocity(new_velocity)
		else:
			_on_navigation_agent_2d_velocity_computed(new_velocity)
	else:
		var new_velocity = current_agent_position.direction_to(next_path_position) * max_speed
		if navigation_agent_2d.avoidance_enabled:
			navigation_agent_2d.set_velocity(new_velocity)
		else:
			_on_navigation_agent_2d_velocity_computed(new_velocity)
	
	move_and_slide()
	
	if velocity.length() > 10.0:
		var target_rotation = velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func _shoot_bullet():
	var bullet = BulletScene.instantiate()
	
	# Set bullet parameters based on current NPC state
	bullet.pos = global_position
	bullet.rota = rotation
	bullet.dir = rotation
	bullet.speed = bullet_speed
	
	# Add bullet to the scene tree (parent scene)
	get_parent().add_child(bullet)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

func _process(_delta):
	queue_redraw()

func _draw():
	if tactical_path.size() > 1:
		for i in range(tactical_path.size() - 1):
			var start = to_local(tactical_path[i])
			var end = to_local(tactical_path[i + 1])
			draw_line(start, end, Color.CYAN, 3.0)
		
		# Marcar el waypoint actual
		if current_path_index < tactical_path.size():
			var current = to_local(tactical_path[current_path_index])
			draw_circle(current, 10.0, Color.GREEN)

func find_tactical_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	if not tactical_graph or not tactical_graph.has_method("find_nearest_location"):
		if role == NPCEnums.Role.FOLLOWER:
			push_warning("find_tactical_path: No hay grafo táctico disponible")
		return [to]
	
	var start_location = tactical_graph.find_nearest_location(from)
	var end_location = tactical_graph.find_nearest_location(to)
	
	if not start_location or not end_location:
		if role == NPCEnums.Role.FOLLOWER:
			push_warning("find_tactical_path: No se encontraron ubicaciones tácticas cercanas")
		return [to]
	
	if start_location == end_location:
		return [end_location.global_position]
	
	var path = _a_star_tactical(start_location, end_location)
	
	if path.is_empty():
		if role == NPCEnums.Role.FOLLOWER:
			push_warning("find_tactical_path: A* no encontró un camino. Usando destino directo.")
		return [to]
	
	var positions: Array[Vector2] = []
	for location in path:
		if location.has_method("global_position"):
			positions.append(location.global_position)
	
	if positions.is_empty():
		if role == NPCEnums.Role.FOLLOWER:
			push_warning("find_tactical_path: El path no tiene posiciones válidas")
		return [to]
	
	if role == NPCEnums.Role.FOLLOWER:
		print("find_tactical_path: Path táctico encontrado con %d waypoints" % positions.size())
	
	return positions

func _a_star_tactical(start: Node, goal: Node) -> Array:
	if not tactical_graph or not tactical_graph.has_method("get_graph"):
		return []
	
	var graph = tactical_graph.get_graph()
	var location_by_id = {}
	
	if tactical_graph.has_method("get_location_by_id"):
		for node_id in graph.keys():
			var location = tactical_graph.get_location_by_id(node_id)
			if location:
				location_by_id[node_id] = location
	
	var start_id = -1
	var goal_id = -1
	
	if start.has_method("get_static_quality"):
		var start_location = start as TacticalLocation
		if start_location:
			start_id = start_location.node_id
	if goal.has_method("get_static_quality"):
		var goal_location = goal as TacticalLocation
		if goal_location:
			goal_id = goal_location.node_id
	
	if start_id == -1 or goal_id == -1:
		return []
	
	var open_set: Array[int] = [start_id]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	
	g_score[start_id] = 0.0
	f_score[start_id] = _heuristic_tactical(start_id, goal_id, location_by_id)
	
	while not open_set.is_empty():
		var current_id = _get_lowest_f_score(open_set, f_score)
		
		if current_id == goal_id:
			return _reconstruct_path_tactical(came_from, current_id, location_by_id)
		
		open_set.erase(current_id)
		
		if not graph.has(current_id):
			continue
		
		for neighbor_id in graph[current_id]:
			if not location_by_id.has(neighbor_id):
				continue
			
			var neighbor = location_by_id[neighbor_id]
			if not is_instance_valid(neighbor):
				continue
			
			var current_location = location_by_id.get(current_id)
			if not current_location:
				continue
			
			var distance = current_location.global_position.distance_to(neighbor.global_position)
			var tactical_value = 0.0
			
			if neighbor.has_method("calculate_tactical_value"):
				tactical_value = neighbor.calculate_tactical_value(tactical_weights)
			
			var tentative_g_score = g_score.get(current_id, INF) + distance - (tactical_value * tactical_influence_factor)
			
			if tentative_g_score < g_score.get(neighbor_id, INF):
				came_from[neighbor_id] = current_id
				g_score[neighbor_id] = tentative_g_score
				f_score[neighbor_id] = tentative_g_score + _heuristic_tactical(neighbor_id, goal_id, location_by_id)
				
				if not open_set.has(neighbor_id):
					open_set.append(neighbor_id)
	
	return []

func _heuristic_tactical(from_id: int, to_id: int, location_by_id: Dictionary) -> float:
	if not location_by_id.has(from_id) or not location_by_id.has(to_id):
		return INF
	
	var from_location = location_by_id[from_id]
	var to_location = location_by_id[to_id]
	
	if not is_instance_valid(from_location) or not is_instance_valid(to_location):
		return INF
	
	return from_location.global_position.distance_to(to_location.global_position)

func _get_lowest_f_score(open_set: Array[int], f_score: Dictionary) -> int:
	var lowest_id = open_set[0]
	var lowest_score = f_score.get(lowest_id, INF)
	
	for node_id in open_set:
		var score = f_score.get(node_id, INF)
		if score < lowest_score:
			lowest_score = score
			lowest_id = node_id
	
	return lowest_id

func _reconstruct_path_tactical(came_from: Dictionary, current_id: int, location_by_id: Dictionary) -> Array:
	var path: Array = []
	var current = current_id
	
	while came_from.has(current):
		if location_by_id.has(current):
			path.insert(0, location_by_id[current])
		current = came_from[current]
	
	if location_by_id.has(current):
		path.insert(0, location_by_id[current])
	
	return path

func get_best_tactical_location_near(target: Vector2, radius: float) -> Node:
	if not tactical_graph or not tactical_graph.has_method("get_locations_in_radius"):
		return null
	
	var locations = tactical_graph.get_locations_in_radius(target, radius)
	
	if locations.is_empty():
		return null
	
	var best_location: Node = null
	var best_value: float = -INF
	
	for location in locations:
		if not is_instance_valid(location):
			continue
		
		if not location.has_method("calculate_tactical_value"):
			continue
		
		var tactical_value = location.calculate_tactical_value(tactical_weights)
		var distance = target.distance_to(location.global_position)
		var adjusted_value = tactical_value - (distance / radius)
		
		if adjusted_value > best_value:
			best_value = adjusted_value
			best_location = location
	
	return best_location
