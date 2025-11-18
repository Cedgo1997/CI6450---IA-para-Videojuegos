extends RigidBody2D

const EnemyScript = preload("res://scripts/enemy.gd")

@export var max_speed = 200.0
@export var max_acceleration = 100.0
@export var rotation_speed = 8.0

@export_group('Path Following Settings')
@export var path_offset = 1.0

var path: Path2D = null
var current_velocity = Vector2.ZERO
var steering_behavior = null
var current_param = 0.0

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

class SteeringSeek extends EnemyScript.KinematicSteering:
	var max_acceleration: float
	
	func _init(owner: RigidBody2D, tgt: Node2D, spd: float, max_accel: float):
		super(owner, tgt, spd)
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
	var character: RigidBody2D
	var path: Path
	var path_offset: float
	var current_param: float
	var seek_behavior: SteeringSeek
	var virtual_target: Node2D
	
	func _init(owner: RigidBody2D, p: Path, offset: float, max_spd: float, max_accel: float):
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

func _ready():
	var paths = get_tree().get_nodes_in_group("enemy_path")
	if paths.size() > 0:
		path = paths[0]
	else:
		push_error("No se encontró ningún Path2D en el grupo 'enemy_path'")
		return
	
	lock_rotation = false
	linear_damp = 0.5
	
	_initialize_steering_behavior()

func _initialize_steering_behavior():
	if not path:
		return
	
	var path_wrapper = Path.new(path)
	steering_behavior = FollowPath.new(self, path_wrapper, path_offset, max_speed, max_acceleration)

func _physics_process(delta):
	if path == null or steering_behavior == null:
		return
	
	var steering_output = steering_behavior.getSteering()
	
	current_velocity += steering_output * delta
	
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed
	
	linear_velocity = current_velocity
	
	if current_velocity.length() > 0:
		var target_rotation = current_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
