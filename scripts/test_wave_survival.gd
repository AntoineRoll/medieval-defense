extends Node2D

var wave = 0
var enemies_alive = 0
var base_hp_start = 100
var test_failed = false

func _ready():
	print("=== WAVE SURVIVAL TEST START ===")
	# Connect to main signals
	var main = get_node("Main")
	if main and main.has_method("connect"):
		if main.has_signal("enemy_spawned"):
			main.connect("enemy_spawned", self, "_on_enemy_spawned")
		if main.has_signal("wave_started"):
			main.connect("wave_started", self, "_on_wave_started")
	
	# Connect to base
	var base = get_node("Main/TownCenter/Base")
	if base:
		base.connect("hp_changed", self, "_on_base_hp_changed")
		base.connect("base_destroyed", self, "_on_base_destroyed")
		base_hp_start = base.current_hp
		print("Base HP: " + str(base.current_hp) + "/" + str(base.max_hp))
	
	print("Test: Survive 4 waves with 200 starting gold")
	print("Expected: Base stays above 0 HP")

func _on_wave_started(wave_num):
	wave = wave_num
	print("Wave " + str(wave) + " started")

func _on_enemy_spawned(enemy):
	enemies_alive += 1

func _on_base_hp_changed(current, max_hp):
	var lost = base_hp_start - current
	if lost > 0:
		print("WARNING: Base took " + str(lost) + " damage! HP: " + str(current) + "/" + str(max_hp))
		base_hp_start = current

func _on_base_destroyed():
	print("✗ TEST FAILED: Base destroyed at wave " + str(wave))
	test_failed = true
	get_tree().quit()

func _process(delta):
	var elapsed = OS.get_ticks_msec() / 1000.0
	if wave >= 4 and enemies_alive <= 0 and not test_failed:
		print("✓ TEST PASSED: Survived 4 waves!")
		yield(get_tree().create_timer(1.0), "timeout")
		get_tree().quit()
	if elapsed > 300.0:  # 5 minutes timeout
		print("✗ TEST FAILED: Timeout after 5 minutes (wave: " + str(wave) + ")")
		get_tree().quit()
