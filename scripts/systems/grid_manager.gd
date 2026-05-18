extends Node

const TILE_SIZE: int = 64
const GRID_WIDTH: int = 16
const GRID_HEIGHT: int = 9
const GRID_OFFSET_X: int = 128
const GRID_OFFSET_Y: int = 72

var _occupancy: Dictionary = {}
var _entity_tiles: Dictionary = {}


func _ready() -> void:
	clear_all()


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_x: float = world_pos.x - GRID_OFFSET_X
	var local_y: float = world_pos.y - GRID_OFFSET_Y
	var gx: int = int(floor(local_x / TILE_SIZE))
	var gy: int = int(floor(local_y / TILE_SIZE))
	return Vector2i(gx, gy)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * TILE_SIZE + TILE_SIZE / 2 + GRID_OFFSET_X,
		grid_pos.y * TILE_SIZE + TILE_SIZE / 2 + GRID_OFFSET_Y
	)


func snap_to_grid(world_pos: Vector2) -> Vector2:
	return grid_to_world(world_to_grid(world_pos))


func is_valid(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT


func is_occupied(grid_pos: Vector2i) -> bool:
	return _occupancy.has(occupancy_key(grid_pos))


func occupancy_key(grid_pos: Vector2i) -> String:
	return str(grid_pos.x) + "," + str(grid_pos.y)


func occupy(grid_pos: Vector2i, entity: Node2D) -> void:
	if not is_valid(grid_pos):
		return
	var key: String = occupancy_key(grid_pos)
	_occupancy[key] = entity
	_entity_tiles[entity] = grid_pos


func occupy_rect(top_left: Vector2i, size: Vector2i, entity: Node2D) -> void:
	for x in range(top_left.x, top_left.x + size.x):
		for y in range(top_left.y, top_left.y + size.y):
			var pos: Vector2i = Vector2i(x, y)
			if is_valid(pos):
				_occupancy[occupancy_key(pos)] = entity
	_entity_tiles[entity] = top_left


func vacate(grid_pos: Vector2i) -> void:
	var key: String = occupancy_key(grid_pos)
	if _occupancy.has(key):
		_occupancy.erase(key)


func vacate_entity(entity: Node2D) -> void:
	var to_erase: Array[String] = []
	for key: String in _occupancy:
		if _occupancy[key] == entity:
			to_erase.append(key)
	for key: String in to_erase:
		_occupancy.erase(key)
	if _entity_tiles.has(entity):
		_entity_tiles.erase(entity)


func get_occupant(grid_pos: Vector2i):
	var key: String = occupancy_key(grid_pos)
	return _occupancy.get(key, null)


func get_entity_grid_pos(entity: Node2D) -> Vector2i:
	return _entity_tiles.get(entity, Vector2i(-1, -1))


func clear_all() -> void:
	_occupancy.clear()
	_entity_tiles.clear()


func is_tile_walkable(grid_pos: Vector2i) -> bool:
	if not is_valid(grid_pos):
		return false
	var occupant = _occupancy.get(occupancy_key(grid_pos))
	if occupant and occupant.is_in_group("buildings"):
		return false
	return true


func update_entity_position(entity: Node2D, old_world: Vector2, new_world: Vector2) -> void:
	var old_grid: Vector2i = world_to_grid(old_world)
	var new_grid: Vector2i = world_to_grid(new_world)
	if old_grid == new_grid:
		return
	vacate(old_grid)
	occupy(new_grid, entity)


func find_path(from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
	var from: Vector2i = world_to_grid(from_world)
	var to: Vector2i = world_to_grid(to_world)

	if not is_valid(from) or not is_tile_walkable(from):
		var nearest_from: Vector2i = _find_nearest_walkable(from)
		if nearest_from != Vector2i(-1, -1):
			from = nearest_from
		else:
			return []

	if not is_tile_walkable(to):
		var nearest_to: Vector2i = _find_nearest_walkable(to)
		if nearest_to != Vector2i(-1, -1):
			to = nearest_to
		else:
			return []

	if from == to:
		return [grid_to_world(to)]

	var path_grid: Array[Vector2i] = _astar(from, to)
	if path_grid.is_empty():
		return []

	var path_world: Array[Vector2] = []
	for g in path_grid:
		path_world.append(grid_to_world(g))
	return path_world


func find_nearest_empty(start: Vector2i) -> Vector2i:
	if is_valid(start) and not is_occupied(start):
		return start

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[occupancy_key(start)] = true
	var front: int = 0

	while front < queue.size():
		var current: Vector2i = queue[front]
		front += 1
		for neighbor in _get_cardinal_neighbors(current):
			var key: String = occupancy_key(neighbor)
			if key in visited:
				continue
			if not is_valid(neighbor):
				continue
			visited[key] = true
			if is_valid(neighbor) and not is_occupied(neighbor):
				return neighbor
			queue.append(neighbor)
	return Vector2i(-1, -1)


func _find_nearest_walkable(start: Vector2i) -> Vector2i:
	if is_tile_walkable(start):
		return start

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[occupancy_key(start)] = true
	var front: int = 0

	while front < queue.size():
		var current: Vector2i = queue[front]
		front += 1
		for neighbor in _get_cardinal_neighbors(current):
			var key: String = occupancy_key(neighbor)
			if key in visited:
				continue
			if not is_valid(neighbor):
				continue
			visited[key] = true
			if is_tile_walkable(neighbor):
				return neighbor
			queue.append(neighbor)
	return Vector2i(-1, -1)


func _astar(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var open_set: Array[Vector2i] = [from]
	var closed_set: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	var key_from: String = occupancy_key(from)
	g_score[key_from] = 0
	f_score[key_from] = _manhattan(from, to)
	var in_open: Dictionary = {}
	in_open[key_from] = true

	while not open_set.is_empty():
		var current: Vector2i = _pop_lowest_f(open_set, f_score)
		var key_c: String = occupancy_key(current)

		if key_c in closed_set:
			continue
		closed_set[key_c] = true

		if current == to:
			return _reconstruct_path(came_from, current)

		for neighbor in _get_cardinal_neighbors(current):
			var key_n: String = occupancy_key(neighbor)
			if key_n in closed_set:
				continue
			if not is_tile_walkable(neighbor):
				continue

			var tentative_g: int = g_score.get(key_c, INF) + 1
			if tentative_g < g_score.get(key_n, INF):
				came_from[key_n] = current
				g_score[key_n] = tentative_g
				f_score[key_n] = tentative_g + _manhattan(neighbor, to)
				if not in_open.has(key_n):
					open_set.append(neighbor)
					in_open[key_n] = true
	return []


func _pop_lowest_f(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var best: Vector2i = open_set[0]
	var best_f: float = f_score.get(occupancy_key(best), INF)
	for i in range(1, open_set.size()):
		var f: float = f_score.get(occupancy_key(open_set[i]), INF)
		if f < best_f:
			best = open_set[i]
			best_f = f
	open_set.erase(best)
	return best


func _get_cardinal_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(grid_pos.x + 1, grid_pos.y),
		Vector2i(grid_pos.x - 1, grid_pos.y),
		Vector2i(grid_pos.x, grid_pos.y + 1),
		Vector2i(grid_pos.x, grid_pos.y - 1),
	]


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var key: String = occupancy_key(current)
	while came_from.has(key):
		current = came_from[key]
		key = occupancy_key(current)
		path.append(current)
	path.reverse()
	return path
