extends Node
class_name PathfindingAStar

var navigation_polygons: Array[PackedVector2Array] = []
var polygon_centers: Array[Vector2] = []
var navigation_region: NavigationRegion2D = null

func initialize(nav_region: NavigationRegion2D):
	navigation_region = nav_region
	if not navigation_region:
		push_error("NavigationRegion2D no encontrado")
		return
	
	_extract_navigation_polygons()
	_calculate_polygon_centers()

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

