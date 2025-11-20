extends Node
## Enemy Behavior System
## Contiene todos los algoritmos de steering behavior implementados de forma organizada
## Incluye: Kinematic Steering, Dynamic Steering, Path Following, y behaviors avanzados
##
## NOTA: Los enums de algoritmos se encuentran en res://scripts/enums/enemy_enums.gd

# =============================================================================
# BASE CLASSES - Clases base para steering behaviors
# =============================================================================

## Clase base para steering behaviors cinemáticos
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

# =============================================================================
# KINEMATIC BEHAVIORS - Behaviors sin aceleración (velocidad directa)
# =============================================================================

## Kinematic Seek: Perseguir al objetivo a velocidad máxima
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

## Kinematic Arrive: Llegar al objetivo desacelerando gradualmente
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
		
		# Detener si está muy cerca o tocando al jugador
		if distance < inner_radius or is_touching_player:
			return Vector2.ZERO
		
		# Velocidad máxima si está lejos
		if distance > outer_radius:
			direction = direction.normalized()
			return direction * max_speed
		
		# Desacelerar gradualmente dentro del radio de frenado
		var target_speed = distance / time_to_target
		target_speed = min(target_speed, max_speed)
		
		direction = direction.normalized()
		var velocity = direction * target_speed
		
		return velocity

## Kinematic Wander: Vagar cambiando de dirección aleatoriamente
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

# =============================================================================
# DYNAMIC BEHAVIORS - Behaviors con aceleración
# =============================================================================

## Dynamic Seek: Perseguir con aceleración
class SteeringSeek extends KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	
	func _init(owner: Node2D, tgt: Node2D, spd: float, max_accel: float):
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

## Dynamic Flee: Huir del objetivo con aceleración
class SteeringFlee extends KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	
	func _init(owner: Node2D, tgt: Node2D, spd: float, max_accel: float):
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

