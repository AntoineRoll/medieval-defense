class_name Enemy
extends CharacterBody2D

enum State { IDLE, CHASING, ATTACKING }

signal enemy_died
signal reached_base

@export var max_hp: int = 50
@export var speed: float = 64.0

var current_hp: int = 50
var base_position: Vector2 = Vector2.ZERO
var attack_range: float = 64.0
var attack_damage: int = 10
var attack_cooldown: float = 1.0
var detection_radius: float = 1216.0

var _state: State = State.IDLE
var _move_dir: Vector2 = Vector2.ZERO
var _dead: bool = false
var _current_target: Node2D = null
var _attack_timer: float = 0.0
var _reported_reached_base: bool = false
var _path: Array[Vector2] = []
var _path_index: int = 0

var hitbox_radius: float = 32.0
var debug_show_hitbox: bool = true

@onready var health_bar: ProgressBar = $HealthBar
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _detection_area: DetectionArea = $DetectionArea


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	_detection_area.set_radius(detection_radius)
	_detection_area.target_detected.connect(_on_target_detected)
	_detection_area.target_lost.connect(_on_target_lost)
	_hurtbox.hurt.connect(_on_hurt)
	queue_redraw()


func _on_target_detected(body: Node2D) -> void:
	if _current_target == null and _state != State.ATTACKING:
		_current_target = body
		_state = State.CHASING


func _on_target_lost(body: Node2D) -> void:
	if _current_target == body:
		_current_target = null
		_state = State.IDLE


func _draw() -> void:
	if debug_show_hitbox:
		draw_arc(Vector2(0, 0), hitbox_radius, 0, TAU, 64, Color.BLACK, 1.0)
	draw_circle(Vector2(0, 0), 12, Color(0.8, 0.2, 0.2))


func find_best_target() -> Node2D:
	var unit_target: Node2D = _detection_area.get_closest(global_position)
	if unit_target:
		return unit_target

	var best_target: Node2D = null
	var best_dist: float = detection_radius
	var buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		var building_node: Node2D = building as Node2D
		if not building_node:
			continue
		var dist: float = global_position.distance_to(building_node.global_position)
		if dist <= detection_radius and dist < best_dist:
			best_target = building_node
			best_dist = dist

	return best_target


func get_unit_type() -> int:
	return Unit.UnitType.FOOT_SOLDIER


func _physics_process(delta: float) -> void:
	if _dead:
		return

	var old_pos: Vector2 = global_position

	match _state:
		State.IDLE:
			_tick_idle(delta)
		State.CHASING:
			_tick_chasing(delta)
		State.ATTACKING:
			_tick_attacking(delta)

	if _move_dir == Vector2.ZERO and _state != State.ATTACKING:
		if not _dead and base_position != Vector2.ZERO and global_position.distance_to(base_position) > attack_range:
			_move_dir = (base_position - global_position).normalized()

	velocity = _move_dir * speed
	move_and_slide()
	_push_apart()

	var new_pos: Vector2 = global_position
	if old_pos != new_pos:
		GridManager.update_entity_position(self, old_pos, new_pos)


func _tick_idle(delta: float) -> void:
	var best_target: Node2D = find_best_target()
	if best_target:
		_current_target = best_target
		_path = []
		_state = State.CHASING
		_move_dir = (_current_target.global_position - global_position).normalized()
		return

	var dist_to_base: float = global_position.distance_to(base_position)
	if dist_to_base <= attack_range:
		_move_dir = Vector2.ZERO
		if not _dead and not _reported_reached_base:
			_reported_reached_base = true
			EventBus.enemy_reached_base.emit(self)
			reached_base.emit()
		return

	if _path.is_empty() or _path_index >= _path.size():
		_path = GridManager.find_path(global_position, base_position)
		_path_index = 0

	if not _follow_path(delta):
		_move_dir = (base_position - global_position).normalized()


