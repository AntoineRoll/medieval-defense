class_name Tower
extends Node2D

signal hp_changed(current_hp: int, max_hp: int)
signal tower_destroyed

@export var max_hp: int = 80
@export var attack_range: float = 256.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.0

var current_hp: int
var selected: bool = false
var hovered: bool = false
var click_radius: float = 32.0
var hitbox_radius: float = 32.0
var debug_show_hitbox: bool = true

var _attack_timer: float = 1.0
var _destroyed: bool = false

@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _detection_area: DetectionArea = $DetectionArea


func _ready() -> void:
	current_hp = max_hp
	add_to_group("buildings")
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
	if selected:
		_draw_tile_circle(attack_range, Color(1, 0, 0, 0.15))
		_draw_tile_circle(click_radius, Color(1, 1, 0, 0.2))


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
	take_damage(hitbox.damage)


func take_damage(amount: int) -> void:
	if _destroyed:
		return
	current_hp -= amount
	current_hp = max(0, current_hp)
	hp_changed.emit(current_hp, max_hp)
	queue_redraw()
	if current_hp <= 0:
		_destroyed = true
		tower_destroyed.emit()
		queue_free()


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


func get_hitbox_radius() -> float:
	return hitbox_radius


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp
