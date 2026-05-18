class_name Base
extends Node2D

signal hp_changed(current_hp: int, max_hp: int)

@export var max_hp: int = 200
@export var attack_range: float = 0.0
@export var attack_damage: int = 0
@export var attack_cooldown: float = 1.0

var current_hp: int = 200
var selected: bool = false
var hovered: bool = false
var click_radius: float = 64.0
var hitbox_radius: float = 64.0
var debug_show_hitbox: bool = true

var _game_over: bool = false
var _damage_events: int = 0
var _attack_timer: float = 1.0

@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _detection_area: DetectionArea = $DetectionArea


func _ready() -> void:
	current_hp = max_hp
	add_to_group("buildings")
	add_to_group("base")
	if attack_range > 0:
		_detection_area.set_radius(attack_range)
	_hurtbox.hurt.connect(_on_hurt)


func _draw_tile_circle(radius: float, color: Color) -> void:
	var tile_size: float = 64.0
	var half_tile: float = tile_size * 0.5
	var tiles_radius: int = int(ceil(radius / tile_size))
	for x in range(-tiles_radius, tiles_radius + 1):
		for y in range(-tiles_radius, tiles_radius + 1):
			var cx: float = x * tile_size + half_tile
			var cy: float = y * tile_size + half_tile
			if sqrt(cx * cx + cy * cy) <= radius + half_tile:
				draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), color)


func _draw() -> void:
	if debug_show_hitbox:
		draw_rect(Rect2(-hitbox_radius, -hitbox_radius, hitbox_radius * 2, hitbox_radius * 2), Color.BLACK, false, 1.0)
	if hovered:
		_draw_tile_circle(click_radius, Color(1, 1, 0, 0.1))
	draw_rect(Rect2(-30, -50, 60, 10), Color(0.3, 0.3, 0.3))
	var bar_width: float = 60.0
	var bar_height: float = 8.0
	var pos: Vector2 = Vector2(-bar_width / 2, -50)
	var ratio: float = float(current_hp) / float(max_hp)
	draw_rect(Rect2(pos, Vector2(bar_width, bar_height)), Color(1, 0, 0))
	var fill_color: Color = Color(0, 1, 0) if ratio > 0.5 else Color(1, 1, 0) if ratio > 0.25 else Color(1, 0, 0)
	draw_rect(Rect2(pos, Vector2(bar_width * ratio, bar_height)), fill_color)
	if selected:
		_draw_tile_circle(click_radius, Color(1, 1, 0, 0.2))


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp


func get_hitbox_radius() -> float:
	return hitbox_radius


func _process(delta: float) -> void:
	if attack_range <= 0 or attack_damage <= 0:
		return
	var target: Node2D = _detection_area.get_closest(global_position)
	if target:
		_attack_timer -= delta
		if _attack_timer <= 0:
			_attack_timer = attack_cooldown
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)


func is_clicked(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var diff: Vector2 = get_global_mouse_position() - global_position
		return abs(diff.x) < click_radius and abs(diff.y) < click_radius
	return false


func _on_hurt(hitbox: Area2D) -> void:
	var src: String = "unknown"
	if hitbox.get_parent():
		src = hitbox.get_parent().name
	print("DAMAGE: Base hit by ", src, " for ", hitbox.damage)
	take_damage(hitbox.damage)


func take_damage(amount: int) -> void:
	if _game_over:
		return
	_damage_events += 1
	current_hp -= amount
	current_hp = max(0, current_hp)
	print("DAMAGE: Base took ", amount, " HP: ", current_hp, "/", max_hp)
	EventBus.base_hp_changed.emit(current_hp, max_hp)
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()
	if current_hp <= 0:
		_game_over = true
		EventBus.base_destroyed.emit()


func set_hovered(value: bool) -> void:
	hovered = value
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()
	if value:
		EventBus.unit_selected.emit(self)
	else:
		EventBus.unit_deselected.emit()
