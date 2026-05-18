class_name Main
extends Node2D

var foot_soldier_scene: PackedScene = preload("res://scenes/units/foot_soldier.tscn")
var archer_scene: PackedScene = preload("res://scenes/units/archer.tscn")
var cavalry_scene: PackedScene = preload("res://scenes/units/cavalry.tscn")
var tower_scene: PackedScene = preload("res://scenes/buildings/tower.tscn")

var foot_soldier_stats: Resource = preload("res://resources/foot_soldier_stats.tres")
var archer_stats: Resource = preload("res://resources/archer_stats.tres")
var cavalry_stats: Resource = preload("res://resources/cavalry_stats.tres")

var foot_soldier_texture: Texture2D = preload("res://assets/sprites/infantry_sergeant.png")
var archer_texture: Texture2D = preload("res://assets/sprites/archery_sergeant.png")
var cavalry_texture: Texture2D = preload("res://assets/sprites/cavalry_sergeant.png")
var tower_texture: Texture2D = preload("res://assets/sprites/tower_wood.png")
var gold_res_texture: Texture2D = preload("res://assets/sprites/gold_res_128.png")

var _placement_preview: Sprite2D
var _custom_tooltip: Control

var placing_unit: bool = false
var placing_unit_type: String = "foot_soldier"
var unit_cost: int = 50
var selected_units: Array = []
var selected_building: Node2D = null
var _hovered_entity: Node2D = null
var auto_place_units: bool = false
var auto_place_timer: float = 0.0

@onready var town_center: Node2D = $TownCenter
@onready var base_node: Node2D = $TownCenter/Base
@onready var enemies_node: Node2D = $Enemies
@onready var map_node: Node2D = $Map
@onready var grid_overlay: Node2D = $GridOverlay
@onready var wave_manager: Node = $WaveManager

