extends CharacterBody2D

const EnemyBehavior = preload("res://scripts/enemy_behavior.gd")
@onready var item_detector = $SightArea

@export var max_speed: float = 200.0
@export var max_acceleration: float = 100.0
@export var rotation_speed: float = 8.0

@export_group('Path Following Settings')
@export var path_offset: float = 1.0
@export var pathGroup: String = "npc_path"
@export var patrol_path: Path2D = null

var target_apple = null
var apples_in_range = []

enum State {
	PATROL,
	FACE,
	CHASE_APPLE
}

var current_state: State = State.PATROL
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
		virtual_target.global_position = target_position
		return seek_behavior.calculate_steering()
	
	func cleanup():
		if virtual_target:
			virtual_target.queue_free()

func _ready():
	print("\n[NPC] Inicializando NPC...")
	player = get_tree().get_first_node_in_group("player")
	item_detector.body_entered.connect(_on_apple_detected)
	item_detector.area_entered.connect(_on_apple_detected)
	item_detector.body_exited.connect(_on_apple_lost)
	item_detector.area_exited.connect(_on_apple_lost)
	
	if player:
		print("[NPC] Player encontrado: ", player.name)
	else:
		print("[NPC] ⚠️ WARNING: No se encontró el player")
	
	if not patrol_path:
		var paths = get_tree().get_nodes_in_group(pathGroup)
		if paths.size() > 0:
			patrol_path = paths[0]
			print("[NPC] Path2D encontrado por grupo '", pathGroup, "': ", patrol_path.name)
		else:
			push_error("No se encontró ningún Path2D en el grupo '" + pathGroup + "' ni asignado directamente")
			return
	else:
		print("[NPC] Path2D asignado directamente: ", patrol_path.name)
	
	if patrol_path:
		_initialize_path_following()
	
	face_behavior = EnemyBehavior.RotationalBehavior.new(self, 5.0, 3.0, 0.1, 0.01, 0.5)
	print("[NPC] Face behavior inicializado")
	
	apple_virtual_target = Node2D.new()
	add_child(apple_virtual_target)
	apple_seek_behavior = SteeringSeek.new(self, apple_virtual_target, max_speed, max_acceleration)
	print("[NPC] Apple seek behavior inicializado")
	
	var sight_area = get_node_or_null("SightArea")
	if sight_area:
		sight_area.body_entered.connect(_on_sight_body_entered)
		sight_area.body_exited.connect(_on_sight_body_exited)
		print("[NPC] SightArea encontrada y conectada")
	else:
		print("[NPC] ⚠️ WARNING: No se encontró SightArea")
	
	print("[NPC] Estado inicial: PATROL")
	print("[NPC] Inicialización completa\n")

func _initialize_path_following():
	if not patrol_path:
		return
	
	path_wrapper = Path.new(patrol_path)
	follow_path_behavior = FollowPath.new(self, path_wrapper, path_offset, max_speed, max_acceleration)
	print("[NPC] Path Following inicializado con ", path_wrapper.points.size(), " puntos")

func _physics_process(delta):
	match current_state:
		State.PATROL:
			_process_patrol_state(delta)
		State.FACE:
			_process_face_state(delta)
		State.CHASE_APPLE:
			_process_chasing_apple_state(delta)

func _process_patrol_state(delta):
	if not patrol_path or not follow_path_behavior:
		return
	
	var steering_output = follow_path_behavior.getSteering()
	current_velocity += steering_output * delta
	
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed
	
	velocity = current_velocity
	move_and_slide()
	
	if current_velocity.length() > 0:
		var target_rotation = current_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func _process_face_state(delta):
	if not player:
		return
	
	current_velocity = current_velocity.lerp(Vector2.ZERO, 5.0 * delta)
	velocity = current_velocity
	move_and_slide()
	
	var target_orientation = face_behavior.face_position(player.global_position)
	var angular_acceleration = face_behavior.align_to_orientation(target_orientation, current_angular_velocity, delta)
	current_angular_velocity += angular_acceleration * delta
	rotation += current_angular_velocity * delta

func _on_sight_body_entered(body: Node2D):
	print("[NPC] Body entered sight: ", body.name, " | Is player: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_in_sight = true
		print("══════════════════════════════════════")
		print("🔴 CAMBIO DE ESTADO: PATROL → FACE")
		print("══════════════════════════════════════")
		current_state = State.FACE
	if body.is_in_group("pickable"):
		current_state = State.CHASE_APPLE

func _on_sight_body_exited(body: Node2D):
	print("[NPC] Body exited sight: ", body.name, " | Is player: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_in_sight = false
		current_angular_velocity = 0.0
		print("══════════════════════════════════════")
		print("🟢 CAMBIO DE ESTADO: FACE → PATROL")
		print("══════════════════════════════════════")
		current_state = State.PATROL
	if body.is_in_group("pickable"):
		current_state = State.PATROL
		
func _process_chasing_apple_state(delta):
	if target_apple == null or not is_instance_valid(target_apple):
		change_to_player_chase()
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
		print("¡Llegué a la manzana!")
		target_apple = null
		change_to_player_chase()

func change_to_player_chase():
	current_state = State.PATROL
	target_apple = null
	apples_in_range.clear()
	
func _on_apple_detected(area):
	if area.is_in_group("pickable"):
		print("¡Manzana detectada!")
		apples_in_range.append(area)
		update_target_apple()

func _on_apple_lost(area):
	if area.is_in_group("pickable"):
		print("Manzana salió del rango")
		apples_in_range.erase(area)
		
		if area == target_apple:
			update_target_apple()

func update_target_apple():
	if apples_in_range.is_empty():
		change_to_player_chase()
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
		current_state = State.CHASE_APPLE
		print("Cambiando objetivo a manzana en: ", target_apple.global_position)

func _on_timer_timeout():
	pass
