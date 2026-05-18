class_name Unit
extends CharacterBody2D

enum UnitType { FOOT_SOLDIER, ARCHER, CAVALRY }
enum State { IDLE, MOVING, CHASING, ATTACKING }

signal selected_changed(unit: Node2D, is_selected: bool)

@export var unit_stats: Resource
@export var click_radius: float = 32.0

var unit_type: UnitType
var speed: float
var detection_radius: float
var attack_range: float
var attack_damage: int
var attack_cooldown: float
var is_ranged: bool
var max_hp: int
var current_hp: int
var selected: bool = false
var hovered: bool = false
var target_position: Vector2 = Vector2.ZERO
var base_position: Vector2 = Vector2.ZERO

var _state: State = State.IDLE
var _move_dir: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0
var _current_target: Node2D = null
var _auto_engaging: bool = true
var _returning_to_base: bool = false
var _dead: bool = false

var hitbox_radius: float = 32.0
var debug_show_hitbox: bool = true

var _path: Array[Vector2] = []
var _path_index: int = 0
var _last_grid_pos: Vector2i = Vector2i(-1, -1)

@onready var sprite: Sprite2D = $Sprite
@onready var selection_indicator: Sprite2D = $SelectionIndicator
@onready var health_bar: ProgressBar = $HealthBar
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _detection_area: DetectionArea = $DetectionArea


func setup_stats(new_max_hp: int, new_speed: float, new_detection_radius: float, new_attack_range: float, new_attack_damage: int, new_attack_cooldown: float, new_is_ranged: bool = false) -> void:
	max_hp = new_max_hp
	current_hp = new_max_hp
	speed = new_speed
	detection_radius = new_detection_radius
	attack_range = new_attack_range
	attack_damage = new_attack_damage
	attack_cooldown = new_attack_cooldown
	is_ranged = new_is_ranged
	_refresh_health_bar()
	_detection_area.set_radius(detection_radius)


func _init_stats_from_resource() -> void:
	if not unit_stats:
		return
	var s: Resource = unit_stats
	max_hp = s.get("max_hp") if "max_hp" in s else 50
	current_hp = max_hp
	speed = s.get("speed") if "speed" in s else 64.0
	detection_radius = s.get("detection_radius") if "detection_radius" in s else 384.0
	attack_range = s.get("attack_range") if "attack_range" in s else 64.0
	attack_damage = s.get("attack_damage") if "attack_damage" in s else 10
	attack_cooldown = s.get("attack_cooldown") if "attack_cooldown" in s else 1.0
	is_ranged = s.get("is_ranged") if "is_ranged" in s else false


func _ready() -> void:
	_init_stats_from_resource()
	current_hp = max_hp
	add_to_group("units")
	_refresh_health_bar()
	_detection_area.set_radius(detection_radius)
	_hurtbox.hurt.connect(_on_hurt)
	EventBus.enemy_died.connect(_on_enemy_died)


func apply_bonus(mult: float) -> void:
	max_hp = int(max_hp * mult)
	current_hp = max_hp
	attack_damage = int(attack_damage * mult)
	_refresh_health_bar()


func _refresh_health_bar() -> void:
	if not health_bar:
		return
	health_bar.visible = current_hp < max_hp
	health_bar.value = float(current_hp) / float(max_hp) * 100
	var ratio: float = float(current_hp) / float(max_hp)
	if ratio > 0.6:
		health_bar.modulate = Color(0, 1, 0)
	elif ratio > 0.25:
		health_bar.modulate = Color(1, 1, 0)
	else:
		health_bar.modulate = Color(1, 0, 0)