@onready var ui_root: Control = $UI/UIRoot
@onready var pause_menu = $UI/PauseMenu
@onready var info_panel: Control = $UI/InfoPanel
@onready var sergeant_bonus: Control = $UI/SergeantBonus
@onready var sergeant_shield: Sprite2D = $UI/SergeantBonus/Shield
@onready var sergeant_label: Label = $UI/SergeantBonus/Label
@onready var gold_label: Label = %GoldLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_text: Label = %HPText
@onready var gold_icon: TextureRect = %GoldIcon
@onready var wave_label: Label = %WaveLabel
@onready var foot_soldier_btn: Button = %FootSoldierBtn
@onready var archer_btn: Button = %ArcherBtn
@onready var cavalry_btn: Button = %CavalryBtn
@onready var tower_btn: Button = %TowerBtn
@onready var pause_btn: Button = %PauseBtn
@onready var skip_btn: Button = %SkipBtn
@onready var title_screen_node: Node2D = $TitleScreen
@onready var title_canvas: CanvasLayer = $TitleScreen/CanvasLayer
@onready var sergeant_canvas: CanvasLayer = $SergeantSelect/CanvasLayer
@onready var game_over_canvas: CanvasLayer = $GameOverScreen/CanvasLayer
@onready var map_background: Control = $BackgroundLayer/Background
@onready var sergeant_select_node: Node2D = $SergeantSelect
@onready var game_over_screen_node: Node2D = $GameOverScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_placement_preview = Sprite2D.new()
	_placement_preview.visible = false
	_placement_preview.z_index = 100
	add_child(_placement_preview)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.base_hp_changed.connect(_on_base_hp_changed)
	EventBus.base_destroyed.connect(_on_base_destroyed)
	EventBus.wave_countdown.connect(_on_wave_countdown)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.unit_deselected.connect(_on_unit_deselected)
	EventBus.unit_died.connect(_on_unit_died)
	StateMachine.state_changed.connect(_on_state_machine_changed)

	foot_soldier_btn.button_down.connect(_on_foot_soldier_btn_pressed)
	archer_btn.button_down.connect(_on_archer_btn_pressed)
	cavalry_btn.button_down.connect(_on_cavalry_btn_pressed)
	tower_btn.button_down.connect(_on_tower_btn_pressed)
	pause_btn.button_down.connect(_on_pause_btn_pressed)
	skip_btn.button_down.connect(_on_skip_btn_pressed)

	GridManager.clear_all()
	GridManager.occupy_rect(Vector2i(8, 4), Vector2i(2, 2), base_node)

	_update_button_states()

	title_screen_node.play_pressed.connect(_on_title_play_pressed)
	title_screen_node.quit_pressed.connect(_on_title_quit_pressed)
	sergeant_select_node.sergeant_selected.connect(_on_sergeant_selected)
	game_over_screen_node.replay_pressed.connect(_on_game_over_replay_pressed)
	game_over_screen_node.quit_pressed.connect(_on_game_over_quit_pressed)

	foot_soldier_btn.icon = _make_icon(foot_soldier_texture)
	archer_btn.icon = _make_icon(archer_texture)
	cavalry_btn.icon = _make_icon(cavalry_texture)
	tower_btn.icon = _make_icon(tower_texture)

	var btn_bg: StyleBoxFlat = StyleBoxFlat.new()
	btn_bg.bg_color = Color(1, 1, 1, 0.12)
	btn_bg.corner_radius_top_left = 4
	for btn in [foot_soldier_btn, archer_btn, cavalry_btn, tower_btn]:
		btn.add_theme_stylebox_override("normal", btn_bg)
		btn.add_theme_stylebox_override("hover", btn_bg)
		btn.add_theme_stylebox_override("pressed", btn_bg)

	foot_soldier_btn.tooltip_text = _format_tooltip("Foot Soldier", foot_soldier_stats, 50)
	archer_btn.tooltip_text = _format_tooltip("Archer", archer_stats, 75)
	cavalry_btn.tooltip_text = _format_tooltip("Cavalry", cavalry_stats, 100)
	tower_btn.tooltip_text = "Wood Tower\nCost: 25\nHP: 80\nDmg: 8\nRange: 128"

	_custom_tooltip = Panel.new()
	_custom_tooltip.visible = false
	_custom_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tt_hbox: HBoxContainer = HBoxContainer.new()
	tt_hbox.add_theme_constant_override("separation", 4)
	_custom_tooltip.add_child(tt_hbox)
	var tt_icon: TextureRect = TextureRect.new()
	tt_icon.texture = _make_icon(gold_res_texture)
	tt_icon.custom_minimum_size = Vector2(16, 16)
	tt_hbox.add_child(tt_icon)
	var tt_label: Label = Label.new()
	tt_label.add_theme_font_size_override("font_size", 14)
	tt_hbox.add_child(tt_label)
	$UI.add_child(_custom_tooltip)

	for btn in [foot_soldier_btn, archer_btn, cavalry_btn, tower_btn]:
		btn.mouse_entered.connect(_on_purchase_btn_mouse_entered.bind(btn))
		btn.mouse_exited.connect(_on_purchase_btn_mouse_exited)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.65)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.corner_radius_bottom_left = 8
	$UI/InfoPanel/Bg.add_theme_stylebox_override("panel", bg_style)

	var purchase_bg: StyleBoxFlat = StyleBoxFlat.new()
	purchase_bg.bg_color = Color(0.1, 0.1, 0.15, 0.65)
	purchase_bg.corner_radius_top_left = 8
	purchase_bg.corner_radius_top_right = 8
	purchase_bg.corner_radius_bottom_right = 8
	purchase_bg.corner_radius_bottom_left = 8
	$UI/PurchaseBar/Bg.add_theme_stylebox_override("panel", purchase_bg)

	_show_title_screen()


