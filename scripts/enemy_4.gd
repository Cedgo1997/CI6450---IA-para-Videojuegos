extends RigidBody2D

enum SteeringAlgorithm {
	WANDER,
	OBSTACLE_AVOIDANCE
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.WANDER

@export_group("Wander Settings")
@export var wander_offset = 300.0
@export var wander_radius = 50.0
@export var wander_rate = 3.0
@export var wander_max_speed = 150.0
@export var max_linear_acceleration = 100.0

@export_group("Obstacle Avoidance Settings")
@export var avoid_distance = 50.0
@export var lookahead = 150.0
@export var max_seek_speed = 200.0
@export var seek_acceleration = 300.0
@export var num_rays = 5
@export var ray_spread_angle = deg_to_rad(45.0)

@export_group("Rotation Settings")
@export var max_angular_acceleration = 10.0
@export var max_rotation_speed = 1.0
@export var target_radius = deg_to_rad(5.0)
@export var slow_radius = deg_to_rad(45.0)
@export var angular_time_to_target = 0.1

@export_group("Separation Settings")
@export var enable_separation = true
@export var separation_threshold = 100.0
@export var separation_decay_coefficient = 5000.0
@export var separation_turn_strength = 5.0

var wander_orientation = 0.0
var wander_target = Vector2.ZERO

func _ready():
	lock_rotation = false
	linear_velocity = Vector2.ZERO
	wander_orientation = rotation

func _physics_process(delta):
	match algorithm:
		SteeringAlgorithm.WANDER:
			steering_wander(delta)
		SteeringAlgorithm.OBSTACLE_AVOIDANCE:
			steering_obstacle_avoidance(delta)

func steering_wander(delta: float) -> void:
	wander_orientation += randf_range(-1, 1) * wander_rate
	var target_orientation = wander_orientation + rotation
	var wander_circle_center = global_position + wander_offset * Vector2(cos(rotation), sin(rotation))
	wander_target = wander_circle_center + wander_radius * Vector2(cos(target_orientation), sin(target_orientation))
	
	steering_face_wander(delta)
	
	var direction = Vector2(cos(rotation), sin(rotation))
	var acceleration = direction * max_linear_acceleration
	
	if enable_separation:
		var sep_vec = steering_separation()
		if sep_vec.length() > 0.1:
			var sep_dir = sep_vec.normalized()
			var sep_angle = sep_dir.angle()
			var blended_angle = lerp_angle(rotation, sep_angle, separation_turn_strength * delta)
			rotation = blended_angle
			
			var blended_force = direction.rotated(sep_angle - rotation)
			acceleration += blended_force * max_linear_acceleration * 0.6
			
			steering_look_where_youre_going(delta)
		else:
			steering_look_where_youre_going(delta)
	else:
		steering_look_where_youre_going(delta)
	
	if acceleration.length() > max_linear_acceleration:
		acceleration = acceleration.normalized() * max_linear_acceleration
	
	linear_velocity += acceleration * delta
	if linear_velocity.length() > wander_max_speed:
		linear_velocity = linear_velocity.normalized() * wander_max_speed

func steering_obstacle_avoidance(delta: float) -> void:
	if linear_velocity.length() < 0.1:
		var direction = Vector2(cos(rotation), sin(rotation))
		linear_velocity = direction * wander_max_speed * 0.5
	
	var ray_direction = linear_velocity.normalized()
	var ray_length = lookahead
	
	var collision_info = detect_collision_multi_ray(ray_direction, ray_length)
	
	var acceleration = Vector2.ZERO
	
	if collision_info != null:
		var target_position = collision_info.position + collision_info.normal * avoid_distance
		acceleration = steering_seek_internal(target_position)
	else:
		var direction = linear_velocity.normalized()
		acceleration = direction * max_linear_acceleration * 0.3
	
	if enable_separation:
		var sep_vec = steering_separation()
		if sep_vec.length() > 0.1:
			acceleration += sep_vec * 0.5
	
	if acceleration.length() > max_linear_acceleration:
		acceleration = acceleration.normalized() * max_linear_acceleration
	
	linear_velocity += acceleration * delta
	if linear_velocity.length() > max_seek_speed:
		linear_velocity = linear_velocity.normalized() * max_seek_speed
	
	steering_look_where_youre_going(delta)

func detect_collision_multi_ray(base_direction: Vector2, ray_length: float):
	var space_state = get_world_2d().direct_space_state
	var closest_collision = null
	var min_distance = INF
	
	for i in range(num_rays):
		var angle_offset = 0.0
		if num_rays > 1:
			angle_offset = lerp(-ray_spread_angle, ray_spread_angle, float(i) / (num_rays - 1))
		
		var ray_dir = base_direction.rotated(angle_offset)
		var ray_end = global_position + ray_dir * ray_length
		
		var query = PhysicsRayQueryParameters2D.create(global_position, ray_end)
		query.exclude = [self]
		query.collision_mask = collision_mask
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var distance = global_position.distance_to(result.position)
			if distance < min_distance:
				min_distance = distance
				closest_collision = {
					"position": result.position,
					"normal": result.normal
				}
	
	return closest_collision

func steering_seek_internal(target_position: Vector2) -> Vector2:
	var direction = target_position - global_position
	var distance = direction.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	var desired_velocity = direction.normalized() * max_seek_speed
	var acceleration = (desired_velocity - linear_velocity) / 0.1
	
	if acceleration.length() > seek_acceleration:
		acceleration = acceleration.normalized() * seek_acceleration
	
	return acceleration

func steering_separation() -> Vector2:
	var result = Vector2.ZERO
	var others = get_tree().get_nodes_in_group("enemy")
	for other in others:
		if other == self:
			continue
		var direction = other.global_position - global_position
		var distance = direction.length()
		if distance < separation_threshold and distance > 0:
			var strength = min(separation_decay_coefficient / (distance * distance), max_linear_acceleration)
			result -= direction.normalized() * strength
	if result.length() > max_linear_acceleration:
		result = result.normalized() * max_linear_acceleration
	return result

func steering_face_wander(delta: float) -> void:
	var direction = wander_target - global_position
	if direction.length() == 0:
		return
	var target_orientation = atan2(direction.y, direction.x)
	steering_align_internal(target_orientation, delta)

func steering_look_where_youre_going(delta: float) -> void:
	if linear_velocity.length() == 0:
		return
	var target_orientation = atan2(linear_velocity.y, linear_velocity.x)
	steering_align_internal(target_orientation, delta)

func steering_align_internal(target_orientation: float, delta: float) -> void:
	var rotation_diff = target_orientation - rotation
	rotation_diff = map_to_range(rotation_diff)
	var rotation_size = abs(rotation_diff)
	if rotation_size < target_radius:
		angular_velocity = 0
		return
	var target_rotation_speed = max_rotation_speed
	if rotation_size < slow_radius:
		target_rotation_speed = max_rotation_speed * rotation_size / slow_radius
	target_rotation_speed *= sign(rotation_diff)
	var angular_acceleration = (target_rotation_speed - angular_velocity) / angular_time_to_target
	if abs(angular_acceleration) > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration
	angular_velocity += angular_acceleration * delta

func map_to_range(angle: float) -> float:
	return fmod(angle + PI, 2 * PI) - PI
