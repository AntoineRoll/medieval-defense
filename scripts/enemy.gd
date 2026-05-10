extends Area2D

signal enemy_died
signal reached_base

export var max_hp = 50
export var speed = 80
var current_hp = 50
var base_position = Vector2(640, 360)
var dead = false
var current_target = null
var attack_range = 20
var attack_damage = 10
var attack_cooldown = 1.0
var attack_timer = 0.0
var detection_radius = 300

func _ready():
	current_hp = max_hp
	update()
	add_to_group("enemies")

func find_best_target():
	var best_target = null
	var best_dist = detection_radius
	
	# Check units first
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		var dist = global_position.distance_to(unit.global_position)
		if dist <= detection_radius and dist < best_dist:
			best_target = unit
			best_dist = dist
	
	# Then buildings (including base)
	if best_target == null:
		var buildings = get_tree().get_nodes_in_group("buildings")
		for building in buildings:
			var dist = global_position.distance_to(building.global_position)
			if dist <= detection_radius and dist < best_dist:
				best_target = building
				best_dist = dist
	
	# If no target found, move toward base position
	if best_target == null:
		pass  # Will use base_position in _process
	
	return best_target

func _draw():
	draw_circle(Vector2(0, 0), 12, Color(0.8, 0.2, 0.2))

func _process(delta):
	if dead:
		return
	
	var best_target = find_best_target()
	if best_target != null and best_target != current_target:
		current_target = best_target
	
	if current_target != null and is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= attack_range:
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = attack_cooldown
				current_target.take_damage(attack_damage)
		else:
			var direction = (current_target.global_position - global_position).normalized()
			position += direction * speed * delta
	else:
		var direction = (base_position - global_position).normalized()
		position += direction * speed * delta

func take_damage(amount):
	if dead:
		return
	current_target = null
	current_hp -= amount
	if has_node("HealthBar"):
		$HealthBar.visible = true
		$HealthBar.value = float(current_hp) / float(max_hp) * 100
	if current_hp <= 0:
		die()

func die():
	dead = true
	emit_signal("enemy_died")
	queue_free()

func set_base_position(pos):
	base_position = pos

func get_hp():
	return current_hp

func get_max_hp():
	return max_hp