func _show_title_screen() -> void:
	town_center.visible = false
	map_node.visible = false
	grid_overlay.visible = false
	enemies_node.visible = false
	title_canvas.visible = true
	sergeant_canvas.visible = false
	sergeant_select_node.visible = false
	game_over_canvas.visible = false
	game_over_screen_node.visible = false
	map_background.visible = false
	ui_root.visible = false
	info_panel.visible = false
	$UI/PurchaseBar.visible = false
	sergeant_bonus.visible = false
	pause_menu.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
	if event is InputEventMouseButton and event.pressed and GameManager.state == GameManager.GameState.PLAYING:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if placing_unit and GameManager.can_afford(unit_cost):
				var pos: Vector2 = get_global_mouse_position()
				if _spawn_unit(pos):
					GameManager.spend_gold(unit_cost)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if placing_unit:
				placing_unit = false
				return
			if not selected_units.is_empty():
				var target_pos: Vector2 = get_global_mouse_position()
				var target_grid: Vector2i = GridManager.world_to_grid(target_pos)
				if not GridManager.is_valid(target_grid) or GridManager.is_occupied(target_grid):
					return
				var snapped: Vector2 = GridManager.grid_to_world(target_grid)
				for i in range(selected_units.size()):
					var unit_node = selected_units[i]
					if is_instance_valid(unit_node) and unit_node.is_in_group("units"):
						var grid_pos: Vector2i = target_grid + Vector2i(i, 0) if i > 0 else target_grid
						if GridManager.is_occupied(grid_pos):
							grid_pos = GridManager.find_nearest_empty(target_grid)
							if grid_pos == Vector2i(-1, -1):
								continue
						var old_grid: Vector2i = GridManager.get_entity_grid_pos(unit_node)
						if old_grid != Vector2i(-1, -1):
							GridManager.vacate(old_grid)
						GridManager.occupy(grid_pos, unit_node)
						unit_node.set_base_position(GridManager.grid_to_world(grid_pos))


func _process(delta: float) -> void:
	_hover_check()
	if placing_unit:
		var pos: Vector2 = get_global_mouse_position()
		var snapped: Vector2 = GridManager.snap_to_grid(pos)
		_placement_preview.position = snapped
		_placement_preview.visible = true
		var grid_pos: Vector2i = GridManager.world_to_grid(pos)
		var valid: bool = GridManager.is_valid(grid_pos) and not GridManager.is_occupied(grid_pos) and GameManager.can_afford(unit_cost)
		_placement_preview.modulate = Color(1, 1, 1, 0.5) if valid else Color(1, 0.3, 0.3, 0.5)
		match placing_unit_type:
			"foot_soldier":
				_placement_preview.texture = foot_soldier_texture
			"archer":
				_placement_preview.texture = archer_texture
			"cavalry":
				_placement_preview.texture = cavalry_texture
			"tower":
				_placement_preview.texture = tower_texture
	else:
		_placement_preview.visible = false
	if auto_place_units and GameManager.state == GameManager.GameState.PLAYING:
		auto_place_timer -= delta
		if auto_place_timer <= 0:
			auto_place_timer = 3.0
			auto_place_unit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and GameManager.state == GameManager.GameState.PLAYING:
		var clicked_unit = _get_clicked_unit(event)
		if clicked_unit:
			if clicked_unit.selected:
				clicked_unit.set_selected(false)
			else:
				_deselect_all()
				clicked_unit.set_selected(true)
			return

		var clicked_building = _get_clicked_building(event)
		if clicked_building:
			if clicked_building.selected:
				clicked_building.set_selected(false)
			else:
				_deselect_all()
				clicked_building.set_selected(true)
			return

		if base_node and base_node.is_clicked(event):
			_deselect_all()
			base_node.set_selected(true)
			return

		_deselect_all()


func _deselect_all() -> void:
	for unit_node in get_tree().get_nodes_in_group("units"):
		if unit_node.selected:
			unit_node.set_selected(false)
	for building_node in get_tree().get_nodes_in_group("buildings"):
		if building_node.has_method("set_selected") and building_node.selected:
			building_node.set_selected(false)
	base_node.set_selected(false)
	EventBus.unit_deselected.emit()


func _get_clicked_unit(event: InputEvent):
	for unit_node in get_tree().get_nodes_in_group("units"):
		if unit_node.is_clicked(event):
			return unit_node
	return null


