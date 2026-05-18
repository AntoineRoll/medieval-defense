extends Area2D

var speed: float = 400.0
var damage: int = 8
var target: Node2D = null
var target_pos: Vector2 = Vector2.ZERO

var _hit: bool = false

@onready var _hitbox: Hitbox = $Hitbox
@onready var _sprite: Sprite2D = $Sprite
@onready var _timer: Timer = $Timer


func _ready() -> void:
	_hitbox.damage = damage
	if target:
		target_pos = target.global_position
		var dir: Vector2 = (target_pos - global_position).normalized()
		_sprite.rotation = dir.angle()
	add_to_group("projectiles")
	_timer.timeout.connect(_on_timeout)
	_timer.start(3.0)
	EventBus.enemy_died.connect(_on_target_enemy_died)


func _physics_process(delta: float) -> void:
	if _hit:
		return
	if not is_instance_valid(target):
		set_physics_process(false)
		ObjectPool.return_to_pool(self)
		return

	target_pos = target.global_position
	var dir: Vector2 = (target_pos - global_position).normalized()
	_sprite.rotation = dir.angle()

	var motion: Vector2 = dir * speed * delta
	var dist_to_target: float = global_position.distance_to(target_pos)

	if dist_to_target <= motion.length():
		global_position = target_pos
		_hit = true
		_hitbox.monitoring = false
		_hitbox.monitorable = false
		_timer.start(0.05)
		set_physics_process(false)
		return

	position += motion


func _on_target_enemy_died(enemy: Node2D) -> void:
	if target == enemy and not _hit:
		target = null
		_hit = true
		set_physics_process(false)
		ObjectPool.return_to_pool(self)


func _on_timeout() -> void:
	ObjectPool.return_to_pool(self)


func reset_pooled() -> void:
	_hit = false
	_hitbox.reset()
	_timer.stop()
	_timer.start(3.0)
	visible = true
	process_mode = PROCESS_MODE_INHERIT
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	target = null
