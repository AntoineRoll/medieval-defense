extends Node2D


func _ready() -> void:
	print("=== MINIMAL TEST ===")

	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	unit.position = Vector2(600, 360)
	add_child(unit)
	unit.setup_stats(100, 80, 100, 20, 10, 1.0)

	var enemy = preload("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.position = Vector2(610, 360)
	enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))
	add_child(enemy)

	print("Unit at (600, 360), Enemy at (610, 360)")
	print("Expected: Enemy dies in ~5 seconds")


func _on_enemy_died() -> void:
	print("TEST PASSED: Enemy killed!")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	var elapsed: float = Time.get_ticks_msec() / 1000.0
	if elapsed > 15.0:
		print("TEST FAILED: Enemy not killed after 15s")
		get_tree().quit()
