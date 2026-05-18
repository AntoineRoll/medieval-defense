extends Node2D

var base: Node2D
var enemies: Array[Node2D] = []
var test_passed: bool = false


func _ready() -> void:
	print("=== BUILDING DAMAGE TEST START ===")
	base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("hp_changed", Callable(self, "_on_base_hp_changed"))
		print("Base HP: " + str(base.current_hp) + "/" + str(base.max_hp))
	EventBus.base_destroyed.connect(_on_base_destroyed)
	spawn_enemies()


func spawn_enemies() -> void:
	var main: Node2D = get_node("Main")
	var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")

	for i in range(10):
		var enemy: Node2D = enemy_scene.instantiate()
		enemy.position = base.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))
		enemy.connect("reached_base", Callable(self, "_on_enemy_reached_base"))
		main.add_child(enemy)
		enemies.append(enemy)
		print("Enemy " + str(i) + " spawned at " + str(enemy.global_position) + " - HP: " + str(enemy.max_hp))

	print("=== TEST INIT COMPLETE ===")
	print("Expected: 10 enemies x 10 damage = 100 HP loss => Base destroyed")


func _on_base_hp_changed(current: int, max_hp: int) -> void:
	print("Base HP changed: " + str(current) + "/" + str(max_hp))


func _on_enemy_reached_base() -> void:
	print("Enemy reached base!")


func _on_enemy_died() -> void:
	print("Enemy died")


func _on_base_destroyed() -> void:
	print("TEST PASSED: Base destroyed correctly by enemies")
	test_passed = true
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	if not test_passed and base and base.current_hp > 0:
		var elapsed: float = Time.get_ticks_msec() / 1000.0
		if elapsed > 15.0:
			print("TEST FAILED: Base not destroyed after 15s (HP: " + str(base.current_hp) + ")")
			get_tree().quit()
