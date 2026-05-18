# Wave Management / Spawning System — Godot 4 Research

## References

- **GDQuest** — Tower Defense course: `WaveResource` + `WaveSpawner` composition pattern, signal-based `wave_finished` chaining
- **GDQuest forum** — Community solution: `MobSpawner` as child nodes with `wave_size`, `spawn_delay`, `mob_scene` per wave
- **GamineAI** — "Spawn Director" pattern: wave intensity curves, threat budgets, layered cooldowns, weighted selection with soft constraints
- **dthendivergentai/gd-agentic-skills** — `game-loop-waves` skill: Manager/Spawner/Resource triad, composition-based spawning, async wave triggers
- **dthendivergentai/gd-agentic-skills** — `godot-genre-tower-defense` skill: WaveManager with `groups` sub-array, wave-cleared signal, `spawn_interval` per group
- **Godot Object Pooling** — Pre-allocate arrays at game start, `visible` + `set_process` toggle instead of `instantiate`/`queue_free`
- **Godot Docs** — GDScript reference counting (no GC pauses), Resources as ScriptableObject-like data containers
- **GDQuest forum** — `WaveResource` extending `Resource`, `@export var compositions: Dictionary` with `PackedScene → count` mapping
- **ArtinTheCoder/Spawner-Godot-Plugin** — Plugin with WaveManager + SpawnerContainer + MultipleSpawner nodes, signal-driven lifecycle
- **quiver-dev/tower-defense-godot4** — Open-source Outpost Assault template (85★), navigation-based enemy movement, wave system
- **ape1121/Godot-4-Tower-Defense-Template** — Open-source template (60★), data-driven config in autoload, path-follow spawning

## Recommended Pattern

**Manager/Spawner/Resource triad** with signal-based lifecycle:

| Component | Role | Responsibility |
|-----------|------|----------------|
| `WaveResource` | Data container | Enemy compositions, spawn timing, per-wave values |
| `WaveManager` | Orchestrator | Wave sequencing, state machine, active-enemy tracking |
| `Spawner` | Spatial executor | Position logic, path binding, enemy instantiation |

State machine: `countdown → spawning → active (combat) → cooldown → countdown...`

---

## Implementation Patterns

### 1. WaveResource (Data Definition)

Define a custom Resource with class_name for inspector-editable wave definitions:

- `groups: Array[SpawnGroup]` or `compositions: Dictionary[PackedScene → int]`
- `pre_delay`: seconds before wave starts (for countdown UI)
- `post_delay`: seconds after wave cleared before next countdown
- Extension: `difficulty_multiplier` for endless scaling

Resources save as `.tres` (text, version-control friendly) — one per wave.

### 2. Spawn Grouping

Waves composed of multiple spawn groups (sub-waves) with independent timing:

- Each group has: `enemy_scene`, `count`, `spawn_interval` (time between enemies in group), `group_delay` (time before this group starts)
- Allows staggered spawns (e.g., flankers delayed 3s after main group)
- Groups within one wave can overlap

### 3. Active Enemy Tracking

**Never** poll `get_tree().get_nodes_in_group("enemies").size()`. Use a counter:

- Increment on `enemy_spawned`
- Decrement on enemy `tree_exiting`
- On reaching zero → emit `wave_cleared`
- Track per-wave total separately from per-group count for staggered completion detection

### 4. Async Wave Lifecycle

Use `await` + timers instead of `_process` polling:

```
func _run_wave(wave: WaveResource) -> void:
    await get_tree().create_timer(wave.pre_delay).timeout
    wave_started.emit(current_wave_index)
    for group in wave.groups:
        await get_tree().create_timer(group.group_delay).timeout
        for i in group.count:
            _spawn_enemy(group.enemy_scene)
            await get_tree().create_timer(group.spawn_interval).timeout
    # Spawning done; wait for combat resolution
    await wave_cleared
    await get_tree().create_timer(wave.post_delay).timeout
```

### 5. Difficulty Scaling

**Endless mode**: Code-generate WaveResource with formulas:

- Enemy HP = `base_hp * (1 + wave_index * hp_scale)`
- Enemy count = `base_count + floor(wave_index * count_scale)`
- Spawn interval = `max(min_interval, base_interval - wave_index * speed_scale)`
- New enemy types unlock at threshold waves

**Budget-based** (advanced): Assign threat cost per enemy type. Wave max budget = `base_budget * wave_curve.sample(progress_ratio)`. Fill with weighted random composition.

### 6. Spawn Strategies

| Strategy | Implementation | Use Case |
|----------|---------------|----------|
| Random edge | Pick random `Marker2D` child from spawn holder | Survival, horde modes |
| Formation | Compute offsets from path start position | Staggered, grouped intros |
| Directed | Specific spawn points per group | Story missions, boss waves |
| Staggered | Multiple groups with delays | Mixed-unit waves |
| Clustered | All enemies of one group at same point, then next group | "Wedge" formations |

### 7. Object Pooling

Pre-allocate enemies at scene load (or wave start) — hide/disable when not in use:

- Pool per enemy type (`Dictionary[PackedScene, Array[Node]]`)
- On spawn: find first inactive node in pool → reposition → enable → show
- On death: disable → hide → return to pool (instead of `queue_free`)
- Grow pool by 1.5× if exhausted
- **Godot-specific**: GDScript uses reference counting (no GC pauses), so pooling is less critical than in C#/Unity but still beneficial at >50 simultaneous enemies
- **Extra safety**: Use `set_deferred("monitoring", false)` before repositioning to avoid one-frame collision glitches

### 8. Handling Large Enemy Counts

- Pool enemies (see above)
- Disable `monitoring`/`monitorable` on sleeping enemies
- Use `VisibleOnScreenNotifier2D` to disable processing when off-screen
- Set `collision_layer = 0` during spawn animation to prevent spawn-point blocking
- For extreme counts (500+): use `PhysicsServer2D` direct queries instead of Area2D detection
- Consider `MultiMeshInstance2D` for identical visual-only enemies with shared logic

---

## Code Snippet Examples

### WaveResource

```gdscript
class_name WaveResource
extends Resource

@export var pre_delay: float = 3.0
@export var post_delay: float = 5.0
@export var groups: Array[SpawnGroupResource] = []
```

### SpawnGroupResource

```gdscript
class_name SpawnGroupResource
extends Resource

@export var enemy_scene: PackedScene
@export var count: int = 5
@export var spawn_interval: float = 0.8
@export var group_delay: float = 0.0
@export var spawn_point_id: String = ""
```

### WaveManager (core)

```gdscript
class_name WaveManager
extends Node

signal wave_started(index: int)
signal wave_cleared
signal all_waves_complete

@export var waves: Array[WaveResource] = []
@export var spawn_points: Node

var current_wave_index: int = -1
var active_enemies: int = 0
var _busy: bool = false

func start_next_wave() -> void:
    if _busy:
        return
    current_wave_index += 1
    if current_wave_index >= waves.size():
        all_waves_complete.emit()
        return
    _busy = true
    await _run_wave(waves[current_wave_index])
    _busy = false

func _run_wave(wave: WaveResource) -> void:
    wave_started.emit(current_wave_index)
    await get_tree().create_timer(wave.pre_delay).timeout
    for group in wave.groups:
        await get_tree().create_timer(group.group_delay).timeout
        for i in group.count:
            _spawn_enemy(group, i)
            await get_tree().create_timer(group.spawn_interval).timeout
    await _wait_for_clear()
    wave_cleared.emit()
    await get_tree().create_timer(wave.post_delay).timeout

func _spawn_enemy(group: SpawnGroupResource, index: int) -> void:
    var enemy: Node2D = _get_from_pool(group.enemy_scene)
    if not enemy:
        enemy = group.enemy_scene.instantiate()
        add_child(enemy)
    var spawn_pos: Marker2D = _pick_spawn_point(group.spawn_point_id, index)
    enemy.global_position = spawn_pos.global_position
    enemy.tree_exiting.connect(_on_enemy_exited.bind(enemy), CONNECT_ONE_SHOT)
    active_enemies += 1
    _activate(enemy)

func _on_enemy_exited(_enemy: Node2D) -> void:
    active_enemies -= 1

func _wait_for_clear() -> Signal:
    if active_enemies <= 0:
        return Signal()
    return wave_cleared
```

