extends Node2D

func _ready():
	print("=== WAVE SURVIVAL TEST ===")
	
	# Wait for title screen then simulate sergeant selection
	yield(get_tree().create_timer(1.0), "timeout")
	
	# Click on "infantry" to start
	var main = $Main
	if main and main.has_method(" on_sergeant_selected"):
		main._on_sergeant_selected("infantry")
		print("Started game with infantry sergeant")
	
	# Wait for game to run
	yield(get_tree().create_timer(2.0), "timeout")
	
	# Connect to signals
	if main.has_signal("wave_started"):
		main.connect("wave_started", self, "_on_wave_started")
	if main.has_signal("enemy_spawned"):
		main.connect("enemy_spawned", self, "_on_enemy_spawned")
	
	var base = main.get_node("TownCenter/Base")
	if base:
		base.connect("base_destroyed", self, "_on_base_destroyed")
	
	enemies_alive = 0
	wave = 0

var wave = 0
var enemies_alive = 0
var test_passed = false

func _on_wave_started(wave_num):
	wave = wave_num
	print("Wave " + str(wave) + " started")

func _on_enemy_spawned(enemy):
	enemies_alive += 1

func _on_base_destroyed():
	print("✗ TEST FAILED: Base destroyed at wave " + str(wave))
	get_tree().quit()

func _process(delta):
	if wave >= 5 and enemies_alive <= 0 and not test_passed:
		test_passed = true
		print("✓ TEST PASSED: Survived 4 waves!")
		yield(get_tree().create_timer(1.0), "timeout")
		get_tree().quit()
	
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 600.0:  # 10 minutes
		print("✗ TEST FAILED: Timeout at wave " + str(wave))
		get_tree().quit()
