extends Node2D

var base
var enemies = []
var test_passed = false

func _ready():
	print("=== BUILDING DAMAGE TEST START ===")
	base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("base_destroyed", self, "_on_base_destroyed")
		base.connect("hp_changed", self, "_on_base_hp_changed")
		print("Base HP: " + str(base.current_hp) + "/" + str(base.max_hp))
	spawn_enemies()

func spawn_enemies():
	var main = get_node("Main")
	var enemy_scene = preload("res://scenes/enemy.tscn")
	
	# Spawn 10 enemies at base to test building damage
	for i in range(10):
		var enemy = enemy_scene.instance()
		enemy.position = base.global_position + Vector2(rand_range(-30, 30), rand_range(-30, 30))
		enemy.connect("enemy_died", self, "_on_enemy_died")
		enemy.connect("reached_base", self, "_on_enemy_reached_base")
		main.add_child(enemy)
		enemies.append(enemy)
		print("Enemy " + str(i) + " spawned at " + str(enemy.global_position) + " - HP: " + str(enemy.max_hp))
	
	print("=== TEST INIT COMPLETE ===")
	print("Expected: 10 enemies × 10 damage = 100 HP loss → Base destroyed")

func _on_base_hp_changed(current, max_hp):
	print("Base HP changed: " + str(current) + "/" + str(max_hp))

func _on_enemy_reached_base():
	print("Enemy reached base!")

func _on_enemy_died():
	print("Enemy died")

func _on_base_destroyed():
	print("✓ TEST PASSED: Base destroyed correctly by enemies")
	test_passed = true
	yield(get_tree().create_timer(1.0), "timeout")
	get_tree().quit()

func _process(delta):
	if not test_passed and base and base.current_hp > 0:
		var elapsed = OS.get_ticks_msec() / 1000.0
		if elapsed > 15.0:
			print("✗ TEST FAILED: Base not destroyed after 15s (HP: " + str(base.current_hp) + ")")
			get_tree().quit()
