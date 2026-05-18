class_name DetectionArea
extends Area2D

signal target_detected(body: Node2D)
signal target_lost(body: Node2D)

var _bodies: Array[Node2D] = []

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_init_overlapping_bodies")


func _init_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		if body not in _bodies:
			_bodies.append(body)
			target_detected.emit(body)


func _on_body_entered(body: Node2D) -> void:
	if body not in _bodies:
		_bodies.append(body)
		target_detected.emit(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
	target_lost.emit(body)


func get_closest(from_position: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_dist_sq: float = INF
	var stale: Array[Node2D] = []
	for body in _bodies:
		if is_instance_valid(body):
			var d: float = from_position.distance_squared_to(body.global_position)
			if d < closest_dist_sq:
				closest_dist_sq = d
				closest = body
		else:
			stale.append(body)
	for body in stale:
		_bodies.erase(body)
	if not closest:
		for body in get_overlapping_bodies():
			if is_instance_valid(body):
				var d: float = from_position.distance_squared_to(body.global_position)
				if d < closest_dist_sq:
					closest_dist_sq = d
					closest = body
	return closest


func has_targets() -> bool:
	for body in _bodies:
		if is_instance_valid(body):
			return true
	return false


func clear() -> void:
	_bodies.clear()


func set_radius(radius: float) -> void:
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		_collision_shape.shape.radius = radius
