extends Node2D

signal enemy_spawned
signal wave_started
signal building_placed(type, position)

var unit_scene = preload("res://scenes/unit.tscn")
var foot_soldier_scene = preload("res://scenes/foot_soldier.tscn")
var archer_scene = preload("res://scenes/archer.tscn")
var cavalry_scene = preload("res://scenes/cavalry.tscn")
var enemy_scene = preload("res://scenes/enemy.tscn")

var current_stage = 0
var selected_sergeant = ""
var wave_number = 0
var enemies_alive = 0
var base_hp = 100
var gold = 200
var placing_unit = false
var placing_unit_type = "foot_soldier"
var unit_cost = 50
var selected_units = []
var game_over = false

func _ready():
	print("Medieval Defense - Main Scene Loaded")
	# Hide game elements initially
	if has_node("TownCenter"):
		$TownCenter.visible = false
	if has_node("Ground"):
		$Ground.visible = false
	if has_node("Map"):
		$Map.visible = false
	if has_node("Enemies"):
		$Enemies.visible = false
	# Connect title screen
	if has_node("TitleScreen"):
		$TitleScreen.connect("play_pressed", self, "_on_title_play_pressed")
		$TitleScreen.connect("quit_pressed", self, "_on_title_quit_pressed")
	# Connect sergeant select screen
	if has_node("SergeantSelect"):
		$SergeantSelect.connect("sergeant_selected", self, "_on_sergeant_selected")
	# Connect game over screen
	if has_node("GameOverScreen"):
		$GameOverScreen.connect("replay_pressed", self, "_on_game_over_replay_pressed")
		$GameOverScreen.connect("quit_pressed", self, "_on_game_over_quit_pressed")
	# Connect base signals
	if has_node("TownCenter/Base"):
		$TownCenter/Base.connect("base_destroyed", self, "_on_base_destroyed")
		$TownCenter/Base.connect("hp_changed", self, "_on_base_hp_changed")
	# Connect UI buttons
	if has_node("UI/UIRoot"):
		$UI/UIRoot.visible = false
		if has_node("UI/UIRoot/GoldLabel"):
			$UI/UIRoot/GoldLabel.text = "Gold: " + str(gold)
	if has_node("UI/UIRoot/FootSoldierBtn"):
		$UI/UIRoot/FootSoldierBtn.connect("pressed", self, "_on_FootSoldierBtn_pressed")
	if has_node("UI/UIRoot/ArcherBtn"):
		$UI/UIRoot/ArcherBtn.connect("pressed", self, "_on_ArcherBtn_pressed")
	if has_node("UI/UIRoot/CavalryBtn"):
		$UI/UIRoot/CavalryBtn.connect("pressed", self, "_on_CavalryBtn_pressed")
	if has_node("UI/UIRoot/PauseBtn"):
		$UI/UIRoot/PauseBtn.connect("pressed", self, "_on_PauseBtn_pressed")
	# Pause menu buttons
	if has_node("UI/PauseMenu/CenterContainer/VBox/ResumeBtn"):
		$UI/PauseMenu/CenterContainer/VBox/ResumeBtn.connect("pressed", self, "_on_ResumeBtn_pressed")
	if has_node("UI/PauseMenu/CenterContainer/VBox/ExitBtn"):
		$UI/PauseMenu/CenterContainer/VBox/ExitBtn.connect("pressed", self, "_on_ExitBtn_pressed")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_ESCAPE:
			toggle_pause()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_LEFT:
			if placing_unit:
				var pos = get_global_mouse_position()
				if gold >= unit_cost:
					place_foot_soldier(pos)
					gold -= unit_cost
				if has_node("UI/UIRoot/GoldLabel"):
					$UI/UIRoot/GoldLabel.text = "Gold: " + str(gold)
				placing_unit = false
		elif event.button_index == BUTTON_RIGHT:
			if selected_units.size() > 0:
				for unit in selected_units:
					if is_instance_valid(unit):
						unit.move_to(get_global_mouse_position())

