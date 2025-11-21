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

func get_nearest_center(position: Vector2) -> Vector2:
	if polygon_centers.is_empty():
		return position
	
	var nearest_center = polygon_centers[0]
	var min_distance = position.distance_to(nearest_center)
	
	for center in polygon_centers:
		var distance = position.distance_to(center)
		if distance < min_distance:
			min_distance = distance
			nearest_center = center
	
	return nearest_center

