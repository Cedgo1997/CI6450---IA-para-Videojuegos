extends Node2D

const TacticalLocation = preload("res://Tactics/tactical_location.gd")

@onready var tactical_locations_container: Node2D = $TacticalLocations
@onready var connections_visualizer: Node2D = $ConnectionsVisualizer

var tactical_locations: Array[Node] = []
var graph: Dictionary = {}
var location_by_id: Dictionary = {}

@export_group("Update Settings")
@export var update_interval: float = 0.1
var update_timer: float = 0.0

@export_group("Visualization")
@export var show_graph: bool = true
@export var node_color: Color = Color(0.0, 1.0, 0.0, 0.8)
@export var connection_color: Color = Color(1.0, 1.0, 0.0, 0.5)
@export var node_radius: float = 10.0
@export var connection_width: float = 2.0

func _ready():
	_initialize_tactical_locations()
	_precalculate_connections()
	
	if tactical_locations.size() < 10:
		push_warning("TacticalGraph: Se recomienda tener al menos 10 ubicaciones tácticas. Actualmente tiene %d" % tactical_locations.size())

func _process(delta):
	update_timer -= delta
	if update_timer <= 0.0:
		_update_all_dynamic_qualities()
		update_timer = update_interval
	
	if show_graph:
		queue_redraw()

func _draw():
	if show_graph:
		_draw_graph()

func _initialize_tactical_locations():
	tactical_locations.clear()
	location_by_id.clear()
	
	if not tactical_locations_container:
		push_error("TacticalGraph: No se encontró el nodo TacticalLocations")
		return
	
	for child in tactical_locations_container.get_children():
		if child.has_method("calculate_tactical_value"):
			tactical_locations.append(child)
			var location = child as TacticalLocation
			if location:
				location_by_id[location.node_id] = location

func _precalculate_connections():
	graph.clear()
	
	for location in tactical_locations:
		if not is_instance_valid(location):
			continue
		
		if not location.has_method("calculate_tactical_value"):
			continue
		
		var location_node = location as TacticalLocation
		if not location_node:
			continue
		
		var node_id = location_node.node_id
		var connected_ids: Array[int] = []
		
		for connected_location in location_node.connected_locations:
			if not is_instance_valid(connected_location):
				continue
			
			if connected_location.has_method("calculate_tactical_value"):
				var connected_node = connected_location as TacticalLocation
				if connected_node:
					connected_ids.append(connected_node.node_id)
		
		graph[node_id] = connected_ids

func _update_all_dynamic_qualities():
	for location in tactical_locations:
		if not is_instance_valid(location):
			continue
		
		if location.has_method("update_dynamic_qualities"):
			location.update_dynamic_qualities()

func find_nearest_location(position: Vector2) -> TacticalLocation:
	if tactical_locations.is_empty():
		return null
	
	var nearest_location: TacticalLocation = null
	var min_distance: float = INF
	
	for location in tactical_locations:
		if not is_instance_valid(location):
			continue
		
		if not location.has_method("calculate_tactical_value"):
			continue
		
		var location_node = location as TacticalLocation
		if not location_node:
			continue
		
		var distance = position.distance_to(location_node.global_position)
		
		if distance < min_distance:
			min_distance = distance
			nearest_location = location_node
	
	return nearest_location

func get_path_tactical_value(path: Array, weights: Dictionary) -> float:
	var total_value: float = 0.0
	
	for node_id in path:
		if not location_by_id.has(node_id):
			continue
		
		var location: TacticalLocation = location_by_id[node_id]
		if not is_instance_valid(location):
			continue
		
		total_value += location.calculate_tactical_value(weights)
	
	return total_value

func _draw_graph():
	for location in tactical_locations:
		if not is_instance_valid(location):
			continue
		
		if not location.has_method("calculate_tactical_value"):
			continue
		
		var location_node = location as TacticalLocation
		if not location_node:
			continue
		
		var node_id = location_node.node_id
		var node_pos = to_local(location_node.global_position)
		
		draw_circle(node_pos, node_radius, node_color)
		
		if graph.has(node_id):
			var connected_ids = graph[node_id]
			for connected_id in connected_ids:
				if not location_by_id.has(connected_id):
					continue
				
				var connected_location = location_by_id[connected_id] as TacticalLocation
				if not is_instance_valid(connected_location):
					continue
				
				var connected_pos = to_local(connected_location.global_position)
				draw_line(node_pos, connected_pos, connection_color, connection_width)

func get_location_by_id(node_id: int) -> TacticalLocation:
	if location_by_id.has(node_id):
		return location_by_id[node_id]
	return null

func get_all_locations() -> Array[Node]:
	return tactical_locations.duplicate()

func get_graph() -> Dictionary:
	return graph.duplicate()

func rebuild_connections():
	_precalculate_connections()

func get_locations_in_radius(center: Vector2, radius: float) -> Array[Node]:
	var locations_in_radius: Array[Node] = []
	
	for location in tactical_locations:
		if not is_instance_valid(location):
			continue
		
		if not location.has_method("calculate_tactical_value"):
			continue
		
		var location_node = location as TacticalLocation
		if not location_node:
			continue
		
		var distance = center.distance_to(location_node.global_position)
		
		if distance <= radius:
			locations_in_radius.append(location_node)
	
	return locations_in_radius
