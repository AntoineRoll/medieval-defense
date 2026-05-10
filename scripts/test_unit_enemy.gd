extends Node2D

func _ready():
	print("=== UNIT ATTACK TEST ===")
	
	# Spawn unit
	var unit = preload("res://scenes/foot_soldier.tscn").instance()
	unit.global_position = Vector2(600, 360)
	add_child(unit)
	unit.setup_stats(100, 80, 100, 20, 10, 1.0)
	
	# Spawn enemy
	var enemy = preload("res://scenes/enemy.tscn").instance()
	enemy.global_position = Vector2(610, 360)
	enemy.connect("enemy_died", self, "_on_enemy_died")
	add_child(enemy)
	
	print("Unit at (600, 360), Enemy at (610, 360)")
	print("Expected: Unit attacks enemy, enemy HP decreases to 0")
	
	yield(get_tree().create_timer(10.0), "timeout")
	if is_instance_valid(enemy) and enemy.current_hp > 0:
		print("✗ TEST FAILED: Enemy not killed after 10s (HP: " + str(enemy.current_hp) + ")")
	else:
		print("✓ TEST PASSED: Enemy killed")
	get_tree().quit()

func _on_enemy_died():
	print("Enemy died!")
	yield(get_tree().create_timer(1.0), "timeout")
	get_tree().quit()
