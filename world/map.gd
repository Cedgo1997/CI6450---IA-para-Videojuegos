extends Node2D

const PathfindingAStar = preload("res://scripts/pathfinding_astar.gd")

var pathfinding: PathfindingAStar = null

func _ready():
	add_to_group("map")
	pathfinding = PathfindingAStar.new()
	var nav_region = _find_navigation_region(self)
	
	if nav_region:
		pathfinding.initialize(nav_region)
		queue_redraw()
	else:
		push_error("No se encontró NavigationRegion2D en la escena")

func _find_navigation_region(node: Node) -> NavigationRegion2D:
	if node is NavigationRegion2D:
		return node
	
	for child in node.get_children():
		var result = _find_navigation_region(child)
		if result:
			return result
	
	return null

func _draw():
	if pathfinding and pathfinding.polygon_centers.size() > 0:
		pathfinding.draw_edges(self)
		pathfinding.draw_polygon_centers(self)
