# Entity Management / Scene Tree Organization in Godot 4

## References

- Godot Docs — Scene Organization: https://docs.godotengine.org/en/4.6/tutorials/best_practices/scene_organization.html
- Godot Docs — Groups: https://docs.godotengine.org/en/4.6/tutorials/scripting/groups.html
- Godot Docs — SceneTree (get_nodes_in_group, get_node_count_in_group): https://docs.godotengine.org/en/4.6/classes/class_scenetree.html
- Godot Docs — Autoloads vs Regular Nodes: https://docs.godotengine.org/en/4.6/tutorials/best_practices/autoloads_versus_internal_nodes.html
- Godot Docs — Node communication ("call down, signal up"): https://kidscancode.org/godot_recipes/4.x/basics/node_communication/
- Godot Docs — Data Preferences (Array/Dictionary performance): https://docs.godotengine.org/en/4.0/tutorials/best_practices/data_preferences.html
- Godot Docs — Instancing with Signals: https://docs.godotengine.org/en/4.0/tutorials/scripting/instancing_with_signals.html
- Godot Docs — Object ID / instance_id(): https://docs.godotengine.org/en/4.2/classes/class_encodedobjectasid.html
- Shaggy Dev — Tactics Engine Architecture (Level -> Units -> Groups -> Units): https://shaggydev.com/2023/07/04/tactics-engine-devlog/
- Shaggy Dev — Strategy Game Architecture (Scene tree partitioning): https://shaggydev.com/2024/09/04/unto-deepest-depths-devlog/
- Ryan Stefan — Data-Oriented Design in Godot (arrays vs nodes at scale): https://dashwood.net/blog/2025-06-04-from-spaghetti-to-speed-how-we-refactored-an-rts-game-to-data-oriented-design-in
- Godot RTS Entity Controller addon (component-based): https://github.com/philipbeaucamp/godot-rts-entity-controller
- Godot Proposal #7080 — get_node_count_in_group to avoid array allocation: https://github.com/godotengine/godot-proposals/issues/7080
- Godot PR #75627 — Node children management optimization (hashmap children): https://github.com/godotengine/godot/pull/75627
- Godot PR #57541 — child_entered_tree / child_exiting_tree signals: https://github.com/godotengine/godot/pull/57541
- Godot Issue #78295 — Editor performance with many scripted nodes: https://github.com/godotengine/godot/issues/78295
- 16BitDev — RTS Unit Group System: https://www.youtube.com/watch?v=eQjBLFKamms
- Gameidea — RTS in Godot / Team/alliance via groups: https://gameidea.org/2024/12/13/how-to-make-an-rts-game-in-godot/
- Nicola Dau — Event Bus pattern in Godot: https://nicoladau.com/2024/05/25/sending-signals-across-your-godot-4-project-with-game-events/
- GECS — Godot Entity Component System: https://csprance.com/blog/gecs-entities
- Godot Object Pooling pattern: https://github.com/thedivergentai/gd-agentic-skills/blob/main/skills/godot-performance-optimization/scripts/object_pool_system.gd
- Godot Performance Optimization — Object Pooling, Scene Management: https://skills.sh/thedivergentai/gd-agentic-skills/godot-performance-optimization

## Recommended Pattern

### Scene Tree Layout

```
Main (Node)                          # Entry point, persists across scene changes
├── GameManager (Node)               # Autoload or child — game state, gold, waves
├── EventBus (Node)                  # Autoload — global signal bus
├── World (Node2D)                   # Current game world, swapped on level change
│   ├── Environment (TileMap/Nav)    # Static geometry, navigation, decorations
│   ├── Actors (Node2D)             # Container for all dynamic entities
│   │   ├── Units (Node2D)          # Player-controlled military units
│   │   ├── Enemies (Node2D)        # Enemy wave entities
│   │   ├── Buildings (Node2D)      # Player buildings / structures
│   │   └── Projectiles (Node2D)    # Active projectiles / effects
│   └── Spawners (Node2D)           # Wave spawn points, timers
└── UI (CanvasLayer)                 # HUD, action bar, menus (pixel coordinates)
```

### Key Principles

1. **Parent-child for lifecycle, groups for queries.** Use the scene tree hierarchy for ownership (freeing a parent frees its children). Use groups (`add_to_group("enemies")`) for runtime entity discovery and iteration.

2. **Autoloads for global state, scene children for per-level state.** Put persistent singletons (EventBus, GameManager) in Autoload. Put level-specific entity containers inside World so they free naturally on scene change.

3. **"Call down, signal up."** Parents call methods on their children directly. Children emit signals to communicate upward or sideways. Use the EventBus autoload for decoupled cross-system communication.

4. **Combined tracking: groups + Dictionary cache.** Use groups for quick iteration (especially `call_group` / `set_group`). Maintain a Dictionary in a manager autoload keyed by entity ID for O(1) lookups of specific entities.