var auto_place_units = false  # Auto-place units near base for survival

func auto_place_unit():
	if gold < unit_cost or not auto_place_units:
		return
	var unit = null
	match placing_unit_type:
		"foot_soldier":
			unit = foot_soldier_scene.instance()
		"archer":
			unit = archer_scene.instance()
		"cavalry":
			unit = cavalry_scene.instance()
	if unit:
		var angle = rand_range(0, 2*PI)
		var distance = rand_range(100, 200)
		var pos = $TownCenter.position + Vector2(cos(angle), sin(angle)) * distance
		unit.position = pos
		unit.set_base_position(pos)
		add_child(unit)
		if selected_sergeant != "":
			apply_sergeant_bonus(unit)
		gold -= unit_cost
		if has_node("UI/UIRoot/GoldLabel"):
			$UI/UIRoot/GoldLabel.text = "Gold: " + str(gold)
		print("Auto-placed " + placing_unit_type + " at " + str(pos) + " (gold: " + str(gold) + ")")

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		var clicked_unit = get_clicked_unit(event)
		if clicked_unit:
			if clicked_unit.selected:
				clicked_unit.set_selected(false)
			else:
				for unit in get_tree().get_nodes_in_group("units"):
					if unit.selected:
						unit.set_selected(false)
				clicked_unit.set_selected(true)
			return
		var base = $TownCenter/Base
		if base and base.is_clicked(event):
			for unit in get_tree().get_nodes_in_group("units"):
				if unit.selected:
					unit.set_selected(false)
			base.set_selected(true)
			return
		# Clicked on nothing - deselect all
		for unit in get_tree().get_nodes_in_group("units"):
			if unit.selected:
				unit.set_selected(false)
		if has_node("TownCenter/Base") and $TownCenter/Base.has_method("set_selected"):
			$TownCenter/Base.set_selected(false)

func get_clicked_unit(event):
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_clicked(event):
			return unit
	return null

func _on_FootSoldierBtn_pressed():
	placing_unit = true
	placing_unit_type = "foot_soldier"
	unit_cost = 50
	print("Placing foot soldier (cost: " + str(unit_cost) + ", gold: " + str(gold) + ")")

func _on_ArcherBtn_pressed():
	placing_unit = true
	placing_unit_type = "archer"
	unit_cost = 75
	print("Placing archer (cost: " + str(unit_cost) + ", gold: " + str(gold) + ")")

func _on_CavalryBtn_pressed():
	placing_unit = true
	placing_unit_type = "cavalry"
	unit_cost = 100
	print("Placing cavalry (cost: " + str(unit_cost) + ", gold: " + str(gold) + ")")

func _on_title_play_pressed():
	print("Title play pressed - showing sergeant selection")
	if has_node("TitleScreen"):
		$TitleScreen.visible = false
	if has_node("SergeantSelect"):
		$SergeantSelect.visible = true

func _on_title_quit_pressed():
	get_tree().quit()

func _on_sergeant_selected(sergeant_type):
	start_village_stage(sergeant_type)

func _on_game_over_replay_pressed():
	print("Replay pressed - restarting game")
	# Reset game state
	game_over = false
	wave_number = 0
	gold = 200
	enemies_alive = 0
	selected_sergeant = ""
	current_stage = 0
	# Remove all enemies
	if has_node("Enemies"):
		for child in $Enemies.get_children():
			child.queue_free()
	# Remove all units
	for unit in get_tree().get_nodes_in_group("units"):
		unit.queue_free()
	# Reset base HP
	if has_node("TownCenter/Base"):
		$TownCenter/Base.current_hp = $TownCenter/Base.max_hp
		$TownCenter/Base.game_over = false
	# Hide game over screen
	if has_node("GameOverScreen"):
		$GameOverScreen.visible = false
	# Show title screen
	if has_node("TitleScreen"):
		$TitleScreen.visible = true
	# Hide game elements
	if has_node("TownCenter"):
		$TownCenter.visible = false
	if has_node("BackgroundLayer/Background"):
		$BackgroundLayer/Background.visible = false
	if has_node("Map"):
		$Map.visible = false
	get_tree().paused = false

