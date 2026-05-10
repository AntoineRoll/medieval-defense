extends Node2D

func _ready():
	print("=== MINIMAL TEST ===")
	
	# Spawn 1 unit
	var unit = preload("res://scenes/foot_soldier.tscn").instance()
	unit.position = Vector2(600, 360)
	add_child(unit)
	unit.setup_stats(100, 80, 100, 20, 10, 1.0)
	
	# Spawn 1 enemy
	var enemy = preload("res://scenes/enemy.tscn").instance()
	enemy.position = Vector2(610, 360)
	enemy.connect("enemy_died", self, "_on_enemy_died")
	add_child(enemy)
	
	print("Unit at (600, 360), Enemy at (610, 360)")
	print("Expected: Enemy dies in ~5 seconds")

func _on_enemy_died():
	print("✓ TEST PASSED: Enemy killed!")
	yield(get_tree().create_timer(1.0), "timeout")
	get_tree().quit()

func _process(delta):
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 15.0:
		print("✗ TEST FAILED: Enemy not killed after 15s")
		get_tree().quit()
