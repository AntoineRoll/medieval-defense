extends Area2D

signal selected_changed(unit, is_selected)

var speed = 150
var target_position = null
var selected = false
var click_radius = 60
var attack_radius = 120
var attack_range = 20
var attack_damage = 10
var attack_cooldown = 1.0
var attack_timer = 0.0
var current_target = null
var auto_engaging = true
var max_hp = 50
var current_hp = 50
var is_ranged = false
var base_position = Vector2.ZERO
var returning_to_base = false

func setup_stats(new_max_hp, new_speed, new_attack_radius, new_attack_range, new_attack_damage, new_attack_cooldown, new_is_ranged=false):
	max_hp = new_max_hp
	current_hp = new_max_hp
	speed = new_speed
	attack_radius = new_attack_radius
	attack_range = new_attack_range
	attack_damage = new_attack_damage
	attack_cooldown = new_attack_cooldown
	is_ranged = new_is_ranged
	if has_node("HealthBar"):
		$HealthBar.visible = (current_hp < max_hp)
		$HealthBar.value = float(current_hp) / float(max_hp) * 100

func _ready():
	current_hp = max_hp
	add_to_group("units")
	if has_node("HealthBar"):
		$HealthBar.visible = (current_hp < max_hp)
		$HealthBar.value = float(current_hp) / float(max_hp) * 100

func is_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		return get_global_mouse_position().distance_to(global_position) < click_radius
	return false

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_RIGHT and selected:
			move_to(get_global_mouse_position())
			auto_engaging = false
			current_target = null

func set_base_position(pos):
	base_position = pos
	if base_position != Vector2.ZERO and position == Vector2.ZERO:
		position = base_position

func move_to(pos):
	target_position = pos
	returning_to_base = false

func _return_to_base():
	if base_position != Vector2.ZERO and position.distance_to(base_position) > 5:
		target_position = base_position
		returning_to_base = true
		auto_engaging = false

func _process(delta):
	if target_position != null:
		var direction = target_position - position
		if direction.length() < speed * delta:
			position = target_position
			target_position = null
			if returning_to_base:
				returning_to_base = false
			# After any movement completes, check if we should return to base
			if current_target == null:
				_return_to_base()
			else:
				auto_engaging = true
		else:
			var facing_left = direction.x < 0
			$Sprite.flip_h = facing_left
			$SelectionIndicator.flip_h = facing_left
			position += direction.normalized() * speed * delta
	if auto_engaging and current_target == null and not returning_to_base:
		find_target()
		if current_target:
			print("Unit found target at distance: " + str(position.distance_to(current_target.position)))
	if current_target != null:
		if not is_instance_valid(current_target):
			current_target = null
			target_position = null
			_return_to_base()
		else:
			var dist = current_target.position.distance_to(position)
			if dist <= attack_range:
				target_position = null
				attack_timer -= delta
				if attack_timer <= 0:
					attack_timer = attack_cooldown
					current_target.take_damage(attack_damage)
					print("Unit attacked enemy! Enemy HP: " + str(current_target.get_hp()))
			elif not is_ranged:
				var direction = (current_target.position - position).normalized()
				position += direction * speed * delta
	elif returning_to_base and target_position == null:
		_return_to_base()

func find_target():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest = null
	var closest_dist = attack_radius
	for enemy in enemies:
		var dist = enemy.position.distance_to(position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	current_target = closest
	if current_target:
		print("Unit found target at distance: " + str(closest_dist))
		target_position = current_target.position

func set_selected(value):
	selected = value
	$SelectionIndicator.visible = selected
	update()
	emit_signal("selected_changed", self, selected)
	var main = get_tree().current_scene
	if main and main.has_method("update_action_bar"):
		if value:
			main.update_action_bar(self)
		else:
			main.update_action_bar(null)

func take_damage(amount):
	current_hp -= amount
	if has_node("HealthBar"):
		$HealthBar.visible = true
		$HealthBar.value = float(current_hp) / float(max_hp) * 100
	if current_hp <= 0:
		queue_free()

func _draw():
	if selected:
		draw_circle(Vector2(0, 0), attack_radius, Color(1, 1, 0, 0.1))
		draw_circle(Vector2(0, 0), attack_range, Color(1, 0, 0, 0.2))
