# Object Pooling / Entity Lifecycle in Godot 4

## References

- Godot Docs — Nodes and scene instances (queue_free, remove_child, reparent): https://docs.godotengine.org/en/4.5/tutorials/scripting/nodes_and_scene_instances.html
- Godot Docs — Optimization using Servers (RenderingServer, PhysicsServer2D as pooling alternative): https://docs.godotengine.org/en/4.6/tutorials/performance/using_servers.html
- Godot Docs — Signal class (connect, disconnect, is_connected): https://docs.godotengine.org/en/4.5/classes/class_signal.html
- Godot Proposal #14752 — Built-in Object Pool Nodes (community desire for native pooling): https://github.com/godotengine/godot-proposals/issues/14752
- Godot Proposal #14118 — Pool Object boolean property on Nodes: https://github.com/godotengine/godot-proposals/issues/14118
- Godot Repo #addons/godot-object-pool (older Godot 3 pool addon): https://github.com/godot-addons/godot-object-pool
- q8geek/Godot-4-Basic-Dynamic-Pool (C# pool): https://github.com/q8geek/Godot-4-Basic-Dynamic-Pool
- dxdesjardins/GDPool (C# pool with PoolManager singleton): https://github.com/dxdesjardins/GDPool
- AzyrGames/GodotProjectileEngine (object-pooled projectile system): https://github.com/AzyrGames/GodotProjectileEngine
- DeviousPulsar/qurobullet (bullet-hell projectile pool using non-node bullets): https://github.com/DeviousPulsar/qurobullet
- raduacg/game-mechanics-optimizations — Object Pooling pattern: https://github.com/raduacg/game-mechanics-optimizations/blob/main/01_object_pooling.md
- thedivergentai/gd-agentic-skills — object_pool_system.gd: https://github.com/thedivergentai/gd-agentic-skills/blob/HEAD/skills/godot-performance-optimization/scripts/object_pool_system.gd
- wshobson/agents — godot-gdscript-patterns (includes object pool with signal cleanup): https://skills.sh/wshobson/agents/godot-gdscript-patterns
- UhiyamaLab — Complete Guide to Object Pooling in Godot: https://uhiyama-lab.com/en/notes/godot/godot-object-pooling-basics
- Godot Forum — Performance drops when instantiating thousands of objects: https://forum.godotengine.org/t/performance-drops-when-instantiating-thousands-of-objects/105227
- Godot Issue #71182 — Godot 4.x significantly slower than 3.5.1 in creating nodes: https://github.com/godotengine/godot/issues/71182
- Godot Issue #48978 — Instancing some objects takes more time in Godot 4 than 3.x: https://github.com/godotengine/godot/issues/48978
- Godot Issue #73936 — Custom objects slower to instantiate in Godot 4 GDScript: https://github.com/godotengine/godot/issues/73936
- Bugnet Blog — Signal cleanup / disconnect strategies: https://bugnet.io/blog/fix-godot-signal-disconnect-error
- Bugnet Blog — Duplicate signal connections in pooled nodes: https://bugnet.io/blog/fix-duplicate-signal-connections-multiple-calls-godot
- Godot Forum — `remove_child` keeps node in memory (re-parenting for pooling): https://forum.godotengine.org/t/what-is-difference-queue-free-and-remove-child-what-is-queue/22333
- Godot Forum — `reparent()` method (Godot 4.0+): https://forum.godotengine.org/t/is-it-possible-to-re-parent-a-node-without-removing-it-from-the-scene-tree/64875
- Godot Demo — Bullet Shower (server-side 500 bullets without nodes): https://github.com/godotengine/godot-demo-projects/blob/master/2d/bullet_shower/bullets.gd
- Toxigon — Mastering Object Pooling in Godot: https://toxigon.com/mastering-object-pooling-in-godot
- PathBits — Implementing Object Pooling in Godot 2D: https://app.pathbits.com/articles/implementing-object-pooling-in-godot-2d-for-performance-optimization

## Recommended Pattern

### When to Pool

Pool objects that are created and destroyed at high frequency (multiple times per second), short-lived, and share the same type. Typical candidates:

| Entity Type | Pool? | Pool Size Guidance |
|---|---|---|
| Bullets / projectiles | Yes | 500–2000 |
| Hit effects / particles | Yes | 500–5000 |
| Damage numbers / floating text | Yes | 50–200 |
| Enemies (common grunts) | Yes | 50–500 |
| Pickups / loot drops | Maybe | 10–50 |
| Bosses / unique entities | No | N/A |
| UI elements (panels, buttons) | No | N/A |
| Player character | No | N/A |

### Core Principle

Pre-allocate a fixed pool of nodes at game start (or level load). Instead of `instantiate()` + `queue_free()`, retrieve an inactive node from the pool (O(1) pop), reset and activate it, then later deactivate it and return it to the pool. This eliminates allocation overhead and GC/free spikes.

### Godot 4 Performance Context

Godot 4.x is measurably slower at node instantiation than Godot 3.x (reported 4x–60x slower for some node types in early 4.0, significantly improved by 4.4 but still behind 3.x). `add_child()` is one of the most expensive operations — pooling avoids it entirely at runtime. However, for low-frequency spawning (once every few seconds), the overhead of a pool may outweigh the benefit. **Always profile before implementing.**

### Keep-in-Tree vs Remove-from-Tree

There are two strategies for where pooled nodes live:

1. **Keep in tree (hidden + disabled):** Nodes remain children of the pool manager. Toggle `visible` and `set_process(false)`. Fastest retrieval — no tree mutation. Downside: nodes still incur scene tree traversal overhead and can receive stray signals.
2. **Remove from tree (re-parent to pool):** Use `remove_child()` / `reparent()` to move nodes between the pool container and the active world. Slower (tree mutation cost) but cleaner isolation — inactive nodes don't participate in physics, signals, or culling.

**Recommendation:** Use keep-in-tree for very high-frequency objects (bullets, particles). Use remove-from-tree for larger entities (enemies) where isolation matters more than micro-performance.

### Pool Architecture

Use a dedicated pool manager node (extending Node) for each entity type, or a single manager with a Dictionary of typed pools. Autoload singletons work well for cross-scene pools. Scene-scoped pools (children of the current World) work for level-specific entities.

## Implementation Patterns

### Pattern A: Simple Pool — Keep in Tree (Bullets/Projectiles)

Pre-allocate, toggle visibility/process, O(1) pop from array tail.

```gdscript
class_name BulletPool
extends Node

@export var scene: PackedScene
@export var pool_size: int = 100

var _available: Array[Node2D] = []

func _ready() -> void:
    for i in pool_size:
        var b = scene.instantiate()
        _deactivate(b)
        add_child(b)
        _available.append(b)

func spawn() -> Node2D:
    if _available.is_empty():
        _grow()
    var b = _available.pop_back()
    _activate(b)
    return b

def reclaim(b: Node2D) -> void:
    _deactivate(b)
    _available.append(b)

func _activate(b: Node2D) -> void:
    b.visible = true
    b.set_process(true)
    b.set_physics_process(true)

func _deactivate(b: Node2D) -> void:
    b.visible = false
    b.set_process(false)
    b.set_physics_process(false)

func _grow() -> void:
    var b = scene.instantiate()
    _deactivate(b)
    add_child(b)
    _available.append(b)
```

### Pattern B: Pool with Reset Interface (Enemies)

Require pooled objects to implement `spawn()` and `reset()` methods for lifecycle hooks.

```gdscript
class_name PooledEnemy
extends CharacterBody2D

var pool_manager: Node
var scene_path: String

func spawn(pos: Vector2, config: Dictionary) -> void:
    global_position = pos
    hit_points = config.get("hp", 50)
    damage = config.get("damage", 10)
    visible = true
    set_process(true)
    set_physics_process(true)

func reset() -> void:
    velocity = Vector2.ZERO
    hit_points = 0
    damage = 0
    visible = false
    set_process(false)
    set_physics_process(false)

func die() -> void:
    if pool_manager and scene_path:
        pool_manager.call_deferred("reclaim", self, scene_path)
    else:
        queue_free()
```

### Pattern C: Multi-Type Pool Manager (Dictionary of Pools)

Single manager handling multiple scene types via Dictionary lookup.

```gdscript
class_name PoolManager
extends Node

@export var scene_list: Array[PackedScene]
@export var pool_sizes: Dictionary  # scene.resource_path -> int

var _pools: Dictionary = {}     # resource_path -> Array[Node]
var _templates: Dictionary = {} # resource_path -> PackedScene

func _ready() -> void:
    for s in scene_list:
        var path = s.resource_path
        _templates[path] = s
        var size = pool_sizes.get(path, 10)
        _pools[path] = []
        for i in size:
            var obj = s.instantiate()
            if obj.has_method(&"set_pool_manager"):
                obj.set_pool_manager(self)
            _deactivate(obj)
            add_child(obj)
            _pools[path].append(obj)

func spawn(scene_path: String) -> Node:
    var pool = _pools.get(scene_path)
    if not pool or pool.is_empty():
        var t = _templates.get(scene_path)
        if not t:
            return null
        var obj = t.instantiate()
        if obj.has_method(&"set_pool_manager"):
            obj.set_pool_manager(self)
        add_child(obj)
        return obj
    var obj = pool.pop_back()
    _activate(obj)
    return obj

func reclaim(obj: Node, scene_path: String) -> void:
    _deactivate(obj)
    _pools[scene_path].append(obj)

func _activate(obj: Node) -> void:
    obj.visible = true
    obj.set_process(true)
    obj.set_physics_process(true)
    if obj.has_method(&"on_spawn"):
        obj.on_spawn()

func _deactivate(obj: Node) -> void:
    if obj.has_method(&"on_despawn"):
        obj.on_despawn()
    obj.visible = false
    obj.set_process(false)
    obj.set_physics_process(false)
```

### Pattern D: Signal-Based Return (Self-Returning Bullet)

Bullet emits `returned_to_pool` signal; pool manager listens and reclaims.

```gdscript
class_name PooledBullet
extends Area2D

signal returned_to_pool

var direction: Vector2
var speed: float = 400.0

func on_spawn(pos: Vector2, dir: Vector2) -> void:
    global_position = pos
    direction = dir.normalized()
    rotation = direction.angle()

func on_despawn() -> void:
    direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_visibility_notifier_screen_exited() -> void:
    returned_to_pool.emit()

func _on_body_entered(_body: Node) -> void:
    returned_to_pool.emit()
```

Pool manager connects to signal:

```gdscript
func _create_instance() -> Node:
    var obj = scene.instantiate()
    obj.returned_to_pool.connect(_on_returned.bind(obj))
    add_child(obj)
    _deactivate(obj)
    _available.append(obj)
    return obj

func _on_returned(obj: Node) -> void:
    reclaim(obj)
```

### Pattern E: Server-Side Pooling (Ultra High Performance)

For 10,000+ simple entities, bypass nodes entirely using `RenderingServer` + `PhysicsServer2D`. Each entity is a struct of RIDs (opaque handles) managed in arrays. Example from Godot's Bullet Shower demo:

```gdscript
class BulletData:
    var position: Vector2
    var speed: float
    var body: RID

var bullets: Array[BulletData] = []
var shape: RID

func _ready() -> void:
    shape = PhysicsServer2D.circle_shape_create()
    PhysicsServer2D.shape_set_data(shape, 8)
    for i in 500:
        var b = BulletData.new()
        b.speed = randf_range(20, 80)
        b.body = PhysicsServer2D.body_create()
        PhysicsServer2D.body_set_space(b.body, get_world_2d().get_space())
        PhysicsServer2D.body_add_shape(b.body, shape)
        bullets.append(b)

func _physics_process(delta: float) -> void:
    var t := Transform2D()
    for b in bullets:
        b.position.x -= b.speed * delta
        t.origin = b.position
        PhysicsServer2D.body_set_state(b.body, PhysicsServer2D.BODY_STATE_TRANSFORM, t)

func _draw() -> void:
    for b in bullets:
        draw_texture(bullet_tex, b.position - bullet_tex.get_size() * 0.5)
```

Trade-offs: No collision signals (manual detection), no per-entity scripts, no editor tooling. Requires manual cleanup (`free_rid` on exit).

## Code Snippet Examples

### Basic Pool Usage

```gdscript
# In any spawner script
@export var bullet_pool: PackedScene  # Assign PoolManager scene in editor

func fire(pos: Vector2, dir: Vector2) -> void:
    var bullet = bullet_pool.spawn()
    if bullet:
        bullet.on_spawn(pos, dir)
```

### Returning Pooled Object via Deferred Call (Safety)

```gdscript
func die() -> void:
    # Use call_deferred to avoid modifying the tree mid-frame
    pool_manager.call_deferred("reclaim", self, scene_path)
```

### Signal Guard Pattern for Pooled Nodes

Prevent duplicate connections when a node re-enters the tree:

```gdscript
func on_spawn() -> void:
    if not GameEvents.enemy_died.is_connected(_on_enemy_died):
        GameEvents.enemy_died.connect(_on_enemy_died)

func on_despawn() -> void:
    if GameEvents.enemy_died.is_connected(_on_enemy_died):
        GameEvents.enemy_died.disconnect(_on_enemy_died)
```

### Safe Growth with Max Capacity

```gdscript
@export var max_pool_size: int = 500

func _grow() -> void:
    if _available.size() + _in_use.size() >= max_pool_size:
        push_warning("Pool at max capacity, reusing oldest active object")
        var oldest = _in_use.pop_front()
        _deactivate(oldest)
        _available.append(oldest)
        return
    var obj = scene.instantiate()
    _deactivate(obj)
    add_child(obj)
    _available.append(obj)
```

## Signal Cleanup When Reusing Nodes

### The Problem

When a node is returned to the pool (hidden/disabled) and later respawned, `_ready()` is **not** called again unless the node exits and re-enters the scene tree. Signals connected in `_ready()` persist silently. If the node connects to autoload signals (EventBus), each spawn creates a duplicate connection — the callback fires N times per event, causing hard-to-debug bugs.

### Solutions

1. **Connect in `on_spawn()` / disconnect in `on_despawn()`** — Most explicit. Pair every connect with a corresponding disconnect. Use `is_connected()` as a guard.

2. **`CONNECT_ONE_SHOT` flag** — Signal auto-disconnects after first fire. Useful for one-time events (animation callbacks, delayed triggers). Not suitable for persistent listeners.

3. **`_exit_tree()` cleanup** — If the node leaves the tree when returned to pool, disconnect in `_exit_tree()`. This is the safest pattern for remove-from-tree strategies.

4. **`is_connected()` guard** — Before connecting, check with `is_connected()`. Prevents duplicates but leaves stale connections to freed objects.

### Recommendations by Scenario

| Scenario | Strategy |
|---|---|
| Bullet → world boundary signal | Connect in `on_spawn()`, disconnect in `on_despawn()` |
| Enemy → EventBus (autoload) | Disconnect in `on_despawn()` (mandatory — autoload outlives the node) |
| Keep-in-tree pool | Manual disconnect in `on_despawn()` |
| Remove-from-tree pool | Disconnect in `_exit_tree()` |
| One-shot listener | `CONNECT_ONE_SHOT` |
| Signal to a node that is freed alongside caller | No cleanup needed — auto-disconnected by Godot |

## Resetting State When Returning to Pool

### Required Reset Categories

1. **Transform:** `position = Vector2.ZERO`, `rotation = 0`, `scale = Vector2.ONE`
2. **Physics:** `velocity = Vector2.ZERO`, `linear_velocity = Vector2.ZERO`
3. **Combat stats:** `hit_points = max_hp`, `damage = base_damage`
4. **Visual:** `modulate = Color.WHITE`, `visible = false`, `material = null`
5. **Timers / cooldowns:** Stop all timers, reset elapsed time
6. **Collision:** Disable collision monitoring if used for one-shot detection
7. **Script state:** Set all dynamic variables to initial values

### Reset Pattern

```gdscript
# Called by pool manager when object is returned
func on_despawn() -> void:
    global_position = Vector2.ZERO
    velocity = Vector2.ZERO
    hit_points = 0
    visible = false
    set_process(false)
    set_physics_process(false)
    if health_changed.is_connected(_on_health_changed):
        health_changed.disconnect(_on_health_changed)
```

### Pitfall: `_ready()` Is Not Called on Reuse

`_ready()` fires once when the node first enters the scene tree. On subsequent spawns from the pool, `_ready()` does **not** fire again. Use explicit `spawn()` / `on_spawn()` methods instead of relying on `_ready()` for initialization. Store the scene path or pool reference that `_ready()` normally sets up via a `set_pool_manager()` call during pool initialization.

## Dynamic / Auto-Expanding Pools

### Growth Strategy

When the pool is exhausted:
1. **Expand by a fixed increment** (e.g., +10) or **multiply by 1.5x** — smooths out future demand.
2. **Reuse the oldest active object** — preempts the oldest (least valuable) entity. Good for limited-memory scenarios.
3. **Return null / fall back to instantiate** — simplest, but means the pool can still cause allocation spikes during growth.

### Max Capacity

Define a hard ceiling per pool. When reached, either:
- Reuse oldest (circular buffer approach)
- Drop new spawn requests (spawn returns null)
- Log a warning for debugging

### Pre-warming Over Multiple Frames

For pools with large initial sizes (1000+), spread instantiation across frames to avoid startup stutter:

```gdscript
func _ready() -> void:
    _warm_async(25)  # Spawn 25 per frame

func _warm_async(batch_size: int) -> void:
    var spawned = 0
    while spawned < pool_size:
        for i in min(batch_size, pool_size - spawned):
            _create_instance()
            spawned += 1
        await get_tree().process_frame
```

## Pool Per Entity Type vs Single Shared Pool

| Approach | Pros | Cons |
|---|---|---|
| **Pool per type** | Type-safe retrieval, no type-checking overhead, independent sizing per type | More manager nodes, more boilerplate if many types |
| **Single Dictionary pool** | Single manager, less code, unified lifecycle hook | Dictionary key lookup cost, risk of returning node to wrong sub-pool, harder to debug |
| **Mixed** | Dedicated managers for high-frequency types (bullets), shared for low-frequency (pickups) | Most complex to set up |

**Recommendation:** Start with a single `PoolManager` autoload that holds a `Dictionary[String, Array[Node]]` keyed by scene resource path. If profiling shows the Dictionary lookup is measurable (typically negligible for <20 types), split into dedicated pool nodes.

## Limitations

| Aspect | Limitation |
|---|---|
| **Memory** | Pooled nodes stay in memory even when unused. Pre-allocation of 500 enemies at 10KB each = 5MB baseline. Monitor with `Performance.get_monitor(PERFORMANCE.OBJECT_COUNT)`. |
| **Stale state** | `_ready()` does not fire on reuse. All state must be reset manually. Missed reset fields are a common source of bugs. |
| **Duplicate signals** | Nodes re-entering the tree or being reactivated can double-connect signals if disconnect logic is missing. Especially problematic with autoload EventBus connections. |
| **Scene tree overhead** | Even disabled/invisible nodes in the tree incur traversal cost. For 10,000+ pooled nodes, this becomes measurable — consider server-side pooling instead. |
| **Complexity** | Adds lifecycle methods (`on_spawn`, `on_despawn`, `reset`), pool manager registration, and signal cleanup. Not free in code complexity. |
| **`add_child` cost** | If using remove-from-tree strategy, the `add_child` / `remove_child` calls that pooling was meant to avoid are still paid on every spawn/reclaim. Only the `instantiate` / `free` cost is saved. |
| **Pool exhaustion** | If pool is too small and auto-growth is disabled, spawn returns null. Silent failure is easy to miss in testing. |
| **Thread safety** | Pool operations (pop, append) modify arrays. If called from threads, must use mutexes or `call_deferred`. |
| **Godot GC** | GDScript reference counting is efficient, but node creation (C++ side) still has allocation cost. Pooling avoids C++ node allocation, which is the primary bottleneck. |
| **No built-in pool node** | As of Godot 4.6, there is no built-in ObjectPool2D/3D node. Must implement custom pooling. |

## Alternatives

| Alternative | When to Use | Trade-offs |
|---|---|---|
| **`instantiate()` / `queue_free()` (no pool)** | <50 objects per minute, unique entities, bosses, UI | Simplest code. Acceptable for low-frequency spawning. Avoid for bullets, particles, grunt enemies. |
| **Server-side (RenderingServer + PhysicsServer2D)** | 10,000+ homogeneous entities (bullet hell, particle fields) | Maximum performance. No Node overhead, no signals, no editor tooling. Manual collision detection. Complex to develop. |
| **`MultiMeshInstance2D`** | Thousands of identical sprites (debris, grass, army units at distance) | GPU-instanced rendering. No per-entity logic or physics. Best for visuals-only entities. |
| **`GPUParticles2D` / `CPUParticles2D`** | Visual effects (explosions, trails, ambient particles) | Built-in particle system. Handles large counts efficiently. Limited to particle behavior, not game-logic entities. |
| **ECS (Entity Component System)** addons | Large-scale games with heterogeneous entities and mix-and-match components | Most flexible but adds abstraction overhead. GDScript ECS addons exist (gecs, assertiv/godot-ecs) but are not mature. |
| **Threaded instantiation** (`WorkerThreadPool`) | Pre-warming pools during loading screens | Offloads instantiation cost to background. Cannot `add_child` from worker thread — must `call_deferred`. Useful for async pool warmup. |
| **Lazy instantiation (grow on demand)** | Unknown peak demand, memory-constrained targets | Start small, grow as needed. Avoids pre-allocation memory cost but still pays instantiation tax during gameplay for the first few spawns past the initial size. |
| **Circular buffer reuse** | Fixed memory budget, can tolerate dropping oldest entities | Pre-allocate max capacity. Overwrite oldest active entity when pool is full. Predictable memory footprint. Suitable for bullet-hell with hard caps. |