func _get_clicked_building(event: InputEvent):
	for building_node in get_tree().get_nodes_in_group("buildings"):
		if building_node != base_node and building_node.has_method("is_clicked") and building_node.is_clicked(event):
			return building_node
	return null


func _spawn_unit(pos: Vector2) -> bool:
	if placing_unit_type == "tower":
		return _spawn_tower(pos)
	if not _is_placement_valid(pos):
		return false
	var unit = null
	match placing_unit_type:
		"foot_soldier":
			unit = foot_soldier_scene.instantiate()
		"archer":
			unit = archer_scene.instantiate()
		"cavalry":
			unit = cavalry_scene.instantiate()
	if unit:
		var grid_pos: Vector2i = GridManager.world_to_grid(pos)
		var snapped: Vector2 = GridManager.grid_to_world(grid_pos)
		unit.position = snapped
		add_child(unit)
		GridManager.occupy(grid_pos, unit)
		unit.tree_exited.connect(_on_entity_tree_exited.bind(unit))
		if not unit.set_base_position(snapped):
			GridManager.vacate_entity(unit)
			unit.queue_free()
			return false
		if GameManager.selected_sergeant != "":
			GameManager.apply_sergeant_bonus(unit)
		return true
	return false


func _spawn_tower(pos: Vector2) -> bool:
	if not _is_placement_valid(pos):
		return false
	var tower: Node2D = tower_scene.instantiate()
	var grid_pos: Vector2i = GridManager.world_to_grid(pos)
	var snapped: Vector2 = GridManager.grid_to_world(grid_pos)
	tower.position = snapped
	add_child(tower)
	GridManager.occupy(grid_pos, tower)
	tower.tree_exited.connect(_on_entity_tree_exited.bind(tower))
	return true


func auto_place_unit() -> void:
	if not auto_place_units:
		return
	if not GameManager.can_afford(unit_cost):
		return

	var unit = null
	match placing_unit_type:
		"foot_soldier":
			unit = foot_soldier_scene.instantiate()
		"archer":
			unit = archer_scene.instantiate()
		"cavalry":
			unit = cavalry_scene.instantiate()

	if unit:
		var angle: float = randf_range(0, TAU)
		var distance: float = randf_range(100, 200)
		var pos: Vector2 = town_center.position + Vector2(cos(angle), sin(angle)) * distance
		if not _is_placement_valid(pos):
			unit.queue_free()
			return
		var grid_pos: Vector2i = GridManager.world_to_grid(pos)
		var snapped: Vector2 = GridManager.grid_to_world(grid_pos)
		unit.position = snapped
		add_child(unit)
		GridManager.occupy(grid_pos, unit)
		unit.tree_exited.connect(_on_entity_tree_exited.bind(unit))
		if not unit.set_base_position(snapped):
			GridManager.vacate_entity(unit)
			unit.queue_free()
			return
		if GameManager.selected_sergeant != "":
			GameManager.apply_sergeant_bonus(unit)
		GameManager.spend_gold(unit_cost)


func _is_placement_valid(pos: Vector2) -> bool:
	var grid_pos: Vector2i = GridManager.world_to_grid(pos)
	return GridManager.is_valid(grid_pos) and not GridManager.is_occupied(grid_pos)


func _update_sergeant_display(sergeant_type: String) -> void:
	var icon_map: Dictionary = {
		"infantry": foot_soldier_texture,
		"archery": archer_texture,
		"cavalry": cavalry_texture
	}
	var label_map: Dictionary = {
		"infantry": "Infantry Sgt\n+20% to Foot Soldiers",
		"archery": "Archery Sgt\n+20% to Archers",
		"cavalry": "Cavalry Sgt\n+20% to Cavalry"
	}
	var tex: Texture2D = icon_map.get(sergeant_type)
	if tex:
		sergeant_shield.texture = tex
		sergeant_shield.visible = true
		sergeant_label.text = label_map.get(sergeant_type, "")
		sergeant_label.visible = true


