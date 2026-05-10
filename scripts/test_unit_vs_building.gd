extends Node2D

var test_unit
var test_enemy
var enemy_hp_start = 0

func _ready():
	print("=== UNIT VS BUILDING (ENEMY) TEST START ===")
	spawn_test_unit_and_enemy()

func spawn_test_unit_and_enemy():
	var main = get_node("Main")
	
	# Spawn unit near enemy
	test_unit = preload("res://scenes/foot_soldier.tscn").instance()
	test_unit.global_position = Vector2(600, 360)
	main.add_child(test_unit)
	test_unit.setup_stats(100, 80, 100, 20, 10, 1.0)
	
	# Spawn enemy near unit (unit should attack it)
	test_enemy = preload("res://scenes/enemy.tscn").instance()
	test_enemy.global_position = Vector2(610, 360)
	test_enemy.connect("enemy_died", self, "_on_enemy_died")
	main.add_child(test_enemy)
	yield(get_tree(), "idle_frame") # Wait for _ready() to complete
	enemy_hp_start = test_enemy.current_hp
	
	print("Unit spawned at (600, 360) - Damage: 10/1s")
	print("Enemy spawned at (610, 360) - HP: " + str(test_enemy.max_hp))
	print("=== TEST INIT COMPLETE ===")
	print("Expected: Unit should damage enemy, HP should decrease to 0")

func _on_enemy_died():
	print("✓ TEST PASSED: Unit killed enemy (building damaged indirectly)")
	yield(get_tree().create_timer(1.0), "timeout")
	get_tree().quit()

func _process(delta):
	if test_unit and is_instance_valid(test_unit) and test_enemy and is_instance_valid(test_enemy):
		var unit_target = test_unit.get("current_target")
		if unit_target and is_instance_valid(unit_target):
			if not "last_target" in test_unit or test_unit.last_target != unit_target.name:
				test_unit.last_target = unit_target.name
				print("Unit targeting: " + unit_target.name + " at dist: " + str(test_unit.position.distance_to(unit_target.position)))
	
	if test_enemy and is_instance_valid(test_enemy):
		var hp = test_enemy.current_hp
		if hp < enemy_hp_start:
			print("Enemy HP: " + str(hp) + "/" + str(test_enemy.max_hp) + " (lost " + str(enemy_hp_start - hp) + " HP)")
			enemy_hp_start = hp
	
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 15.0:
		if test_enemy and is_instance_valid(test_enemy) and test_enemy.current_hp > 0:
			print("✗ TEST FAILED: Enemy not killed after 15s (HP: " + str(test_enemy.current_hp) + ")")
		get_tree().quit()