func _on_game_over_quit_pressed():
	get_tree().quit()

func start_village_stage(sergeant_type):
	selected_sergeant = sergeant_type
	current_stage = 1
	if has_node("SergeantSelect"):
		$SergeantSelect.visible = false
	if has_node("TownCenter"):
		$TownCenter.visible = true
	if has_node("Enemies"):
		$Enemies.visible = true
	if has_node("UI/UIRoot"):
		$UI/UIRoot.visible = true
	if has_node("BackgroundLayer/Background"):
		$BackgroundLayer/Background.visible = true
	if has_node("Map"):
		$Map.visible = true
	show_sergeant_bonus()
	print("Village stage started with: " + sergeant_type + " (+20% HP, +20% attack)")
	spawn_initial_buildings()
	start_next_wave()

func show_sergeant_bonus():
	var shield = get_node_or_null("UI/SergeantBonus/Shield")
	var label = get_node_or_null("UI/SergeantBonus/Label")
	if shield:
		shield.visible = true
	if label:
		label.text = selected_sergeant.capitalize() + " (+20% HP, +20% ATK)"
		label.visible = true

func apply_sergeant_bonus(unit):
	var mult = 1.2
	unit.max_hp = int(unit.max_hp * mult)
	unit.current_hp = unit.max_hp
	unit.attack_damage = int(unit.attack_damage * mult)
	if unit.has_node("HealthBar"):
		unit.get_node("HealthBar").value = 100.0
	return unit

var sergeant_unit = null

func place_foot_soldier(pos):
	var unit = null
	match placing_unit_type:
		"foot_soldier":
			unit = foot_soldier_scene.instance()
		"archer":
			unit = archer_scene.instance()
		"cavalry":
			unit = cavalry_scene.instance()
	if unit:
		unit.position = pos
		add_child(unit)
		unit.set_base_position(pos)
		if selected_sergeant != "":
			apply_sergeant_bonus(unit)
		print("Placed " + placing_unit_type + " at " + str(pos))

func spawn_initial_buildings():
	match selected_sergeant:
		"infantry":
			print("Deploying spear infantry defenses")
		"archery":
			print("Deploying archery positions")
		"cavalry":
			print("Setting up cavalry rally points")

func start_next_wave():
	if game_over:
		return
	wave_number += 1
	emit_signal("wave_started", wave_number)
	print("Wave " + str(wave_number) + " starting")
	
	var enemy_count = wave_number
	for i in range(enemy_count):
		yield(get_tree().create_timer(2.0), "timeout")
		if game_over:
			return
		spawn_enemy()
	if has_node("UI/UIRoot/WaveLabel"):
		$UI/UIRoot/WaveLabel.text = "Wave: " + str(wave_number)

func spawn_enemy():
	var enemy = enemy_scene.instance()
	var base_pos = $TownCenter/Base.global_position
	enemy.set_base_position(base_pos)
	var spawn_pos = get_random_edge_position()
	enemy.position = spawn_pos
	enemy.connect("enemy_died", self, "_on_enemy_died", [enemy])
	enemy.connect("reached_base", self, "_on_enemy_reached_base", [enemy])
	$Enemies.add_child(enemy)
	enemies_alive += 1
	emit_signal("enemy_spawned", enemy)
	print("Spawned enemy at " + str(spawn_pos) + " (alive: " + str(enemies_alive) + ")")

func get_random_edge_position():
	var viewport = get_viewport_rect()
	var side = randi() % 4
	var x = 0
	var y = 0
	match side:
		0: # top
			x = rand_range(0, viewport.size.x)
			y = -50
		1: # bottom
			x = rand_range(0, viewport.size.x)
			y = viewport.size.y + 50
		2: # left
			x = -50
			y = rand_range(0, viewport.size.y)
		3: # right
			x = viewport.size.x + 50
			y = rand_range(0, viewport.size.y)
	return Vector2(x, y)