func _make_icon(tex: Texture2D) -> ImageTexture:
	var img: Image = tex.get_image()
	img.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _hover_check() -> void:
	var new_hover: Node2D = null
	if GameManager.state == GameManager.GameState.PLAYING and not placing_unit:
		var mouse_pos: Vector2 = get_global_mouse_position()
		for unit in get_tree().get_nodes_in_group("units"):
			var diff: Vector2 = mouse_pos - unit.global_position
			if abs(diff.x) < unit.click_radius and abs(diff.y) < unit.click_radius:
				new_hover = unit
				break
		if new_hover == null:
			for building in get_tree().get_nodes_in_group("buildings"):
				if building.has_method("is_clicked"):
					var diff: Vector2 = mouse_pos - building.global_position
					if abs(diff.x) < building.click_radius and abs(diff.y) < building.click_radius:
						new_hover = building
						break
		if new_hover == null and base_node:
			var diff: Vector2 = mouse_pos - base_node.global_position
			if abs(diff.x) < base_node.click_radius and abs(diff.y) < base_node.click_radius:
				new_hover = base_node
	if new_hover != _hovered_entity:
		if _hovered_entity and _hovered_entity.has_method("set_hovered"):
			_hovered_entity.set_hovered(false)
		_hovered_entity = new_hover
		if _hovered_entity and _hovered_entity.has_method("set_hovered"):
			_hovered_entity.set_hovered(true)


func _format_tooltip(name_str: String, s: Resource, cost: int) -> String:
	var range_type: String = "Ranged: " + str(s.attack_range) if s.is_ranged else "Melee"
	return name_str + "\nCost: " + str(cost) + "\nHP: " + str(s.max_hp) + "\nDmg: " + str(s.attack_damage) + "\n" + range_type + "\nSpd: " + str(s.speed)


func _toggle_pause() -> void:
	pause_menu.toggle()


# === Button handlers ===

func _update_button_states() -> void:
	var can_play: bool = GameManager.state == GameManager.GameState.PLAYING
	foot_soldier_btn.disabled = not can_play or not GameManager.can_afford(GameManager.FOOT_SOLDIER_COST)
	archer_btn.disabled = not can_play or not GameManager.can_afford(GameManager.ARCHER_COST)
	cavalry_btn.disabled = not can_play or not GameManager.can_afford(GameManager.CAVALRY_COST)
	tower_btn.disabled = not can_play or not GameManager.can_afford(GameManager.TOWER_COST)


func _on_foot_soldier_btn_pressed() -> void:
	placing_unit = true
	placing_unit_type = "foot_soldier"
	unit_cost = GameManager.FOOT_SOLDIER_COST


func _on_archer_btn_pressed() -> void:
	placing_unit = true
	placing_unit_type = "archer"
	unit_cost = GameManager.ARCHER_COST


func _on_cavalry_btn_pressed() -> void:
	placing_unit = true
	placing_unit_type = "cavalry"
	unit_cost = GameManager.CAVALRY_COST


func _on_tower_btn_pressed() -> void:
	placing_unit = true
	placing_unit_type = "tower"
	unit_cost = GameManager.TOWER_COST


func _on_pause_btn_pressed() -> void:
	_toggle_pause()


func _on_skip_btn_pressed() -> void:
	skip_btn.visible = false
	wave_manager.skip_wave_countdown()


func _on_title_play_pressed() -> void:
	print("Title play pressed - switching to sergeant select")
	title_canvas.visible = false
	sergeant_canvas.visible = true
	sergeant_select_node.visible = true


func _on_title_quit_pressed() -> void:
	get_tree().quit()


func _on_sergeant_selected(sergeant_type: String) -> void:
	GameManager.start_game(sergeant_type)
	GridManager.clear_all()
	GridManager.occupy_rect(Vector2i(8, 4), Vector2i(2, 2), base_node)
	sergeant_canvas.visible = false
	sergeant_select_node.visible = false
	map_background.visible = true
	town_center.visible = true
	grid_overlay.visible = true
	enemies_node.visible = true
	map_node.visible = true
	ui_root.visible = true
	sergeant_bonus.visible = true
	info_panel.visible = true
	$UI/PurchaseBar.visible = true
	gold_label.text = str(GameManager.gold)
	_update_button_states()
	_update_sergeant_display(sergeant_type)
	wave_manager.start_wave(1)


