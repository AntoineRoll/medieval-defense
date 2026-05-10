extends Node2D

func _ready():
	print("=== DIRECT SURVIVAL TEST ===")
	
	# Get main node
	var main = $Main
	
	# Start game by simulating sergeant selection
	main._on_sergeant_selected("infantry")
	
	# Connect signals
	main.connect("wave_started", self, "_on_wave_started")
	main.connect("enemy_spawned", self, "_on_enemy_spawned")
	
	var base = main.get_node("TownCenter/Base")
	base.connect("base_destroyed", self, "_on_base_destroyed")
	
	wave = 0
	enemies_alive = 0

var wave = 0
var enemies_alive = 0

func _on_wave_started(wave_num):
	wave = wave_num
	print("Wave " + str(wave) + " started")

func _on_enemy_spawned(enemy):
	enemies_alive += 1

func _on_base_destroyed():
	print("✗ TEST FAILED: Base destroyed at wave " + str(wave))
	get_tree().quit()

func _process(delta):
	if wave >= 5 and enemies_alive <= 0:
		print("✓ TEST PASSED: Survived 4 waves!")
		get_tree().quit()
	
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 600.0: # 10 minutes
		print("✗ TEST FAILED: Timeout at wave " + str(wave))
		get_tree().quit()