### ObjectPool

```gdscript
class_name ObjectPool
extends Node

var _pools: Dictionary = {}

func warm(scene: PackedScene, count: int) -> void:
    var pool: Array[Node] = []
    for i in count:
        var obj: Node = scene.instantiate()
        obj.visible = false
        obj.set_process(false)
        obj.set_physics_process(false)
        add_child(obj)
        pool.append(obj)
    _pools[scene] = pool

func get_from_pool(scene: PackedScene) -> Node:
    if not _pools.has(scene) or _pools[scene].is_empty():
        var obj: Node = scene.instantiate()
        add_child(obj)
        return obj
    var obj: Node = _pools[scene].pop_back()
    return obj

func return_to_pool(scene: PackedScene, obj: Node) -> void:
    obj.visible = false
    obj.set_process(false)
    obj.set_physics_process(false)
    if not _pools.has(scene):
        _pools[scene] = []
    _pools[scene].append(obj)
```

### Wave Composition (Dictionary variant)

```gdscript
class_name WaveResource
extends Resource

@export var pre_delay: float = 3.0
@export var post_delay: float = 5.0
@export var compositions: Dictionary = {
    # Key: path to PackedScene, Value: count to spawn
}
```

### Difficulty Curve (endless)

```gdscript
static func generate_wave(index: int) -> WaveResource:
    var wave := WaveResource.new()
    var hp_mult: float = 1.0 + index * 0.15
    var count_base: int = 3 + index * 2
    var interval: float = max(0.4, 1.2 - index * 0.05)
    var group := SpawnGroupResource.new()
    group.enemy_scene = preload("res://enemies/grunt.tscn")
    group.count = count_base
    group.spawn_interval = interval
    # Apply hp_mult to enemies on spawn via signal
    wave.groups = [group]
    return wave
```

---

## Limitations

| Pattern | Limitation |
|---------|------------|
| Resource-based waves | .tres files must be manually created; tedious for 50+ waves. Use code-generation for endless mode |
| `await`-driven spawning | Cannot cleanly interrupt mid-wave (e.g., fast-forward). Wrap in a cancel-check pattern or use explicit Timer nodes |
| Per-enemy `tree_exiting` signal | One-shot connection per enemy. If enemy is freed without `tree_exiting` (e.g., `queue_free` not called), counter leaks. Add defensive timeout or periodic health-check |
| Dictionary composition | `PackedScene` as dictionary key works but cannot be serialized to .tres. Use `String` (scene path) as key instead |
| Object pooling all types | Pool per scene; each enemy variant needs its own pool. Pre-warming 10 types × 20 each = 200 nodes at scene load |
| Threat budget system | Requires careful tuning of per-enemy costs. Over-constrained budgets can produce boring waves |

---

## Alternatives

| Alternative | Trade-off |
|-------------|-----------|
| **SpawnDirector** (GamineAI pattern) | Curve-driven continuous spawning instead of discrete waves. Better for survival/roguelite, worse for structured TD levels |
| **Plugin-based** (ArtinTheCoder Spawner) | Drag-and-drop setup in editor, less code. Less control over composition and scaling logic |
| **Timer node per spawn** | Explicit Timer nodes instead of `await create_timer()`. More scene tree overhead, but allows pause/resume per timer without managing coroutine state |
| **Single autoload manager** | All wave logic in one global autoload. Simpler for small games; couples spawning to game state, harder to swap per-level |
| **JSON/CSV wave data** | Flat file instead of .tres. Better for large wave tables (>50), tooling-friendly, but no inspector editing or type safety |
| **No pooling (direct instantiation)** | Simpler code, acceptable for <30 simultaneous enemies. Risk of frame spikes during `instantiate` on intense waves |
