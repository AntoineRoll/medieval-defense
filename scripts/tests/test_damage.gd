extends Node2D

var base: Node2D
var test_unit: Node2D
var enemies: Array[Node2D] = []
var damage_events: Array = []
var start_time: int = 0


func _ready() -> void:
	print("=== DAMAGE TEST START ===")
	start_time = Time.get_ticks_msec()
	setup_scene()
	spawn_test_unit()
	spawn_enemies()


func setup_scene() -> void:
	base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("hp_changed", Callable(self, "_on_base_hp_changed"))
		print("Base positioned at: " + str(base.global_position))


func spawn_test_unit() -> void:
	var main: Node2D = get_node("Main")
	test_unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	test_unit.global_position = Vector2(600, 360)
	test_unit.name = "FootSoldier"
	main.add_child(test_unit)
	test_unit.connect("selected_changed", Callable(self, "_on_unit_selected"))
	print("Foot Soldier spawned - HP: " + str(test_unit.current_hp) + "/" + str(test_unit.max_hp))
	print("  Damage: " + str(test_unit.attack_damage) + " every " + str(test_unit.attack_cooldown) + "s")
	print("  Attack Range: " + str(test_unit.attack_range))


func spawn_enemies() -> void:
	var main: Node2D = get_node("Main")
	var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")

	var positions: Array[Vector2] = [
		Vector2(300, 360),
		Vector2(900, 360),
	]

	for i in range(positions.size()):
		var enemy: Node2D = enemy_scene.instantiate()
		enemy.global_position = positions[i]
		enemy.name = "Enemy" + str(i)
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died").bind(i))
		enemy.connect("reached_base", Callable(self, "_on_enemy_reached_base").bind(i))
		main.add_child(enemy)
		enemies.append(enemy)
		print("Enemy " + str(i) + " spawned at: " + str(enemy.global_position) + " - HP: " + str(enemy.max_hp) + " Speed: " + str(enemy.speed))
		print("  Damage: " + str(enemy.attack_damage) + " every " + str(enemy.attack_cooldown) + "s")

	print("=== DAMAGE TEST INIT COMPLETE ===")
	print("Expected: Unit should attack enemies in range (120px detection, 20px attack)")
	print("Expected: Enemies should attack unit (300px detection, 20px attack)")


func _process(delta: float) -> void:
	var elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0

	if test_unit and is_instance_valid(test_unit):
		var unit_hp: int = test_unit.current_hp
		if unit_hp < test_unit.max_hp:
			log_damage("Unit", "FootSoldier", "Enemy", unit_hp, test_unit.max_hp)

	for i in range(enemies.size()):
		var e: Node2D = enemies[i]
		if is_instance_valid(e) and "current_hp" in e:
			if e.current_hp < e.max_hp:
				log_damage("Enemy", "Enemy" + str(i), "FootSoldier", e.current_hp, e.max_hp)

	if elapsed > 10.0:
		print_damage_report()
		get_tree().quit()


func log_damage(attacker_type: String, attacker_name: String, target_name: String, current_hp: int, max_hp: int) -> void:
	var timestamp: float = (Time.get_ticks_msec() - start_time) / 1000.0
	var key: String = attacker_name + "_" + str(current_hp)

	if not damage_events.has(key):
		damage_events.append(key)
		var damage_taken: int = max_hp - current_hp
		print("[" + str(snapped(timestamp, 0.1)) + "s] " + target_name + " took damage! HP: " + str(current_hp) + "/" + str(max_hp) + " (lost " + str(damage_taken) + " HP)")


func _on_base_hp_changed(current_hp: int, max_hp: int) -> void:
	print("BASE HP: " + str(current_hp) + "/" + str(max_hp))


func _on_enemy_died(enemy_id: int) -> void:
	print("[" + str(snapped((Time.get_ticks_msec() - start_time) / 1000.0, 0.1)) + "s] Enemy " + str(enemy_id) + " died!")


func _on_enemy_reached_base(enemy_id: int) -> void:
	print("Enemy " + str(enemy_id) + " reached base")


func _on_unit_selected(unit: Node2D, is_selected: bool) -> void:
	pass


func print_damage_report() -> void:
	print("\n=== DAMAGE TEST REPORT ===")
	print("Test Duration: " + str(snapped((Time.get_ticks_msec() - start_time) / 1000.0, 0.1)) + "s")
	print("\nDamage Events: " + str(damage_events.size()))

	if test_unit and is_instance_valid(test_unit):
		print("\nFoot Soldier Final HP: " + str(test_unit.current_hp) + "/" + str(test_unit.max_hp))
		var total_damage_taken: int = test_unit.max_hp - test_unit.current_hp
		print("Total Damage Taken: " + str(total_damage_taken))
		print("Expected (2 enemies x 8dmg x ~10 attacks): ~" + str(2 * 8 * 10))

	var alive_enemies: int = 0
	for i in range(enemies.size()):
		var e: Node2D = enemies[i]
		if is_instance_valid(e):
			alive_enemies += 1
			print("Enemy " + str(i) + " Final HP: " + str(e.current_hp) + "/" + str(e.max_hp))
			var total_damage: int = e.max_hp - e.current_hp
			print("Total Damage Taken: " + str(total_damage))
			print("Expected (1 unit x 10dmg x ~10 attacks): ~" + str(1 * 10 * 10))

	if alive_enemies == 0:
		print("\nAll enemies defeated!")
	else:
		print("\n" + str(alive_enemies) + " enemies still alive")

	print("=== END REPORT ===")