func _tick_chasing(delta: float) -> void:
	if not is_instance_valid(_current_target):
		_current_target = null
		_state = State.IDLE
		return

	var best_target: Node2D = find_best_target()
	if best_target and best_target != _current_target:
		_current_target = best_target

	var dist: float = global_position.distance_to(_current_target.global_position)
	if dist <= attack_range:
		_attack_timer = attack_cooldown
		_apply_attack()
		_state = State.ATTACKING
		return

	var target_grid: Vector2i = GridManager.world_to_grid(_current_target.global_position)
	var path_end: Vector2i = GridManager.world_to_grid(_path[_path.size() - 1]) if _path.size() > 0 else Vector2i(-1, -1)
	if _path.is_empty() or _path_index >= _path.size() or target_grid != path_end:
		_path = GridManager.find_path(global_position, _current_target.global_position)
		_path_index = 0

	if not _follow_path(delta):
		_move_dir = (_current_target.global_position - global_position).normalized()


func _tick_attacking(delta: float) -> void:
	if not is_instance_valid(_current_target):
		_current_target = null
		_state = State.IDLE
		return

	var dist: float = global_position.distance_to(_current_target.global_position)
	if dist > attack_range:
		_state = State.CHASING
		_move_dir = (_current_target.global_position - global_position).normalized()
		return

	_move_dir = Vector2.ZERO
	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		_apply_attack()


func _apply_attack() -> void:
	if not _current_target or not _current_target.has_method("take_damage"):
		return
	print("DAMAGE: Enemy deals ", attack_damage, " to ", _current_target.name, " at ", Vector2i(_current_target.global_position))
	_current_target.take_damage(attack_damage)


func _push_apart() -> void:
	_check_base_push()


func _check_base_push() -> void:
	if _current_target != null:
		return
	var base_nodes: Array[Node] = get_tree().get_nodes_in_group("buildings")
	for base_node in base_nodes:
		if not base_node.has_method("get_hitbox_radius"):
			continue
		var base_half: float = base_node.get_hitbox_radius()
		var dx: float = abs(global_position.x - base_node.global_position.x)
		var dy: float = abs(global_position.y - base_node.global_position.y)
		var overlap_x: float = (hitbox_radius + base_half) - dx
		var overlap_y: float = (hitbox_radius + base_half) - dy
		if overlap_x > 0 and overlap_y > 0:
			var push: Vector2 = Vector2.ZERO
			if overlap_x < overlap_y:
				push.x = sign(global_position.x - base_node.global_position.x) * overlap_x * 0.5
			else:
				push.y = sign(global_position.y - base_node.global_position.y) * overlap_y * 0.5
			global_position += push


func _on_hurt(hitbox: Area2D) -> void:
	if hitbox is Hitbox and not hitbox.is_friendly_hit():
		return
	var src: String = "unknown"
	if hitbox.get_parent():
		src = hitbox.get_parent().name
	print("DAMAGE: Enemy at ", Vector2i(global_position), " hit by ", src, " for ", hitbox.damage)
	take_damage(hitbox.damage)


func take_damage(amount: int) -> void:
	if _dead:
		return
	current_hp -= amount
	print("DAMAGE: Enemy at ", Vector2i(global_position), " took ", amount, " HP: ", current_hp, "/", max_hp)
	if health_bar:
		health_bar.visible = true
		health_bar.value = float(current_hp) / float(max_hp) * 100
	if current_hp <= 0:
		die()


func die() -> void:
	_dead = true
	EventBus.enemy_died.emit(self)
	enemy_died.emit()
	ObjectPool.return_to_pool(self)


func reset_pooled() -> void:
	_dead = false
	_state = State.IDLE
	_move_dir = Vector2.ZERO
	_current_target = null
	_attack_timer = 0.0
	_reported_reached_base = false
	health_bar.visible = false
	health_bar.value = 100
	_detection_area.clear()
	collision_layer = 4
	collision_mask = 0
	visible = true
	process_mode = PROCESS_MODE_INHERIT
	_hurtbox.monitoring = true
	_hurtbox.monitorable = true
	_detection_area.monitoring = true
	_detection_area.monitorable = true


func _follow_path(delta: float) -> bool:
	if _path_index >= _path.size():
		return false
	var waypoint: Vector2 = _path[_path_index]
	var d: float = global_position.distance_to(waypoint)
	if d < speed * delta:
		_path_index += 1
		if _path_index >= _path.size():
			return false
		waypoint = _path[_path_index]
	_move_dir = (waypoint - global_position).normalized()
	return true


func set_base_position(pos: Vector2) -> void:
	base_position = pos


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp
