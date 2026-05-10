extends Node2D

var base
var test_unit
var enemies = []
var damage_events = []
var start_time = 0

func _ready():
	print("=== DAMAGE TEST START ===")
	start_time = OS.get_ticks_msec()
	setup_scene()
	spawn_test_unit()
	spawn_enemies()
	
func setup_scene():
	base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("hp_changed", self, "_on_base_hp_changed")
		print("Base positioned at: " + str(base.global_position))
	
func spawn_test_unit():
	var main = get_node("Main")
	test_unit = preload("res://scenes/foot_soldier.tscn").instance()
	test_unit.global_position = Vector2(600, 360)
	test_unit.name = "FootSoldier"
	main.add_child(test_unit)
	test_unit.connect("selected_changed", self, "_on_unit_selected")
	print("Foot Soldier spawned - HP: " + str(test_unit.current_hp) + "/" + str(test_unit.max_hp))
	print("  Damage: " + str(test_unit.attack_damage) + " every " + str(test_unit.attack_cooldown) + "s")
	print("  Attack Range: " + str(test_unit.attack_range))
	
func spawn_enemies():
	var main = get_node("Main")
	var enemy_scene = preload("res://scenes/enemy.tscn")
	
	var positions = [
		Vector2(300, 360),
		Vector2(900, 360),
	]
	
	for i in range(positions.size()):
		var enemy = enemy_scene.instance()
		enemy.global_position = positions[i]
		enemy.name = "Enemy" + str(i)
		enemy.connect("enemy_died", self, "_on_enemy_died", [i])
		enemy.connect("reached_base", self, "_on_enemy_reached_base", [i])
		main.add_child(enemy)
		enemies.append(enemy)
		print("Enemy " + str(i) + " spawned at: " + str(enemy.global_position) + " - HP: " + str(enemy.max_hp) + " Speed: " + str(enemy.speed))
		print("  Damage: " + str(enemy.attack_damage) + " every " + str(enemy.attack_cooldown) + "s")
	
	print("=== DAMAGE TEST INIT COMPLETE ===")
	print("Expected: Unit should attack enemies in range (120px detection, 20px attack)")
	print("Expected: Enemies should attack unit (300px detection, 20px attack)")
	
func _process(delta):
	var elapsed = (OS.get_ticks_msec() - start_time) / 1000.0
	
	if test_unit and is_instance_valid(test_unit):
		var unit_hp = test_unit.current_hp
		if unit_hp < test_unit.max_hp:
			log_damage("Unit", "FootSoldier", "Enemy", unit_hp, test_unit.max_hp)
	
	for i in range(enemies.size()):
		var e = enemies[i]
		if is_instance_valid(e) and "current_hp" in e:
			if e.current_hp < e.max_hp:
				log_damage("Enemy", "Enemy" + str(i), "FootSoldier", e.current_hp, e.max_hp)
	
	if elapsed > 10.0:
		print_damage_report()
		get_tree().quit()
	
func log_damage(attacker_type, attacker_name, target_name, current_hp, max_hp):
	var timestamp = (OS.get_ticks_msec() - start_time) / 1000.0
	var key = attacker_name + "_" + str(current_hp)
	
	if not damage_events.has(key):
		damage_events.append(key)
		var damage_taken = max_hp - current_hp
		print("[" + str(stepify(timestamp, 0.1)) + "s] " + target_name + " took damage! HP: " + str(current_hp) + "/" + str(max_hp) + " (lost " + str(damage_taken) + " HP)")
		
func _on_base_hp_changed(current_hp, max_hp):
	print("BASE HP: " + str(current_hp) + "/" + str(max_hp))
		
func _on_enemy_died(enemy_id):
	print("[" + str(stepify((OS.get_ticks_msec() - start_time) / 1000.0, 0.1)) + "s] Enemy " + str(enemy_id) + " died!")
	
func _on_enemy_reached_base(enemy_id):
	print("Enemy " + str(enemy_id) + " reached base")
	
func _on_unit_selected(unit, is_selected):
	pass
	
func print_damage_report():
	print("\n=== DAMAGE TEST REPORT ===")
	print("Test Duration: " + str(stepify((OS.get_ticks_msec() - start_time) / 1000.0, 0.1)) + "s")
	print("\nDamage Events: " + str(damage_events.size()))
	
	if test_unit and is_instance_valid(test_unit):
		print("\nFoot Soldier Final HP: " + str(test_unit.current_hp) + "/" + str(test_unit.max_hp))
		var total_damage_taken = test_unit.max_hp - test_unit.current_hp
		print("Total Damage Taken: " + str(total_damage_taken))
		print("Expected (2 enemies × 8dmg × ~10 attacks): ~" + str(2 * 8 * 10))
	
	var alive_enemies = 0
	for i in range(enemies.size()):
		var e = enemies[i]
		if is_instance_valid(e):
			alive_enemies += 1
			print("Enemy " + str(i) + " Final HP: " + str(e.current_hp) + "/" + str(e.max_hp))
			var total_damage = e.max_hp - e.current_hp
			print("Total Damage Taken: " + str(total_damage))
			print("Expected (1 unit × 10dmg × ~10 attacks): ~" + str(1 * 10 * 10))
	
	if alive_enemies == 0:
		print("\n✓ All enemies defeated!")
	else:
		print("\n✗ " + str(alive_enemies) + " enemies still alive")
	
	print("=== END REPORT ===")
