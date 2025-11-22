extends Node
class_name PathfindingAStar

var navigation_polygons: Array[PackedVector2Array] = []
var polygon_centers: Array[Vector2] = []
var edges: Array[Array] = []
var navigation_region: NavigationRegion2D = null
var space_state: PhysicsDirectSpaceState2D = null

func initialize(nav_region: NavigationRegion2D):
	navigation_region = nav_region
	if not navigation_region:
		push_error("NavigationRegion2D no encontrado")
		return
	
	_extract_navigation_polygons()
	_calculate_polygon_centers()
	_build_graph()

func _extract_navigation_polygons():
	navigation_polygons.clear()
	
	if not navigation_region:
		return
	
	var nav_poly = navigation_region.navigation_polygon
	if not nav_poly:
		push_error("NavigationPolygon no encontrado en NavigationRegion2D")
		return
	print(nav_poly.get_polygon_count())
	
	for i in range(nav_poly.get_polygon_count()):
		var polygon_indices = nav_poly.get_polygon(i)
		var polygon_points: PackedVector2Array = PackedVector2Array()
		
		for index in polygon_indices:
			var vertex = nav_poly.get_vertices()[index]
			var global_pos = navigation_region.to_global(vertex)
			polygon_points.append(global_pos)
		
		navigation_polygons.append(polygon_points)
	
	print("Polígonos extraídos: ", navigation_polygons.size())

func _calculate_polygon_centers():
	polygon_centers.clear()
	
	for polygon in navigation_polygons:
		if polygon.size() == 0:
			continue
		
		var center = _calculate_centroid(polygon)
		polygon_centers.append(center)
	
	print("Centros de polígonos calculados: ", polygon_centers.size())

func _calculate_centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.size() == 0:
		return Vector2.ZERO
	
	var sum = Vector2.ZERO
	for point in polygon:
		sum += point
	
	return sum / polygon.size()

func _build_graph():
	edges.clear()
	
	if not navigation_region or not navigation_region.is_inside_tree():
		return
	
	space_state = navigation_region.get_world_2d().direct_space_state
	
	for i in range(polygon_centers.size()):
		for j in range(i + 1, polygon_centers.size()):
			if _are_polygons_adjacent(i, j) and _can_connect(polygon_centers[i], polygon_centers[j]):
				edges.append([i, j])
	
	print("Aristas creadas: ", edges.size())

func _are_polygons_adjacent(poly_a_index: int, poly_b_index: int) -> bool:
	var poly_a = navigation_polygons[poly_a_index]
	var poly_b = navigation_polygons[poly_b_index]
	
	var shared_vertices = 0
	for vertex_a in poly_a:
		for vertex_b in poly_b:
			if vertex_a.distance_to(vertex_b) < 1.0:
				shared_vertices += 1
				if shared_vertices >= 2:
					return true
	
	return false

func _can_connect(from: Vector2, to: Vector2) -> bool:
	if not space_state:
		return true
	
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	query.exclude = []
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func draw_edges(canvas: CanvasItem):
	for edge in edges:
		var from = polygon_centers[edge[0]]
		var to = polygon_centers[edge[1]]
		var local_from = canvas.to_local(from)
		var local_to = canvas.to_local(to)
		canvas.draw_line(local_from, local_to, Color.BLACK, 2.0)

func draw_polygon_centers(canvas: CanvasItem):
	for center in polygon_centers:
		var local_pos = canvas.to_local(center)
		canvas.draw_circle(local_pos, 15.0, Color.RED)
		canvas.draw_arc(local_pos, 15.0, 0, TAU, 32, Color.WHITE, 2.0)

func get_polygon_centers() -> Array[Vector2]:
	return polygon_centers

func get_nearest_center_index(position: Vector2) -> int:
	if polygon_centers.is_empty():
		return -1
	
	var nearest_index = 0
	var min_distance = position.distance_to(polygon_centers[0])
	
	for i in range(polygon_centers.size()):
		var distance = position.distance_to(polygon_centers[i])
		if distance < min_distance:
			min_distance = distance
			nearest_index = i
	
	return nearest_index

func get_neighbors(node_index: int) -> Array[int]:
	var neighbors: Array[int] = []
	
	for edge in edges:
		if edge[0] == node_index:
			neighbors.append(edge[1])
		elif edge[1] == node_index:
			neighbors.append(edge[0])
	
	return neighbors

func find_path(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var start_index = get_nearest_center_index(start_pos)
	var end_index = get_nearest_center_index(end_pos)
	
	if start_index == -1 or end_index == -1:
		return []
	
	if start_index == end_index:
		return [end_pos]
	
	var open_set: Array[int] = [start_index]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	
	for i in range(polygon_centers.size()):
		g_score[i] = INF
		f_score[i] = INF
	
	g_score[start_index] = 0
	f_score[start_index] = _heuristic(start_index, end_index)
	
	while not open_set.is_empty():
		var current = _get_lowest_f_score(open_set, f_score)
		
		if current == end_index:
			var path = _reconstruct_path(came_from, current)
			path.append(end_pos)
			return path
		
		open_set.erase(current)
		
		for neighbor in get_neighbors(current):
			var tentative_g_score = g_score[current] + polygon_centers[current].distance_to(polygon_centers[neighbor])
			
			if tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = g_score[neighbor] + _heuristic(neighbor, end_index)
				
				if not open_set.has(neighbor):
					open_set.append(neighbor)
	
	return []

func _heuristic(from_index: int, to_index: int) -> float:
	return polygon_centers[from_index].distance_to(polygon_centers[to_index])

func _get_lowest_f_score(open_set: Array[int], f_score: Dictionary) -> int:
	var lowest = open_set[0]
	var lowest_score = f_score[lowest]
	
	for node in open_set:
		if f_score[node] < lowest_score:
			lowest = node
			lowest_score = f_score[node]
	
	return lowest

func _reconstruct_path(came_from: Dictionary, current: int) -> Array[Vector2]:
	var path: Array[Vector2] = [polygon_centers[current]]
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(polygon_centers[current])
	
	return path

