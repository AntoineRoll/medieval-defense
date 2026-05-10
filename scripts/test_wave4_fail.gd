extends Node2D

func _ready():
	print("=== WAVE 4 AUTO TEST ===")
	
	# Spawn 4 enemies at distance like wave 4
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var positions = [Vector2(300, 360), Vector2(980, 360), Vector2(640, 100), Vector2(640, 620)]
	
	for i in range(4):
		var enemy = enemy_scene.instance()
		enemy.position = positions[i]
		enemy.connect("enemy_died", self, "_on_enemy_died")
		enemy.connect("reached_base", self, "_on_enemy_reached_base")
		$Main/Enemies.add_child(enemy)
		print("Enemy " + str(i) + " spawned at " + str(positions[i]))
	
	# Count enemies
	enemies_alive = 4
	print("Test: 4 enemies spawned, no units placed")
	print("Expected: All reach base, base takes 40 damage (survives with 200 HP)")

var enemies_alive = 0

func _on_enemy_died():
	enemies_alive -= 1

func _on_enemy_reached_base():
	enemies_alive -= 1
	$Main/TownCenter/Base.take_damage(10)
	var hp = $Main/TownCenter/Base.current_hp
	print("Enemy reached base! Base HP: " + str(hp))
	if hp <= 0:
		print("✗ TEST FAILED: Base destroyed")
		get_tree().quit()

func _process(delta):
	if enemies_alive <= 0:
		print("✓ TEST PASSED: All enemies processed, base survived")
		yield(get_tree().create_timer(1.0), "timeout")
		get_tree().quit()
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 60.0:
		print("✗ TEST FAILED: Timeout (enemies alive: " + str(enemies_alive) + ")")
		get_tree().quit()
