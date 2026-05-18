extends Node2D

var wave: int = 0
var enemies_alive: int = 0
var damage_count: int = 0
var done: bool = false


func _ready() -> void:
	print("=== FULL GAME TEST ===")
	var main: Node2D = $Main

	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.base_hp_changed.connect(_on_base_hp_changed)

	var base_node: Node2D = $Main/TownCenter/Base
	if base_node:
		print("Base HP: " + str(base_node.current_hp) + "/" + str(base_node.max_hp))
	EventBus.base_destroyed.connect(_on_base_destroyed)

	main._do_sergeant_selected("infantry")
	main.auto_place_units = true
	for i in range(4):
		var unit: Node2D = main.foot_soldier_scene.instantiate()
		var angle: float = i * PI / 4
		var pos: Vector2 = Vector2(640, 360) + Vector2(cos(angle), sin(angle)) * 150
		unit.position = pos
		main.add_child(unit)
		unit.set_base_position(pos)
		GameManager.spend_gold(50)
		if GameManager.selected_sergeant != "":
			GameManager.apply_sergeant_bonus(unit)


func _on_wave_started(wave_num: int) -> void:
	wave = wave_num
	print("Wave " + str(wave) + " started")


func _on_enemy_spawned(_enemy: Node2D) -> void:
	enemies_alive += 1


func _on_enemy_died(_enemy: Node2D) -> void:
	enemies_alive -= 1
	print("Enemy died, " + str(enemies_alive) + " alive")


func _on_base_hp_changed(_current: int, _max_hp_val: int) -> void:
	damage_count += 1


func _on_base_destroyed() -> void:
	if done:
		return
	done = true
	print("TEST FAILED: Base destroyed at wave " + str(wave) + " (damage events: " + str(damage_count) + ")")
	get_tree().quit()


func _process(_delta: float) -> void:
	if done:
		return
	if wave >= 5 and enemies_alive <= 0:
		done = true
		print("TEST PASSED: Survived 4 waves!")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()

	var elapsed: float = Time.get_ticks_msec() / 1000.0
	if elapsed > 600.0:
		done = true
		print("TEST FAILED: Timeout at wave " + str(wave))
		get_tree().quit()
