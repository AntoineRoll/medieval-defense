extends Node2D

func _ready():
	print("=== AUTO-PLACE TEST ===")
	
	# Place 8 units (2x wave 4 enemies = 8)
	var unit_scene = preload("res://scenes/foot_soldier.tscn")
	for i in range(8):
		var unit = unit_scene.instance()
		var angle = i * PI / 4
		unit.position = Vector2(640, 360) + Vector2(cos(angle), sin(angle)) * 150
		$".".add_child(unit)
		unit.setup_stats(100, 80, 120, 20, 10, 1.0)
	
	# Spawn 4 enemies at edges
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var positions = [Vector2(300, 360), Vector2(980, 360), Vector2(640, 100), Vector2(640, 620)]
	for i in range(4):
		var enemy = enemy_scene.instance()
		enemy.position = positions[i]
		enemy.connect("enemy_died", self, "_on_enemy_died")
		enemy.connect("reached_base", self, "_on_reached_base")
		$".".add_child(enemy)
	
	print("8 units + 4 enemies placed")
	enemies_alive = 4

var enemies_alive = 0

func _on_enemy_died():
	enemies_alive -= 1
	print("Enemy died! Alive: " + str(enemies_alive))
	if enemies_alive <= 0:
		print("✓ TEST PASSED: All enemies killed!")
		yield(get_tree().create_timer(1.0), "timeout")
		get_tree().quit()

func _on_reached_base():
	print("✗ TEST FAILED: Enemy reached base!")
	get_tree().quit()

func _process(delta):
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 60.0:
		print("✗ TEST FAILED: Timeout after 60s")
		get_tree().quit()
