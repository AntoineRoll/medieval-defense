extends Node2D

func _ready():
	print("=== WAVE 4 AUTO TEST ===")
	
	# Auto-place 4 foot soldiers around base
	var unit_scene = preload("res://scenes/foot_soldier.tscn")
	for i in range(4):
		var unit = unit_scene.instance()
		var angle = i * PI / 2
		unit.position = Vector2(640, 360) + Vector2(cos(angle), sin(angle)) * 150
		$Main.add_child(unit)
		unit.setup_stats(100, 80, 120, 20, 10, 1.0)
	
	# Connect to base
	var base = $Main/TownCenter/Base
	base.connect("hp_changed", self, "_on_hp_changed")
	base.connect("base_destroyed", self, "_on_destroyed")
	print("Base HP: " + str(base.current_hp) + "/" + str(base.max_hp))
	
	# Spawn 4 enemies at edges like wave 4
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var positions = [Vector2(300, 360), Vector2(980, 360), Vector2(640, 100), Vector2(640, 620)]
	for i in range(4):
		var enemy = enemy_scene.instance()
		enemy.position = positions[i]
		enemy.connect("enemy_died", self, "_on_enemy_died")
		enemy.connect("reached_base", self, "_on_reached_base")
		$Main/Enemies.add_child(enemy)
	
	print("4 units placed, 4 enemies spawned")
	print("Expected: All enemies killed by units")

var enemies_alive = 4

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

func _on_hp_changed(current, max_hp):
	if current < max_hp:
		print("WARNING: Base took damage! HP: " + str(current))

func _on_destroyed():
	print("✗ TEST FAILED: Base destroyed!")
	get_tree().quit()

func _process(delta):
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 60.0:
		print("✗ TEST FAILED: Timeout after 60s (alive: " + str(enemies_alive) + ")")
		get_tree().quit()
