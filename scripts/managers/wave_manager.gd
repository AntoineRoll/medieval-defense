class_name WaveManager
extends Node

var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
var enemies_alive: int = 0
var base_position: Vector2 = Vector2.ZERO
var active: bool = false
var _skip_countdown: bool = false
var _tracked_enemies: Dictionary = {}

@onready var enemies_node: Node2D = %Enemies


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_reached_base.connect(_on_enemy_reached_base)
	EventBus.base_destroyed.connect(_on_game_over)


func _get_base_position() -> Vector2:
	var base_node: Node2D = get_tree().get_first_node_in_group("base")
	if base_node:
		return base_node.global_position
	return Vector2(640, 360)


func _get_wave_resource(wave_number: int):
	var path: String = "res://resources/wave_%02d.tres" % clampi(wave_number, 1, 99)
	if ResourceLoader.exists(path):
		return load(path)
	return null


func start_wave(wave_number: int) -> void:
	if active:
		return
	active = true
	base_position = _get_base_position()
	GameManager.wave_number = wave_number

	var wave_data = _get_wave_resource(wave_number)
	var config: GameConfig = preload("res://resources/data/game_config.tres")
	var countdown_time: float = config.initial_wave_countdown_time if wave_number == 1 else config.wave_countdown_time

	_skip_countdown = false
	for s in range(int(countdown_time), 0, -1):
		if _skip_countdown:
			break
		EventBus.wave_countdown.emit(wave_number, s)
		await get_tree().create_timer(1.0, true).timeout
		if GameManager.game_over:
			active = false
			return
	EventBus.wave_started.emit(wave_number)

	var enemy_count: int = wave_data.enemy_count if wave_data else wave_number
	var spawn_interval: float = wave_data.spawn_interval if wave_data else 2.0

	for i in range(enemy_count):
		await get_tree().create_timer(spawn_interval, true).timeout
		if GameManager.game_over:
			active = false
			return
		spawn_enemy(wave_data)


func spawn_enemy(wave_data = null) -> void:
	var enemy: Node2D = ObjectPool.get_from_pool(enemy_scene)
	if not enemy:
		enemy = enemy_scene.instantiate()
	enemy.set_base_position(base_position)
	enemy.position = _get_spawn_position()

	if wave_data:
		enemy.max_hp = int(enemy.max_hp * wave_data.hp_multiplier)
		enemy.current_hp = enemy.max_hp
		enemy.speed = enemy.speed * wave_data.speed_multiplier
		enemy.attack_damage = int(enemy.attack_damage * wave_data.damage_multiplier)

	enemies_node.add_child(enemy)
	enemies_alive += 1
	_tracked_enemies[enemy] = true
	EventBus.enemy_spawned.emit(enemy)


func _get_spawn_position() -> Vector2:
	var markers: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	if markers.size() > 0:
		var marker: Marker2D = markers[randi() % markers.size()]
		return marker.global_position
	return _get_random_edge_position()


func _get_random_edge_position() -> Vector2:
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var side: int = randi() % 4
	var x: float = 0.0
	var y: float = 0.0
	match side:
		0:
			x = randf_range(0, viewport.size.x)
			y = -50
		1:
			x = randf_range(0, viewport.size.x)
			y = viewport.size.y + 50
		2:
			x = -50
			y = randf_range(0, viewport.size.y)
		3:
			x = viewport.size.x + 50
			y = randf_range(0, viewport.size.y)
	return Vector2(x, y)


func _on_enemy_died(enemy: Node2D) -> void:
	if not _tracked_enemies.has(enemy):
		return
	_tracked_enemies.erase(enemy)
	enemies_alive = _tracked_enemies.size()
	check_wave_complete()


func _on_enemy_reached_base(enemy: Node2D) -> void:
	if not _tracked_enemies.has(enemy):
		return
	_tracked_enemies.erase(enemy)
	enemies_alive = _tracked_enemies.size()
	check_wave_complete()


func skip_wave_countdown() -> void:
	_skip_countdown = true


func check_wave_complete() -> void:
	if enemies_alive <= 0 and active:
		active = false
		var completed_wave: int = GameManager.wave_number
		EventBus.wave_completed.emit(completed_wave)
		if completed_wave >= 10:
			StateMachine.transition(StateMachine.State.WON)
		else:
			_next_wave_soon()


func _next_wave_soon() -> void:
	await get_tree().create_timer(2.0, true).timeout
	if not GameManager.game_over:
		start_wave(GameManager.wave_number + 1)


func _on_game_over() -> void:
	active = false
	for child in enemies_node.get_children():
		if not is_instance_valid(child):
			continue
		if child.has_method("set_process") and child.has_method("set_physics_process"):
			child.set_process(false)
			child.set_physics_process(false)
		if _tracked_enemies.has(child):
			_tracked_enemies.erase(child)
		ObjectPool.return_to_pool(child)