func _do_sergeant_selected(sergeant_type: String) -> void:
	_on_sergeant_selected(sergeant_type)


func _on_game_over_replay_pressed() -> void:
	GameManager.reset_game()
	get_tree().paused = false
	_show_title_screen()


func _on_game_over_quit_pressed() -> void:
	get_tree().quit()


# === Signal handlers ===

func _on_gold_changed(amount: int) -> void:
	gold_label.text = str(amount)
	var tween: Tween = create_tween()
	gold_label.modulate = Color(1, 1, 0)
	tween.tween_property(gold_label, "modulate", Color(1, 1, 1), 0.3)
	_update_button_states()


func _on_base_hp_changed(current: int, max_hp_val: int) -> void:
	hp_bar.value = float(current) / float(max_hp_val) * 100
	hp_text.text = "HP: " + str(current) + "/" + str(max_hp_val)


func _on_base_destroyed() -> void:
	GameManager.end_game(false)
	get_tree().paused = true
	game_over_screen_node.set_title(false)
	game_over_canvas.visible = true
	game_over_screen_node.visible = true
	skip_btn.visible = false


func _on_wave_countdown(wave_number: int, seconds_left: int) -> void:
	wave_label.text = "Wave " + str(wave_number) + " / 10\nEnemies incoming! (" + str(seconds_left) + "s)"
	skip_btn.visible = true


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave " + str(wave_number) + " / 10"
	skip_btn.visible = false


func _on_unit_selected(unit_node: Node2D) -> void:
	selected_units = [unit_node]
	_update_action_bar(unit_node)


func _on_unit_deselected() -> void:
	selected_units = []
	_update_action_bar(null)


func _on_unit_died(unit: Node2D) -> void:
	if unit in selected_units:
		selected_units.erase(unit)
		if selected_units.is_empty():
			_update_action_bar(null)


func _on_purchase_btn_mouse_entered(btn: Button) -> void:
	var tt_label: Label = _custom_tooltip.get_child(0).get_child(1)
	tt_label.text = btn.tooltip_text
	_custom_tooltip.position = get_global_mouse_position() + Vector2(10, -20)
	_custom_tooltip.visible = true


func _on_purchase_btn_mouse_exited() -> void:
	_custom_tooltip.visible = false


func _on_entity_tree_exited(entity: Node2D) -> void:
	GridManager.vacate_entity(entity)


func _on_state_machine_changed(_from: StateMachine.State, to: StateMachine.State) -> void:
	if to == StateMachine.State.WON:
		GameManager.end_game(true)
		get_tree().paused = true
		game_over_screen_node.set_title(true)
		game_over_canvas.visible = true
		game_over_screen_node.visible = true


func _update_action_bar(obj: Node2D) -> void:
	if not info_panel:
		return
	var name_label: Label = info_panel.get_node("VBox/SelectedLabel")
	var hp_info: Label = info_panel.get_node("VBox/HPInfo")
	if obj:
		info_panel.visible = true
		var name_str: String = "Unknown"
		if obj.get_script():
			name_str = obj.get_script().resource_path.get_file().get_basename().capitalize().replace("_", " ")
		elif "scene_file_path" in obj and obj.scene_file_path:
			name_str = obj.scene_file_path.get_file().get_basename().capitalize()
		else:
			name_str = "Town Center"
		name_label.text = name_str
		var hp: int = obj.get_hp() if obj.has_method("get_hp") else 0
		var max_hp_val: int = obj.get_max_hp() if obj.has_method("get_max_hp") else 0
		hp_info.text = "HP: " + str(hp) + "/" + str(max_hp_val)
	else:
		info_panel.visible = false