5. **Use `get_node_count_in_group()` for counts.** Avoid calling `get_nodes_in_group().size()` which allocates a temporary array. Since Godot 4.3+, `get_node_count_in_group()` is available.

## Implementation Patterns

### Pattern A: Groups for Entity Discovery

Add entities to groups in `_ready()`:

```gdscript
func _ready():
    add_to_group("units")
    add_to_group("military")
    add_to_group("selectable")
```

Broadcast to all entities in a group:

```gdscript
get_tree().call_group("enemies", "take_damage", 10)
get_tree().set_group("units", "modulate", Color.RED)
```

Iterate group members:

```gdscript
for enemy in get_tree().get_nodes_in_group("enemies"):
    if global_position.distance_to(enemy.global_position) < detection_radius:
        target = enemy
        break
```

Get count without allocation:

```gdscript
var count = get_tree().get_node_count_in_group("projectiles")
```

### Pattern B: Autoload Registry (Dictionary Cache)

Maintain a registry in an autoload for O(1) entity lookup:

```gdscript
# entity_registry.gd (Autoload)
extends Node

var _entities: Dictionary = {}  # entity_id -> Node

func register(entity: Node) -> void:
    _entities[entity.entity_id] = entity

func unregister(entity_id: int) -> void:
    _entities.erase(entity_id)

func get_entity(entity_id: int) -> Node:
    return _entities.get(entity_id)

func get_all_in_group(group: String) -> Array:
    return get_tree().get_nodes_in_group(group)
```

### Pattern C: Entity ID System

Use Godot's built-in `get_instance_id()` as a unique ID:

```gdscript
# In a base entity script
class_name GameEntity
extends Node2D

var entity_id: int

func _ready() -> void:
    entity_id = get_instance_id()
    EntityRegistry.register(self)

func _exit_tree() -> void:
    if EntityRegistry:
        EntityRegistry.unregister(entity_id)
```

For serialization or multiplayer stability without Godot 4.4+ internal node IDs, use a custom counter or server-assigned ID:

```gdscript
# Autoload: IDManager
extends Node

var _next_id: int = 1

func generate_id() -> int:
    var id = _next_id
    _next_id += 1
    return id
```

### Pattern D: Signal Bus for Lifecycle Events

```gdscript
# event_bus.gd (Autoload)
extends Node

signal entity_spawned(entity: Node)
signal entity_died(entity: Node)
signal entity_hp_changed(entity: Node, old_hp: int, new_hp: int)
```

Usage in entity script:

```gdscript
func _ready() -> void:
    EventBus.entity_spawned.emit(self)

func die() -> void:
    EventBus.entity_died.emit(self)
    queue_free()
```

### Pattern E: Object Pooling

Pre-allocate and reuse frequently spawned entities (projectiles, particles):

```gdscript
# projectile_pool.gd
class_name ProjectilePool
extends Node

@export var scene: PackedScene
@export var pool_size: int = 50

var _pool: Array[Node] = []

func _ready() -> void:
    for i in pool_size:
        var instance = scene.instantiate()
        instance.visible = false
        instance.set_process(false)
        instance.set_physics_process(false)
        add_child(instance)
        _pool.append(instance)

func get_projectile() -> Node:
    for p in _pool:
        if not p.visible:
            p.visible = true
            p.set_process(true)
            p.set_physics_process(true)
            return p
    var instance = scene.instantiate()
    add_child(instance)
    return instance

func return_projectile(p: Node) -> void:
    p.visible = false
    p.set_process(false)
    p.set_physics_process(false)
```

### Pattern F: Container Node + Manual Tracking

For sub-100 entity counts, direct children iteration is simplest:

```gdscript
# In World.gd or Actors.gd
@onready var units: Node2D = %Units
@onready var enemies: Node2D = %Enemies

func get_all_enemies() -> Array:
    return enemies.get_children()

func count_units() -> int:
    return units.get_child_count()
```

When entities are added/removed frequently, connect `child_entered_tree` / `child_exiting_tree` (Godot 4.0+):

```gdscript
func _ready() -> void:
    enemies.child_entered_tree.connect(_on_enemy_spawned)
    enemies.child_exiting_tree.connect(_on_enemy_died)

func _on_enemy_spawned(node: Node) -> void:
    EventBus.entity_spawned.emit(node)

func _on_enemy_died(node: Node) -> void:
    EventBus.entity_died.emit(node)
```

## Code Snippet Examples

### Entity Base Class

