extends Node2D

func _ready():
	print("=== BASE DAMAGE TEST ===")
	var base = $Main/TownCenter/Base
	
	# Spawn 4 enemies at base
	var enemy_scene = preload("res://scenes/enemy.tscn")
	for i in range(4):
		var enemy = enemy_scene.instance()
		enemy.position = base.position + Vector2(rand_range(-20, 20), rand_range(-20, 20))
		enemy.connect("reached_base", self, "_on_enemy_reached_base")
		$Main/Enemies.add_child(enemy)
	
	print("Spawned 4 enemies at base")
	print("Expected: 4 enemies × 10 damage = 40 HP loss (200 → 160)")
	yield(get_tree().create_timer(10.0), "timeout")
	get_tree().quit()

func _on_enemy_reached_base():
	$Main/TownCenter/Base.take_damage(10)
	var hp = $Main/TownCenter/Base.current_hp
	print("Enemy hit base! HP: " + str(hp) + "/200")
	if hp <= 0:
		print("✗ TEST FAILED: Base destroyed")
		get_tree().quit()
