extends Node2D

@export var static_qualities: Dictionary = {
	"cobertura": 0.8,
	"visibilidad": 0.6,
	"altura": 0.9
}

@export var dynamic_qualities: Dictionary = {
	"peligro": 0.0
}

@export var connected_locations: Array[Node] = []

@export var node_id: int = -1

@export_group("Dynamic Quality Settings")
@export var danger_detection_radius: float = 200.0
@export var danger_decay_rate: float = 0.5
@export var max_danger_value: float = 1.0
@export var update_interval: float = 0.1

var player: Node2D = null
var enemies: Array[Node] = []

var update_timer: float = 0.0

@export_group("Visualization")
@export var show_connections: bool = true
@export var connection_color: Color = Color(1.0, 1.0, 0.0, 0.5)
@export var show_debug_info: bool = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	if dynamic_qualities.is_empty():
		dynamic_qualities["peligro"] = 0.0
	
	if static_qualities.size() < 3:
		push_warning("TacticalLocation: Se recomienda tener al menos 3 cualidades estáticas. Actualmente tiene %d" % static_qualities.size())
	
	if dynamic_qualities.is_empty():
		push_warning("TacticalLocation: Se recomienda tener al menos 1 cualidad dinámica")
	
	if node_id == -1:
		node_id = _generate_unique_id()

func _process(delta):
	update_timer -= delta
	if update_timer <= 0.0:
		update_dynamic_qualities()
		update_timer = update_interval
	
	if show_connections:
		queue_redraw()

func _draw():
	if show_connections:
		_draw_connections()

func calculate_tactical_value(weights: Dictionary) -> float:
	var total_value: float = 0.0
	
	for quality_name in static_qualities:
		var quality_value = static_qualities[quality_name]
		var weight = weights.get(quality_name, 0.0)
		total_value += quality_value * weight
	
	for quality_name in dynamic_qualities:
		var quality_value = dynamic_qualities[quality_name]
		var weight = weights.get(quality_name, 0.0)
		total_value += quality_value * weight
	
	return total_value

func update_dynamic_qualities():
	enemies = get_tree().get_nodes_in_group("enemy")
	_calculate_danger()

func _calculate_danger():
	var danger_value: float = 0.0
	
	if enemies.is_empty():
		var current_danger = dynamic_qualities.get("peligro", 0.0)
		danger_value = max(0.0, current_danger - danger_decay_rate * update_interval)
	else:
		var max_danger_from_enemies: float = 0.0
		
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			
			var distance = global_position.distance_to(enemy.global_position)
			
			if distance <= danger_detection_radius:
				var normalized_distance = distance / danger_detection_radius
				var enemy_danger = (1.0 - normalized_distance) * max_danger_value
				max_danger_from_enemies = max(max_danger_from_enemies, enemy_danger)
		
		if max_danger_from_enemies > 0.0:
			danger_value = max_danger_from_enemies
		else:
			var current_danger = dynamic_qualities.get("peligro", 0.0)
			danger_value = max(0.0, current_danger - danger_decay_rate * update_interval)
	
	danger_value = clamp(danger_value, 0.0, max_danger_value)
	dynamic_qualities["peligro"] = danger_value

func _draw_connections():
	if connected_locations.is_empty():
		return
	
	for connected_location in connected_locations:
		if not is_instance_valid(connected_location):
			continue
		
		var start_pos = Vector2.ZERO
		var end_pos = to_local(connected_location.global_position)
		
		draw_line(start_pos, end_pos, connection_color, 2.0)

func _generate_unique_id() -> int:
	return hash(get_path())

func get_static_quality(quality_name: String) -> float:
	return static_qualities.get(quality_name, 0.0)

func get_dynamic_quality(quality_name: String) -> float:
	return dynamic_qualities.get(quality_name, 0.0)

func set_static_quality(quality_name: String, value: float):
	static_qualities[quality_name] = clamp(value, 0.0, 1.0)

func set_dynamic_quality(quality_name: String, value: float):
	dynamic_qualities[quality_name] = clamp(value, 0.0, 1.0)

func add_connection(location: Node):
	if location == self:
		return
	
	if not connected_locations.has(location):
		connected_locations.append(location)

func remove_connection(location: Node):
	connected_locations.erase(location)

func get_all_qualities() -> Dictionary:
	var all_qualities = static_qualities.duplicate()
	all_qualities.merge(dynamic_qualities)
	return all_qualities

func get_debug_info() -> String:
	var info = "Tactical Location ID: %d\n" % node_id
	info += "Position: %s\n" % str(global_position)
	info += "Static Qualities: %s\n" % str(static_qualities)
	info += "Dynamic Qualities: %s\n" % str(dynamic_qualities)
	info += "Connections: %d\n" % connected_locations.size()
	return info
