extends Node2D

var base
var test_unit
var enemies = []
var enemy_last_target = {}
var enemy_hp_tracker = {}
var unit_hp_tracker = []
var damage_events = []

func _ready():
	print("=== COMBAT TEST START ===")
	setup_scene()
	spawn_test_unit()
	spawn_enemies()
	
func setup_scene():
	base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("hp_changed", self, "_on_base_hp_changed")
		print("Base positioned at: " + str(base.global_position))
	
func spawn_test_unit():
	var main = get_node("Main")
	# Test Archer (ranged unit)
	test_unit = preload("res://scenes/archer.tscn").instance()
	test_unit.global_position = Vector2(600, 360)
	main.add_child(test_unit)
	test_unit.setup_stats(200, 100, 360, 200, 15, 1.0)
	test_unit.connect("selected_changed", self, "_on_unit_selected")
	print("Archer (ranged) spawned at: " + str(test_unit.global_position))
	print("  Detection Radius: " + str(test_unit.attack_radius) + " (should be 360)")
	print("  Attack Range: " + str(test_unit.attack_range) + " (should be 200)")
	print("  HP: " + str(test_unit.current_hp) + "/" + str(test_unit.max_hp) + " (should be 200/200)")
	print("  Damage: " + str(test_unit.attack_damage) + " (should be 15)")
	print("  EXPECTED: Should stop at 200px from enemy, NOT rush to melee")
	
func spawn_enemies():
	var enemy_scene = preload("res://scenes/enemy.tscn")
	
	var positions = [
		Vector2(500, 360),
		Vector2(1080, 360),
		Vector2(640, 100),
	]
	
	var main = get_node("Main")
	for i in range(positions.size()):
		var enemy = enemy_scene.instance()
		enemy.global_position = positions[i]
		enemy.connect("enemy_died", self, "_on_enemy_died")
		enemy.connect("reached_base", self, "_on_enemy_reached_base")
		main.add_child(enemy)
		enemies.append(enemy)
		print("Enemy " + str(i) + " spawned at: " + str(enemy.global_position) + " (dist to base: " + str(enemy.global_position.distance_to(Vector2(640, 360))) + ")")
	
	print("=== TEST INIT COMPLETE ===")
	print("Expected behavior:")
	print("1. Enemy 0 (left) should target Foot Soldier first (in detection range)")
	print("2. Enemy 1 (right) should move to base (no unit in range)")
	print("3. Enemy 2 (top) should move to base (no unit in range)")
	
func _process(delta):
	if test_unit and is_instance_valid(test_unit):
		var unit_hp = test_unit.current_hp if "current_hp" in test_unit else -1
		if unit_hp > 0 and unit_hp < 50:
			print("WARNING: Foot Soldier taking damage! HP: " + str(unit_hp))
	
	for i in range(enemies.size()):
		var e = enemies[i]
		if is_instance_valid(e) and "current_target" in e:
			var target_name = "none"
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
				var dist = "N/A"
				if e.current_target:
					dist = str(e.position.distance_to(e.current_target.position))
				print("Enemy " + str(i) + " targeting: " + target_name + " at dist: " + dist)
	
func _on_base_hp_changed(current_hp, max_hp):
	print("BASE HP: " + str(current_hp) + "/" + str(max_hp))
	if current_hp <= 0:
		print("TEST FAILED: Base destroyed!")
		
func _on_enemy_died():
	print("Enemy died")
	
func _on_enemy_reached_base():
	print("Enemy reached base (no unit intercepted)")
	
func _on_unit_selected(unit, is_selected):
	print("Unit selected: " + str(is_selected))
