extends Node2D

var base: Node2D
var test_unit: Node2D
var enemies: Array[Node2D] = []
var enemy_last_target: Dictionary = {}
var enemy_hp_tracker: Dictionary = {}
var unit_hp_tracker: Array = []
var damage_events: Array = []
var _start_time: int = 0
var _test_complete: bool = false


func _ready() -> void:
	print("=== COMBAT TEST START ===")
	_start_time = Time.get_ticks_msec()
	setup_scene()
	spawn_test_unit()
	spawn_enemies()


func setup_scene() -> void:
	base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("hp_changed", Callable(self, "_on_base_hp_changed"))
		print("Base positioned at: " + str(base.global_position))


func spawn_test_unit() -> void:
	var main: Node2D = get_node("Main")
	test_unit = preload("res://scenes/units/archer.tscn").instantiate()
	test_unit.global_position = Vector2(600, 360)
	main.add_child(test_unit)
	test_unit.setup_stats(200, 100, 360, 200, 15, 1.0)
	test_unit.connect("selected_changed", Callable(self, "_on_unit_selected"))
	print("Archer (ranged) spawned at: " + str(test_unit.global_position))
	print("  Detection Radius: " + str(test_unit.detection_radius) + " (should be 360)")
	print("  Attack Range: " + str(test_unit.attack_range) + " (should be 200)")
	print("  HP: " + str(test_unit.current_hp) + "/" + str(test_unit.max_hp) + " (should be 200/200)")
	print("  Damage: " + str(test_unit.attack_damage) + " (should be 15)")
	print("  EXPECTED: Should stop at 200px from enemy, NOT rush to melee")


func spawn_enemies() -> void:
	var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")

	var positions: Array[Vector2] = [
		Vector2(500, 360),
		Vector2(1080, 360),
		Vector2(640, 100),
	]

	var main: Node2D = get_node("Main")
	for i in range(positions.size()):
		var enemy: Node2D = enemy_scene.instantiate()
		enemy.global_position = positions[i]
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))
		enemy.connect("reached_base", Callable(self, "_on_enemy_reached_base"))
		main.add_child(enemy)
		enemies.append(enemy)
		print("Enemy " + str(i) + " spawned at: " + str(enemy.global_position) + " (dist to base: " + str(enemy.global_position.distance_to(Vector2(640, 360))) + ")")

	print("=== TEST INIT COMPLETE ===")
	print("Expected behavior:")
	print("1. Enemy 0 (left) should target Foot Soldier first (in detection range)")
	print("2. Enemy 1 (right) should move to base (no unit in range)")
	print("3. Enemy 2 (top) should move to base (no unit in range)")


func _process(delta: float) -> void:
	if _test_complete:
		return

	if test_unit and is_instance_valid(test_unit):
		var unit_hp: int = test_unit.current_hp if "current_hp" in test_unit else -1
		if unit_hp > 0 and unit_hp < 50:
			print("WARNING: Foot Soldier taking damage! HP: " + str(unit_hp))

	for i in range(enemies.size()):
		var e: Node2D = enemies[i]
		if is_instance_valid(e) and "current_target" in e:
			var target_name: String = "none"
			if e.current_target:
				target_name = e.current_target.name
				if e.current_target.is_in_group("units"):
					target_name += " (MILITARY - PRIORITY)"
				elif e.current_target.is_in_group("buildings"):
					target_name += " (BUILDING)"
				elif e.current_target.is_in_group("base"):
					target_name += " (BASE)"
			if not enemy_last_target.has(i) or enemy_last_target[i] != target_name:
				enemy_last_target[i] = target_name
				var dist: String = "N/A"
				if e.current_target:
					dist = str(e.position.distance_to(e.current_target.position))
				print("Enemy " + str(i) + " targeting: " + target_name + " at dist: " + dist)

	var elapsed: float = (Time.get_ticks_msec() - _start_time) / 1000.0
	if elapsed > 15.0:
		_quit_test()


func _on_base_hp_changed(current_hp: int, max_hp: int) -> void:
	print("BASE HP: " + str(current_hp) + "/" + str(max_hp))
	if current_hp <= 0:
		print("TEST FAILED: Base destroyed!")


func _on_enemy_died() -> void:
	print("Enemy died")


func _on_enemy_reached_base() -> void:
	print("Enemy reached base (no unit intercepted)")


func _on_unit_selected(unit: Node2D, is_selected: bool) -> void:
	print("Unit selected: " + str(is_selected))


func _quit_test() -> void:
	_test_complete = true
	print("=== COMBAT TEST COMPLETE ===")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
