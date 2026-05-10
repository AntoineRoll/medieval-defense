extends Node2D

var wave = 0
var enemies_alive = 0
var base_hp_start = 200
var damage_count = 0

func _ready():
	print("=== FULL GAME TEST ===")
	var main = $Main
	if main.has_signal("enemy_spawned"):
		main.connect("enemy_spawned", self, "_on_enemy_spawned")
	if main.has_signal("wave_started"):
		main.connect("wave_started", self, "_on_wave_started")
	
	var base = $Main/TownCenter/Base
	if base:
		base.connect("hp_changed", self, "_on_base_hp_changed")
		base.connect("base_destroyed", self, "_on_base_destroyed")
		base_hp_start = base.current_hp
		print("Base HP: " + str(base.current_hp) + "/" + str(base.max_hp))
	
	# Auto-place units each wave
	main.auto_place_units = true

func _on_wave_started(wave_num):
	wave = wave_num
	print("Wave " + str(wave) + " started")

func _on_enemy_spawned(enemy):
	enemies_alive += 1

func _on_base_hp_changed(current, max_hp):
	if current < base_hp_start:
		damage_count += 1
		var lost = base_hp_start - current
		print("Base took damage! HP: " + str(current) + "/" + str(max_hp) + " (total lost: " + str(lost) + ")")
		base_hp_start = current

func _on_base_destroyed():
	print("✗ TEST FAILED: Base destroyed at wave " + str(wave) + " (damage events: " + str(damage_count) + ")")
	get_tree().quit()

func _process(delta):
	if wave >= 5 and enemies_alive <= 0:
		print("✓ TEST PASSED: Survived 4 waves!")
		yield(get_tree().create_timer(1.0), "timeout")
		get_tree().quit()
	
	var elapsed = OS.get_ticks_msec() / 1000.0
	if elapsed > 600.0:  # 10 minutes timeout
		print("✗ TEST FAILED: Timeout at wave " + str(wave))
		get_tree().quit()
