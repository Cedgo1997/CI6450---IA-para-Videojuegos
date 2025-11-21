extends CharacterBody2D

const EnemyBehavior = preload("res://scripts/enemy_behavior.gd")
const NPCEnums = preload("res://scripts/enums/npc_enums.gd")
const BulletScene = preload("res://scenes/bullet.tscn")

@onready var item_detector = $SightArea

@export var max_speed: float = 200.0
@export var max_acceleration: float = 100.0
@export var rotation_speed: float = 8.0

@export_group('Role Settings')
@export var role: NPCEnums.Role = NPCEnums.Role.PATROLMAN

@export_group('Shooting Settings')
@export var shoot_interval: float = 0.5
@export var can_shoot: bool = true

@export_group('Follower Settings')
@export var following_duration: float = 5.0

@export_group('Path Following Settings')
@export var path_offset: float = 5.0
@export var pathGroup: String = "npc_path"
@export var patrol_path: Path2D = null

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

func _initialize_path_following():
	if not patrol_path:
		return
	
	path_wrapper = Path.new(patrol_path)
	follow_path_behavior = FollowPath.new(self, path_wrapper, path_offset, max_speed, max_acceleration)
	
	var closest_param = path_wrapper.getParam(global_position, 0.0)
	follow_path_behavior.current_param = closest_param + 0.5

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
	if target_apple != null and is_instance_valid(target_apple):
		return NPCEnums.State.CHASE_APPLE
	
	# Different behavior based on role
	if role == NPCEnums.Role.FOLLOWER:
		# FOLLOWER: Sigue mientras el timer esté activo
		if following_timer > 0.0:
			return NPCEnums.State.FOLLOW_PLAYER
	else:
		# Otros roles: comportamiento normal (FACE cuando ve al jugador)
		if player_in_sight:
			return NPCEnums.State.FACE
	
	return NPCEnums.State.PATROL


func _change_state(new_state: NPCEnums.State):
	previous_state = current_state
	current_state = new_state
	if previous_state == NPCEnums.State.FACE and new_state != NPCEnums.State.FACE:
		current_angular_velocity = 0.0

func _process_patrol_state(delta):
	if not patrol_path or not follow_path_behavior:
		return
	
	var steering_output = follow_path_behavior.getSteering()
	
	if steering_output.length() > 0:
		current_velocity += steering_output * delta
		
		if current_velocity.length() > max_speed:
			current_velocity = current_velocity.normalized() * max_speed
		
		velocity = current_velocity
		move_and_slide()
		
		if current_velocity.length() > 10.0:
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
	
	# Shoot while facing the player (only for GUARD role)
	if can_shoot and role == NPCEnums.Role.GUARD:
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			_shoot_bullet()
			shoot_timer = shoot_interval

func _process_follow_player_state(delta):
	if not player:
		return
	
	# Si el jugador está en el área de visión, resetear el timer
	if player_in_sight:
		following_timer = following_duration
	else:
		# Si no está visible, disminuir el timer
		following_timer -= delta
	
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * max_speed
	move_and_slide()
	
	# Rotate towards movement direction
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
		
func _process_chasing_apple_state(delta):
	if target_apple == null or not is_instance_valid(target_apple):
		target_apple = null
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
		target_apple = null
		apples_in_range.erase(target_apple)
		update_target_apple()

func _on_apple_detected(area):
	if area.is_in_group("pickable"):
		if not apples_in_range.has(area):
			apples_in_range.append(area)
		update_target_apple()

func _on_apple_lost(area):
	if area.is_in_group("pickable"):
		apples_in_range.erase(area)
		if area == target_apple:
			target_apple = null
			update_target_apple()

func update_target_apple():
	if apples_in_range.is_empty():
		target_apple = null
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

func _shoot_bullet():
	var bullet = BulletScene.instantiate()
	
	# Set bullet parameters based on current NPC state
	bullet.pos = global_position
	bullet.rota = rotation
	bullet.dir = rotation
	
	# Add bullet to the scene tree (parent scene)
	get_parent().add_child(bullet)

func _on_timer_timeout():
	pass


func _on_following_timer_timeout() -> void:
	pass # Replace with function body.