```gdscript
class_name GameEntity
extends Node2D

@export var stats: Resource  # UnitStats or similar

var entity_id: int
var hit_points: int

func _ready() -> void:
    entity_id = get_instance_id()
    hit_points = stats.max_hp
    add_to_group("entities")
    EntityRegistry.register(self)
    EventBus.entity_spawned.emit(self)

func take_damage(amount: int) -> void:
    var old_hp = hit_points
    hit_points = max(0, hit_points - amount)
    EventBus.entity_hp_changed.emit(self, old_hp, hit_points)
    if hit_points <= 0:
        die()

func die() -> void:
    EntityRegistry.unregister(entity_id)
    EventBus.entity_died.emit(self)
    queue_free()
```

### Spawning an Entity at Runtime

```gdscript
const UNIT_SCENES := {
    "foot_soldier": preload("res://scenes/units/foot_soldier.tscn"),
    "archer": preload("res://scenes/units/archer.tscn"),
}

func spawn_unit(type: String, position: Vector2) -> void:
    var scene = UNIT_SCENES.get(type)
    if not scene:
        return
    var unit = scene.instantiate()
    unit.global_position = position
    %Units.add_child(unit)
```

### Movement Queue System (for 100+ entities)

Adapted from Data-Oriented Design approach:

```gdscript
# unit_manager.gd (Autoload)
extends Node

var positions: PackedVector2Array
var velocities: PackedVector2Array
var targets: Array[Vector2]
var active: Array[bool]
var unit_count: int = 0

func register_unit(unit: Node2D) -> void:
    var idx = unit_count
    unit_count += 1
    positions.resize(unit_count)
    velocities.resize(unit_count)
    targets.resize(unit_count)
    active.resize(unit_count)
    positions[idx] = unit.global_position
    active[idx] = true
    unit.set_meta("entity_index", idx)

func unregister_unit(idx: int) -> void:
    active[idx] = false

func _physics_process(delta: float) -> void:
    for i in unit_count:
        if not active[i]:
            continue
        var direction = (targets[i] - positions[i]).normalized()
        velocities[i] = direction * 4.0
        positions[i] += velocities[i] * delta
```

## Limitations

| Approach | Limitation |
|---|---|
| **Groups** | `get_nodes_in_group()` allocates a new Array each call. Use `get_node_count_in_group()` if only the count is needed. Editor-assigned groups do not propagate to `instantiate()` children — must call `add_to_group()` in `_ready()`. |
| **Parent-child hierarchy** | `get_child()` and `get_child_count()` have thread-guard overhead (~16x slower than cached access per Godot PR #106224). Iteration across 1000+ children can be slow. |
| **Dictionary registry** | Must manually register/unregister in `_ready()` / `_exit_tree()`. If a node is freed without unregistering, the Dictionary holds a stale reference. Check with `is_instance_valid()`. |
| **Data-Oriented arrays** | Loses Godot's built-in scene features (signals, per-node scripts, editor integration). Best reserved for high-count homogeneous entities (1000+ bullets). |
| **Object pooling** | Fixed pool size may exhaust; must handle growth. Pooled nodes remain in the scene tree; invisible/disabled nodes still incur minimal overhead. |
| **Event Bus (autoload signals)** | Global signals make data flow harder to trace. Overuse leads to "spaghetti signals." Debugging requires searching all `connect()` calls. |
| **Per-frame `_process` on many nodes** | Even with empty `_process()`, Godot incurs virtual method call overhead. Disable processing on pooled/inactive entities with `set_process(false)`. |

## Alternatives

| Alternative | When to Use |
|---|---|
| **ECS (Entity Component System)** via addons like `gecs` or `assertiv/godot-ecs` | Large-scale games with thousands of heterogeneous entities where mix-and-match behavior is essential. Adds abstraction overhead. |
| **Servers (RenderingServer, PhysicsServer)** | For 10,000+ simple entities (particles, debris) where full Node overhead is wasteful. Direct server API calls bypass Node entirely. |
| **MultiMeshInstance2D/3D** | For rendering hundreds of identical sprites/meshes (e.g., grass, army units at low zoom). GPU-instanced, extremely performant. |
| **Pure Resource-based entities (no Node)** | For data-only entities (inventory items, stats) that never need a position in the scene tree. Extend `Resource`, use in arrays. |
| **Scene change with separate World scenes** | For distinct levels / game modes. Each World is a self-contained scene with its own entity hierarchy. Swap via `change_scene_to_file()`. The Autoload singletons persist across swaps. |
| **child_entered_tree / child_exiting_tree signals** | Alternative to groups for tracking dynamic children of a container node. Added in Godot 4.0. Lets a manager node observe adds/removes without manual registration. |
| **`@onready` + `%UniqueName` for editor-friendly references** | Alternative to string-based `get_node()` and fragile `$` paths. Designate unique names in the editor; use `%Units`, `%Enemies` for type-safe, refactor-safe references. |
| **Manual iteration via `SceneTreeFTI` (Godot 4.5+)** | Future API for fast cached children access. Once available in stable, use `get_cached_children()` for high-frequency iteration over large sibling groups. |
