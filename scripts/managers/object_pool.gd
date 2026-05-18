extends Node

var _pools: Dictionary = {}
var _pending_returns: Array[Node] = []


func get_from_pool(scene: PackedScene) -> Node:
	var path: String = scene.resource_path
	if not _pools.has(path):
		return null
	var pool: Array = _pools[path]
	while pool.size() > 0:
		var obj = pool.pop_back()
		if is_instance_valid(obj):
			if obj.has_method(&"reset_pooled"):
				obj.reset_pooled()
			if obj.get_parent():
				obj.get_parent().remove_child(obj)
			return obj
	return null


func return_to_pool(obj: Node) -> void:
	if not is_instance_valid(obj):
		return
	var path: String = obj.scene_file_path
	if path.is_empty():
		obj.queue_free()
		return
	if not Engine.is_in_physics_frame():
		_finish_return_to_pool(obj)
		return
	if obj in _pending_returns:
		return
	_pending_returns.append(obj)
	call_deferred("_deferred_return_to_pool", obj)


func _deferred_return_to_pool(obj: Node) -> void:
	_pending_returns.erase(obj)
	_finish_return_to_pool(obj)


func _finish_return_to_pool(obj: Node) -> void:
	if not is_instance_valid(obj):
		return
	var path: String = obj.scene_file_path
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	obj.process_mode = PROCESS_MODE_DISABLED
	obj.visible = false
	if obj is Area2D:
		obj.monitoring = false
		obj.monitorable = false
	var children: Array[Node] = obj.get_children(true)
	for child in children:
		if is_instance_valid(child) and child is Area2D:
			child.monitoring = false
			child.monitorable = false
	add_child(obj)
	if not _pools.has(path):
		_pools[path] = []
	_pools[path].append(obj)