func is_clicked(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var diff: Vector2 = get_global_mouse_position() - global_position
		return abs(diff.x) < click_radius and abs(diff.y) < click_radius
	return false


func set_base_position(pos: Vector2) -> bool:
	if not _is_base_position_valid(pos):
		return false
	base_position = pos
	if base_position != Vector2.ZERO and position == Vector2.ZERO:
		position = base_position
	if _current_target == null:
		_return_to_base()
	return true


func _is_base_position_valid(pos: Vector2) -> bool:
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.has_method("get_hitbox_radius"):
			var building_r: float = building.get_hitbox_radius()
			var dx: float = abs(pos.x - building.global_position.x)
			var dy: float = abs(pos.y - building.global_position.y)
			if dx < hitbox_radius + building_r and dy < hitbox_radius + building_r:
				return false
	for other in get_tree().get_nodes_in_group("units"):
		if other == self:
			continue
		var other_unit: Node2D = other as Node2D
		if not other_unit:
			continue
		var other_radius: float = other_unit.get("hitbox_radius") if "hitbox_radius" in other_unit else 32.0
		var other_base: Vector2 = other_unit.get("base_position") if "base_position" in other_unit else Vector2.ZERO
		if other_base != Vector2.ZERO:
			var dx: float = abs(pos.x - other_base.x)
			var dy: float = abs(pos.y - other_base.y)
			if dx < hitbox_radius + other_radius and dy < hitbox_radius + other_radius:
				return false
	return true


func move_to(pos: Vector2) -> void:
	target_position = pos
	_returning_to_base = false
	_state = State.MOVING


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


func _return_to_base() -> void:
	if base_position != Vector2.ZERO and global_position.distance_to(base_position) > 5:
		target_position = base_position
		_returning_to_base = true
		_auto_engaging = false
		_path = []
		_path_index = 0
		_state = State.MOVING


func _physics_process(delta: float) -> void:
	if _current_target != null and not is_instance_valid(_current_target):
		_current_target = null

	var old_pos: Vector2 = global_position

	match _state:
		State.IDLE:
			_tick_idle(delta)
		State.MOVING:
			_tick_moving(delta)
		State.CHASING:
			_tick_chasing(delta)
		State.ATTACKING:
			_tick_attacking(delta)

	if _move_dir.x != 0:
		sprite.flip_h = _move_dir.x < 0
		selection_indicator.flip_h = _move_dir.x < 0

	velocity = _move_dir * speed
	move_and_slide()

	if _state != State.ATTACKING:
		_push_apart()

	var new_pos: Vector2 = global_position
	if old_pos != new_pos:
		GridManager.update_entity_position(self, old_pos, new_pos)


func _tick_idle(delta: float) -> void:
	_move_dir = Vector2.ZERO
	if _auto_engaging:
		_find_target_from_detection()
		if _current_target:
			_state = State.CHASING
			_move_dir = (_current_target.global_position - global_position).normalized()
			return
	if not _returning_to_base and base_position != Vector2.ZERO and global_position.distance_to(base_position) > 5:
		_return_to_base()


func _tick_moving(delta: float) -> void:
	if target_position == Vector2.ZERO:
		_state = State.IDLE
		return

	var dist: float = global_position.distance_to(target_position)
	if dist < speed * delta:
		global_position = target_position
		target_position = Vector2.ZERO
		_move_dir = Vector2.ZERO
		if _returning_to_base:
			_returning_to_base = false
			_auto_engaging = true
		_state = State.IDLE
		if _auto_engaging:
			_find_target_from_detection()
			if _current_target:
				_state = State.CHASING
				_move_dir = (_current_target.global_position - global_position).normalized()
		return

	if _path.is_empty() or _path_index >= _path.size():
		_path = GridManager.find_path(global_position, target_position)
		_path_index = 0

	if not _follow_path(delta):
		_move_dir = (target_position - global_position).normalized()

	if _auto_engaging:
		_find_target_from_detection()
		if _current_target:
			target_position = Vector2.ZERO
			_state = State.CHASING
			_move_dir = (_current_target.global_position - global_position).normalized()


func _tick_chasing(delta: float) -> void:
	if not is_instance_valid(_current_target):
		_current_target = null
		_state = State.MOVING if target_position != Vector2.ZERO else State.IDLE
		return

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
		_move_dir = Vector2.ZERO
		_state = State.IDLE
		return

	var dist: float = global_position.distance_to(_current_target.global_position)
	if dist > attack_range:
		_state = State.CHASING
		_move_dir = (_current_target.global_position - global_position).normalized()
		return

	var dir_to_target: Vector2 = _current_target.global_position - global_position
	sprite.flip_h = dir_to_target.x < 0
	selection_indicator.flip_h = dir_to_target.x < 0
	_move_dir = Vector2.ZERO
	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		_apply_attack()


func _apply_attack() -> void:
	if not _current_target or not _current_target.has_method("take_damage"):
		return
	print("DAMAGE: Unit deals ", attack_damage, " to ", _current_target.name, " at ", Vector2i(_current_target.global_position))
	_current_target.take_damage(attack_damage)


func _spawn_projectile(target: Node2D, damage: int) -> void:
	var scene: PackedScene = preload("res://scenes/projectile.tscn")
	var projectile = ObjectPool.get_from_pool(scene)
	if not projectile:
		projectile = scene.instantiate()
	projectile.damage = damage
	projectile.target = target
	projectile.global_position = global_position
	var hitbox: Hitbox = projectile.get_node("Hitbox")
	if hitbox:
		hitbox.friendly = true
	get_parent().add_child(projectile)


func _on_hurt(hitbox: Area2D) -> void:
	if hitbox is Hitbox and hitbox.is_friendly_hit():
		return
	var src: String = "unknown"
	if hitbox.get_parent():
		src = hitbox.get_parent().name
	print("DAMAGE: ", name, " hit by ", src, " for ", hitbox.damage)
	take_damage(hitbox.damage)


func _on_enemy_died(enemy: Node2D) -> void:
	if _current_target == enemy:
		_current_target = null


func _find_target_from_detection() -> void:
	var found: Node2D = _detection_area.get_closest(global_position)
	if found and global_position.distance_to(found.global_position) <= detection_radius:
		_current_target = found
	else:
		_current_target = null


func get_unit_type() -> UnitType:
	return unit_type


func _push_apart() -> void:
	_check_base_push()


func _check_base_push() -> void:
	if _current_target != null:
		return
	if target_position == Vector2.ZERO:
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


func find_target() -> void:
	_find_target_from_detection()


func set_hovered(value: bool) -> void:
	hovered = value
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	selection_indicator.visible = selected
	queue_redraw()
	selected_changed.emit(self, selected)
	if value:
		EventBus.unit_selected.emit(self)
	else:
		EventBus.unit_deselected.emit()


func take_damage(amount: int) -> void:
	if _dead:
		return
	current_hp -= amount
	_refresh_health_bar()
	print("DAMAGE: ", name, " took ", amount, " HP: ", current_hp, "/", max_hp)
	if current_hp <= 0:
		_dead = true
		EventBus.unit_died.emit(self)
		queue_free()


func _draw_tile_circle(radius: float, color: Color) -> void:
	var tile_size: float = 64.0
	var half_tile: float = tile_size * 0.5
	var tiles_radius: int = int(ceil(radius / tile_size))
	for x in range(-tiles_radius, tiles_radius + 1):
		for y in range(-tiles_radius, tiles_radius + 1):
			var cx: float = x * tile_size + half_tile
			var cy: float = y * tile_size + half_tile
			if sqrt(cx * cx + cy * cy) <= radius + half_tile:
				draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), color)


func _draw() -> void:
	if debug_show_hitbox:
		draw_rect(Rect2(-hitbox_radius, -hitbox_radius, hitbox_radius * 2, hitbox_radius * 2), Color.BLACK, false, 1.0)
	if hovered:
		_draw_tile_circle(click_radius, Color(1, 1, 0, 0.1))
	if selected:
		_draw_tile_circle(detection_radius, Color(1, 1, 0, 0.1))
		_draw_tile_circle(attack_range, Color(1, 0, 0, 0.2))


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp
