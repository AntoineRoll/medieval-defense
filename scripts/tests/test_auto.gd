extends Node2D

var enemies_alive: int = 0


func _ready() -> void:
	print("=== AUTO-PLACE TEST ===")

	var unit_scene: PackedScene = preload("res://scenes/units/foot_soldier.tscn")
	for i in range(8):
		var unit: Node2D = unit_scene.instantiate()
		var angle: float = i * PI / 4
		unit.position = Vector2(640, 360) + Vector2(cos(angle), sin(angle)) * 150
		add_child(unit)
		unit.setup_stats(100, 80, 120, 20, 10, 1.0)

	var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")
	var positions: Array[Vector2] = [Vector2(300, 360), Vector2(980, 360), Vector2(640, 100), Vector2(640, 620)]
	for i in range(4):
		var enemy: Node2D = enemy_scene.instantiate()
		enemy.position = positions[i]
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))
		enemy.connect("reached_base", Callable(self, "_on_reached_base"))
		add_child(enemy)

	print("8 units + 4 enemies placed")
	enemies_alive = 4


func _on_enemy_died() -> void:
	enemies_alive -= 1
	print("Enemy died! Alive: " + str(enemies_alive))
	if enemies_alive <= 0:
		print("TEST PASSED: All enemies killed!")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _on_reached_base() -> void:
	print("TEST FAILED: Enemy reached base!")
	get_tree().quit()


func _process(delta: float) -> void:
	var elapsed: float = Time.get_ticks_msec() / 1000.0
	if elapsed > 60.0:
		print("TEST FAILED: Timeout after 60s")
		get_tree().quit()