## Dynamic Arrive: Llegar al objetivo con aceleración y desaceleración
class SteeringArrive extends KinematicSteering:
	var max_acceleration: float
	var current_velocity: Vector2
	var target_radius: float
	var slow_radius: float
	var time_to_target: float
	
	func _init(owner: Node2D, tgt: Node2D, spd: float, max_accel: float, 
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
		
		# Detener si alcanzó el radio objetivo
		if distance < target_radius:
			current_velocity = Vector2.ZERO
			return Vector2.ZERO
		
		# Calcular velocidad objetivo
		var target_speed = max_speed
		if distance < slow_radius:
			target_speed = max_speed * (distance / slow_radius)
		
		var target_velocity = direction.normalized() * target_speed
		
		# Calcular aceleración necesaria
		var acceleration = (target_velocity - current_velocity) / time_to_target
		
		if acceleration.length() > max_acceleration:
			acceleration = acceleration.normalized() * max_acceleration
		
		return acceleration

# =============================================================================
# ROTATIONAL BEHAVIORS - Comportamientos de rotación
# =============================================================================

## Clase auxiliar para behaviors que requieren control de rotación
class RotationalBehavior:
	var owner_node: Node2D
	var max_angular_acceleration: float
	var max_rotation_speed: float
	var angular_time_to_target: float
	var target_radius: float
	var slow_radius: float
	
	func _init(owner: Node2D, max_ang_accel: float, max_rot_spd: float, 
			   ang_ttt: float, tgt_rad: float, slw_rad: float):
		owner_node = owner
		max_angular_acceleration = max_ang_accel
		max_rotation_speed = max_rot_spd
		angular_time_to_target = ang_ttt
		target_radius = tgt_rad
		slow_radius = slw_rad
	
	## Alinear con una orientación objetivo
	func align_to_orientation(target_orientation: float, current_angular_velocity: float, _delta: float) -> float:
		var rotation_diff = angle_difference(owner_node.rotation, target_orientation)
		var rotation_size = abs(rotation_diff)
		
		if rotation_size < target_radius:
			return 0.0
		
		var target_rotation_speed = max_rotation_speed
		if rotation_size < slow_radius:
			target_rotation_speed = max_rotation_speed * rotation_size / slow_radius
		
		target_rotation_speed *= sign(rotation_diff)
		
		var angular_acceleration = (target_rotation_speed - current_angular_velocity) / angular_time_to_target
		if abs(angular_acceleration) > max_angular_acceleration:
			angular_acceleration = sign(angular_acceleration) * max_angular_acceleration
		
		return angular_acceleration
	
	## Mirar hacia una posición
	func face_position(target_position: Vector2) -> float:
		var direction = target_position - owner_node.global_position
		if direction.length() == 0:
			return owner_node.rotation
		return atan2(direction.y, direction.x)
	
	## Mirar en la dirección del movimiento
	func look_where_going(velocity: Vector2) -> float:
		if velocity.length() == 0:
			return owner_node.rotation
		return atan2(velocity.y, velocity.x)

# =============================================================================
# ADVANCED BEHAVIORS - Comportamientos avanzados
# =============================================================================

## Pursue: Perseguir prediciendo la posición futura del objetivo
class PursueBehavior:
	var owner_node: RigidBody2D
	var target: Node2D
	var max_speed: float
	var max_linear_acceleration: float
	var max_prediction_time: float
	var arrive_target_radius: float
	var arrive_slow_radius: float
	var arrive_time_to_target: float
	var target_velocity: Vector2
	
	func _init(owner: RigidBody2D, tgt: Node2D, max_spd: float, max_accel: float,
			   max_pred: float, arr_tgt_rad: float, arr_slw_rad: float, arr_ttt: float):
		owner_node = owner
		target = tgt
		max_speed = max_spd
		max_linear_acceleration = max_accel
		max_prediction_time = max_pred
		arrive_target_radius = arr_tgt_rad
		arrive_slow_radius = arr_slw_rad
		arrive_time_to_target = arr_ttt
		target_velocity = Vector2.ZERO
	
	func set_target_velocity(vel: Vector2):
		target_velocity = vel
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
		
		var direction = target.global_position - owner_node.global_position
		var distance = direction.length()
		var speed = owner_node.linear_velocity.length()
		
		# Calcular tiempo de predicción
		var prediction = 0.0
		if speed <= distance / max_prediction_time:
			prediction = max_prediction_time
		else:
			prediction = distance / speed
		
		# Predecir posición futura
		var predicted_position = target.global_position + target_velocity * prediction
		
		# Usar arrive hacia la posición predicha
		return _arrive_to_position(predicted_position)
	
	func _arrive_to_position(target_position: Vector2) -> Vector2:
		var direction = target_position - owner_node.global_position
		var distance = direction.length()
		
		if distance < arrive_target_radius:
			return -owner_node.linear_velocity / arrive_time_to_target
		
		var target_speed = max_speed
		if distance < arrive_slow_radius:
			target_speed = max_speed * (distance / arrive_slow_radius)
		
		var target_velocity_vec = direction.normalized() * target_speed
		var acceleration = (target_velocity_vec - owner_node.linear_velocity) / arrive_time_to_target
		
		if acceleration.length() > max_linear_acceleration:
			acceleration = acceleration.normalized() * max_linear_acceleration
		
		return acceleration

## Evade: Evadir prediciendo la posición futura del objetivo
class EvadeBehavior:
	var owner_node: RigidBody2D
	var target: Node2D
	var max_speed: float
	var max_linear_acceleration: float
	var max_prediction_time: float
	var target_velocity: Vector2
	
	func _init(owner: RigidBody2D, tgt: Node2D, max_spd: float, max_accel: float, max_pred: float):
		owner_node = owner
		target = tgt
		max_speed = max_spd
		max_linear_acceleration = max_accel
		max_prediction_time = max_pred
		target_velocity = Vector2.ZERO
	
	func set_target_velocity(vel: Vector2):
		target_velocity = vel
	
	func calculate_steering() -> Vector2:
		if not target:
			return Vector2.ZERO
		
		var direction = target.global_position - owner_node.global_position
		var distance = direction.length()
		var speed = owner_node.linear_velocity.length()
		
		# Calcular tiempo de predicción
		var prediction = 0.0
		if speed <= distance / max_prediction_time:
			prediction = max_prediction_time
		else:
			prediction = distance / speed
		
		# Predecir posición futura
		var predicted_position = target.global_position + target_velocity * prediction
		
		# Huir de la posición predicha
		var result = owner_node.global_position - predicted_position
		if result.length() > 0:
			result = result.normalized()
		result *= max_linear_acceleration
		
		return result

## Dynamic Wander: Vagar con comportamiento dinámico más complejo
class DynamicWanderBehavior:
	var owner_node: RigidBody2D
	var max_linear_acceleration: float
	var wander_max_speed: float
	var wander_offset: float
	var wander_radius: float
	var wander_rate: float
	var wander_orientation: float = 0.0
	var wander_target: Vector2 = Vector2.ZERO
	
	func _init(owner: RigidBody2D, max_accel: float, max_spd: float, 
			   offset: float, radius: float, rate: float):
		owner_node = owner
		max_linear_acceleration = max_accel
		wander_max_speed = max_spd
		wander_offset = offset
		wander_radius = radius
		wander_rate = rate
		wander_orientation = owner.rotation
	
	func calculate_steering() -> Vector2:
		# Actualizar orientación de wander
		wander_orientation += randf_range(-1, 1) * wander_rate
		var target_orientation = wander_orientation + owner_node.rotation
		
		# Calcular círculo de wander
		var wander_circle_center = owner_node.global_position + wander_offset * Vector2(cos(owner_node.rotation), sin(owner_node.rotation))
		wander_target = wander_circle_center + wander_radius * Vector2(cos(target_orientation), sin(target_orientation))
		
		# Aceleración en la dirección actual
		var direction = Vector2(cos(owner_node.rotation), sin(owner_node.rotation))
		var acceleration = direction * max_linear_acceleration
		
		return acceleration
	
	func get_wander_target() -> Vector2:
		return wander_target

# =============================================================================
# OBSTACLE AVOIDANCE - Evasión de obstáculos
# =============================================================================

## Sistema de evasión de obstáculos con raycast
class ObstacleAvoidance:
	var owner_node: Node2D
	var lookahead_distance: float
	var avoid_distance: float
	var max_acceleration: float
	var num_rays: int
	var ray_spread_angle: float
	
	func _init(owner: Node2D, lookahead: float, avoid_dist: float, max_accel: float, rays: int = 5, spread: float = deg_to_rad(60.0)):
		owner_node = owner
		lookahead_distance = lookahead
		avoid_distance = avoid_dist
		max_acceleration = max_accel
		num_rays = rays
		ray_spread_angle = spread
	
	## Detectar obstáculos con un solo rayo
	func detect_single_ray(velocity: Vector2, collision_mask: int) -> Dictionary:
		if velocity.length() < 0.1:
			return {}
		
		var ray_direction = velocity.normalized()
		var space_state = owner_node.get_world_2d().direct_space_state
		var ray_end = owner_node.global_position + ray_direction * lookahead_distance
		
		var query = PhysicsRayQueryParameters2D.create(owner_node.global_position, ray_end)
		query.exclude = [owner_node]
		query.collision_mask = collision_mask
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var collider = result.get("collider")
			if collider and _is_obstacle(collider):
				return {
					"position": result.position,
					"normal": result.normal
				}
		
		return {}
	
	## Detectar obstáculos con múltiples rayos en abanico
	func detect_multi_ray(velocity: Vector2, collision_mask: int) -> Dictionary:
		var ray_direction = velocity.normalized() if velocity.length() > 0.1 else Vector2(cos(owner_node.rotation), sin(owner_node.rotation))
		var space_state = owner_node.get_world_2d().direct_space_state
		var closest_collision = {}
		var min_distance = INF
		
		for i in range(num_rays):
			var angle_offset = 0.0
			if num_rays > 1:
				angle_offset = lerp(-ray_spread_angle, ray_spread_angle, float(i) / (num_rays - 1))
			
			var ray_dir = ray_direction.rotated(angle_offset)
			var ray_end = owner_node.global_position + ray_dir * lookahead_distance
			
			var query = PhysicsRayQueryParameters2D.create(owner_node.global_position, ray_end)
			query.exclude = [owner_node]
			query.collision_mask = collision_mask
			
			var result = space_state.intersect_ray(query)
			
			if result:
				var distance = owner_node.global_position.distance_to(result.position)
				if distance < min_distance:
					var collider = result.get("collider")
					if collider and _is_obstacle(collider):
						min_distance = distance
						closest_collision = {
							"position": result.position,
							"normal": result.normal
						}
		
		return closest_collision
	
	## Calcular fuerza de evasión basada en la colisión detectada
	func calculate_avoidance_force(collision_info: Dictionary) -> Vector2:
		if collision_info.is_empty():
			return Vector2.ZERO
		
		var distance_to_collision = owner_node.global_position.distance_to(collision_info.position)
		var urgency = 1.0 - (distance_to_collision / lookahead_distance)
		urgency = clamp(urgency, 0.0, 1.0)
		
		var avoidance_target = collision_info.position + collision_info.normal * avoid_distance
		var to_target = avoidance_target - owner_node.global_position
		
		if to_target.length() < 1.0:
			return Vector2.ZERO
		
		var avoidance_force = to_target.normalized() * max_acceleration * (urgency + 0.5)
		
		return avoidance_force
	
	func _is_obstacle(collider) -> bool:
		if collider.is_in_group("obstacle"):
			return true
		elif collider is StaticBody2D or collider is RigidBody2D or collider is CharacterBody2D:
			if not collider.is_in_group("player"):
				return true
		return false

# =============================================================================
# SEPARATION - Separación entre enemigos
# =============================================================================

## Sistema de separación para evitar aglomeraciones
class SeparationBehavior:
	var owner_node: Node2D
	var separation_threshold: float
	var separation_decay_coefficient: float
	var max_acceleration: float
	var group_name: String
	
	func _init(owner: Node2D, threshold: float, decay: float, max_accel: float, group: String = "enemy"):
		owner_node = owner
		separation_threshold = threshold
		separation_decay_coefficient = decay
		max_acceleration = max_accel
		group_name = group
	
	func calculate_separation() -> Vector2:
		var result = Vector2.ZERO
		var others = owner_node.get_tree().get_nodes_in_group(group_name)
		
		for other in others:
			if other == owner_node:
				continue
			
			var direction = other.global_position - owner_node.global_position
			var distance = direction.length()
			
			if distance < separation_threshold and distance > 0:
				var strength = min(separation_decay_coefficient / (distance * distance), max_acceleration)
				result -= direction.normalized() * strength
		
		if result.length() > max_acceleration:
			result = result.normalized() * max_acceleration
		
		return result

# =============================================================================
# PATH FOLLOWING - Seguimiento de caminos
# =============================================================================

## Clase para representar un camino (Path2D)
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
	
	## Obtener el parámetro del camino más cercano a una posición
	func getParam(position: Vector2, lastParam: float) -> float:
		if points.size() < 2:
			return 0.0
		
		var local_pos = path_node.to_local(position)
		
		var closest_segment = 0
		var min_distance = INF
		
		# Buscar segmento más cercano (optimizado con búsqueda local)
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
	
	## Obtener posición en el camino dado un parámetro
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

## Behavior para seguir un camino
class FollowPathBehavior:
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
		
		# Crear objetivo virtual
		virtual_target = Node2D.new()
		character.add_child(virtual_target)
		
		# Usar Seek hacia el objetivo virtual
		seek_behavior = SteeringSeek.new(character, virtual_target, max_spd, max_accel)
	
	func calculate_steering() -> Vector2:
		# Actualizar parámetro actual en el camino
		current_param = path.getParam(character.global_position, current_param)
		
		# Calcular posición objetivo adelante en el camino
		var target_param = current_param + path_offset
		var target_position = path.getPosition(target_param)
		virtual_target.global_position = target_position
		
		# Usar Seek hacia el objetivo virtual
		return seek_behavior.calculate_steering()
	
	func cleanup():
		if virtual_target:
			virtual_target.queue_free()

# =============================================================================
# UTILITY FUNCTIONS - Funciones de utilidad
# =============================================================================

## Mapear un ángulo al rango [-PI, PI]
static func map_to_range(angle: float) -> float:
	return fmod(angle + PI, 2 * PI) - PI

## Calcular la diferencia entre dos ángulos
static func angle_difference(from_angle: float, to_angle: float) -> float:
	var diff = to_angle - from_angle
	return map_to_range(diff)