func _on_enemy_died(enemy):
	enemies_alive -= 1
	gold += 10
	if has_node("UI/UIRoot/GoldLabel"):
		$UI/UIRoot/GoldLabel.text = "Gold: " + str(gold)
	print("Enemy died! Gold: " + str(gold) + " (alive: " + str(enemies_alive) + ")")
	if enemies_alive <= 0 and wave_number < 10 and not game_over:
		yield(get_tree().create_timer(2.0), "timeout")
		start_next_wave()
	elif wave_number >= 10 and enemies_alive <= 0:
		print("Victory! All 10 waves survived!")

func _on_enemy_reached_base(enemy):
	enemies_alive -= 1
	if has_node("TownCenter/Base"):
		$TownCenter/Base.take_damage(10)
		var base_hp = $TownCenter/Base.get_hp()
		var unit_count = get_tree().get_nodes_in_group("units").size()
		print("Enemy reached base! Base HP: " + str(base_hp) + " (enemies alive: " + str(enemies_alive) + ", units placed: " + str(unit_count) + ")")
		if base_hp <= 0:
			print("DEBUG: Base destroyed by enemy reaching base")
	else:
		print("ERROR: Base node not found!")
	if enemies_alive <= 0 and wave_number < 10 and not game_over:
		yield(get_tree().create_timer(2.0), "timeout")
		start_next_wave()

func _on_base_destroyed():
	print("Game Over! Base destroyed.")
	if has_node("TownCenter/Base"):
		$TownCenter/Base.game_over = true
	game_over = true
	get_tree().paused = true
	# Show game over screen
	if has_node("GameOverScreen"):
		$GameOverScreen.visible = true

func _on_base_hp_changed(current, max_hp):
	base_hp = current
	if has_node("UI/UIRoot/HPBar"):
		$UI/UIRoot/HPBar.value = float(current) / float(max_hp) * 100
	if has_node("UI/UIRoot/GoldLabel"):
		$UI/UIRoot/GoldLabel.text = "Gold: " + str(gold)

func update_action_bar(obj):
	var action_bar = $UI/ActionBar
	if not action_bar:
		return
	if obj:
		action_bar.show()
		if action_bar.has_node("HBox/SelectedLabel"):
			var name = "Unknown"
			if obj.has_method("get_script") and obj.get_script():
				var script_path = obj.get_script().resource_path
				name = script_path.get_file().get_basename().capitalize().replace("_", " ")
			elif obj.filename:
				name = obj.filename.get_file().get_basename().capitalize()
			else:
				name = "Town Center"
			action_bar.get_node("HBox/SelectedLabel").text = name
		if action_bar.has_node("HBox/HPInfo"):
			var hp = obj.get_hp() if obj.has_method("get_hp") else (obj.current_hp if "current_hp" in obj else 0)
			var max_hp_val = obj.get_max_hp() if obj.has_method("get_max_hp") else (obj.max_hp if "max_hp" in obj else 0)
			action_bar.get_node("HBox/HPInfo").text = "HP: " + str(hp) + "/" + str(max_hp_val)
	else:
		action_bar.hide()
		if action_bar.has_node("HBox/SelectedLabel"):
			action_bar.get_node("HBox/SelectedLabel").text = ""

func _on_PauseBtn_pressed():
	if has_node("UI/PauseMenu"):
		$UI/PauseMenu.visible = not $UI/PauseMenu.visible
		get_tree().paused = $UI/PauseMenu.visible

func _on_ResumeBtn_pressed():
	if has_node("UI/PauseMenu"):
		$UI/PauseMenu.visible = false
		get_tree().paused = false

func _on_ExitBtn_pressed():
	get_tree().quit()

func toggle_pause():
	if has_node("UI/PauseMenu"):
		$UI/PauseMenu.visible = not $UI/PauseMenu.visible
		get_tree().paused = $UI/PauseMenu.visible
