extends Node2D

func _ready():
	print("=== WAVE 4 SURVIVAL TEST ===")
	
	# Place 4 units around base at wave 4 start
	var main = get_node("Main")
	var unit_scene = preload("res://scenes/foot_soldier.tscn")
	
	for i in range(4):
		var unit = unit_scene.instance()
		var angle = i * PI / 2  # 4 directions
		unit.position = Vector2(640, 360) + Vector2(cos(angle), sin(angle)) * 150
		main.add_child(unit)
		unit.setup_stats(100, 80, 120, 20, 10, 1.0)
	
	# Connect to base
	var base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("base_destroyed", self, "_on_base_destroyed")
		base.connect("hp_changed", self, "_on_base_hp_changed")
		print("Base HP: " + str(base.current_hp))
	
	print("Placed 4 Foot Soldiers around base")
	print("Spawning 4 enemies at edges...")
	
	# Spawn 4 enemies at edges (like wave 4)
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var positions = [
		Vector2(1330, 360),
		Vector2(-50, 360),
		Vector2(640, -50),
		Vector2(640, 770)
	]
	
	for i in range(4):
		var enemy = enemy_scene.instance()
		enemy.position = positions[i]
		enemy.connect("enemy_died", self, "_on_enemy_died")
		enemy.connect("reached_base", self, "_on_enemy_reached_base")
		main.add_child(enemy)
		print("Enemy " + str(i) + " spawned at " + str(positions[i]))
	
	print("=== TEST STARTED ===")
	print("Expected: 4 units kill 4 enemies before they reach base")

var enemies_alive = 4
var test_passed = false

func _on_enemy_died():
	enemies_alive -= 1
	print("Enemy died! Enemies alive: " + str(enemies_alive))
	if enemies_alive <= 0:
		test_passed = true
		print("✓ TEST PASSED: All enemies killed, base survived!")
		yield(get_tree().create_timer(1.0), "timeout")
		get_tree().quit()

func _on_enemy_reached_base():
	print("✗ TEST FAILED: Enemy reached base!")
	get_tree().quit()

func _on_base_destroyed():
	print("✗ TEST FAILED: Base destroyed!")
	get_tree().quit()

func _on_base_hp_changed(current, max_hp):
	if current < max_hp:
		print("WARNING: Base took damage! HP: " + str(current) + "/" + str(max_hp))

func _process(delta):
	if enemies_alive > 0:
		var units = get_tree().get_nodes_in_group("units")
		for unit in units:
			if unit.has_method("get") and unit.current_target:
				if not "last_target" in unit or unit.last_target != unit.current_target.name:
					unit.last_target = unit.current_target.name
					print("Unit targeting: " + unit.current_target.name + " at dist: " + str(unit.position.distance_to(unit.current_target.position)))
	
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 60.0 and not test_passed:
		print("✗ TEST FAILED: Timeout after 60s (enemies alive: " + str(enemies_alive) + ")")
		get_tree().quit()
