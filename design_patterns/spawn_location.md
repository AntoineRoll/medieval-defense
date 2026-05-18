# Spawn Point / Spawn Location System — Godot 4 Research

## References

- **UhiyamaLab** — `Marker2D` as management node: group-based spawn point collection, `@export`-extended Marker2D scripts for per-point configuration, editor-visual placement
- **Godot Docs — PathFollow2D** — `progress`/`progress_ratio` sampling for path-based movement, `loop`/`rotate` properties
- **Godot Docs — Spawning Mobs (3D)** — `PathFollow3D.progress_ratio = randf()` for randomized edge spawning using a closed Path2D around viewport
- **GamineAI / thedivergentai — godot-genre-tower-defense** — Fixed Path (Kingdom Rush style) vs Mazing (Fieldrunners style) trade-offs, `PathFollow2D` as enemy parent for deterministic path traversal
- **thedivergentai — godot-game-loop-waves** — Composition-based spawning, `WaveResource` with spawn location bindings, `spawn_point_id` per spawn group
- **ArtinTheCoder/Spawner-Godot-Plugin** — Plugin with `SpawnerContainer`, `SpawnArea` (CollisionShape-based), random location sampling within rectangle
- **SharpCoderBlog** — Hardcoded `spawn_points: Array[Vector2]` with `randi() % spawn_points.size()` random selection
- **Wayline.io** — `Path2D` + `PathFollow2D` pattern: enemies move along predefined curve, add position offset to prevent bunching
- **Godot Forum — Random Edge Spawning** — `randf()` × `PathFollow2D.progress_ratio` for random positions along a closed perimeter path
- **quiver-dev/tower-defense-godot4** — Open-source Outpost Assault template: `NavigationAgent2D`-based enemies with spawner nodes, path-follow from spawn to base
- **VillerotJustin/spawner-plugin** — 2D/3D spawner plugin with `wave_entry.gd` resources for per-entry spawn configuration

## Recommended Pattern

**Editor-placed Marker2D spawn points** collected via groups, with an extended `SpawnPointResource` data structure for per-wave spawn entry definitions:

| Layer | Component | Role |
|-------|-----------|------|
| Visual | `Marker2D` nodes (children of `SpawnPoints` node) | Editor-visible green cross, draggable positions, grouped as `spawn_points` |
| Config | `SpawnPointResource` (extends `Resource`) | Per-point data: `id`, `preferred_enemy_types`, `weight`, `enabled` |
| Wave | `WaveResource.spawn_entries: Array[SpawnEntry]` | Per-spawn-event config: `spawn_point_id`, `count`, `delay_between`, `formation` |
| Runtime | `SpawnDirector` or `WaveManager` | Selects spawn points, computes offsets, instantiates enemies |

Scene tree structure:
```
Level (Node2D)
  SpawnPoints (Node2D)
    SpawnPoint_Top (Marker2D)  → group: "spawn_points"
    SpawnPoint_Left (Marker2D)  → group: "spawn_points"
    SpawnPoint_Right (Marker2D) → group: "spawn_points"
  EnemyPath (Path2D)            → curve from spawn area to base
  WaveManager (Node)            → orchestrates spawning
```

---

## Implementation Patterns

### 1. Marker2D Spawn Points

Place `Marker2D` nodes in the editor as children of a container `Node2D`. Add each to the `"spawn_points"` group. At runtime, collect via `get_tree().get_nodes_in_group("spawn_points")`.

**Key rule**: Always use `global_position` when reading Marker2D coordinates, never `position` (which is local to the parent).

### 2. Extended Marker2D with Per-Point Config

Attach a custom script to each Marker2D to store editor-configurable properties:

- `point_id: String` — unique identifier for wave references
- `weight: int` — higher weight = more likely to be selected in random mode
- `enabled: bool` — toggle without removing from scene tree
- `preferred_enemy_types: Array[PackedScene]` — restrict which enemies use this point
- `spawn_radius: float` — random offset radius around the exact point (anti-bunching)

### 3. Edge-Based vs Fixed-Point Spawning

| Approach | When to Use | Implementation |
|----------|-------------|----------------|
| **Fixed Marker2D points** | Defined lanes, story missions, boss entries | Place Marker2D nodes directly; spawn enemies at `marker.global_position` |
| **Path2D edge ring** | Survival/horde, random screen-edge entry | Closed Path2D around viewport perimeter; `PathFollow2D.progress_ratio = randf()` yields random edge position |
| **CollisionShape area** | Clustered spawning within a zone | Disabled CollisionShape2D (Rectangle/Circle); sample random point inside with `randf_range(-extents, extents)` |
| **Grid-aligned points** | Tilemap-based games | Read custom data layer from `TileMap` or compute from `map_to_local(grid_coord)` |

### 4. Formation Offsets from Spawn Point

Instead of stacking all enemies at the exact same coordinate, apply formation offsets calculated relative to the spawn point:

- **Line**: `offset = Vector2(i * spacing, 0)` — enemies enter single-file
- **Row**: `offset = Vector2((i % cols) * spacing - row_center, (i / cols) * row_spacing)` — block formation
- **Arc**: `offset = Vector2.from_angle(start_angle + i * arc_step) * arc_radius` — fan/spread entry
- **Staggered**: `offset = row_offset; row_offset.x *= -1; row_offset.y += row_spacing` — alternating zigzag

### 5. Spawn Entry Data Structures

A `SpawnEntry` (or group definition within `WaveResource`) connects wave logic to spawn geometry:

```
SpawnEntry:
  spawn_point_id: String       # matches Marker2D.point_id (empty = pick any)
  enemy_scene: PackedScene     # which enemy to spawn
  count: int                   # how many
  delay_between: float         # seconds between each spawn
  formation: FormationType     # LINE, ROW, ARC, NONE
  formation_spacing: float     # spacing between units in formation
  jitter: float                # random offset applied per enemy (anti-bunching)
```

### 6. Deterministic vs Randomized Selection

| Selection Mode | Method | Use Case |
|----------------|--------|----------|
| **Round-robin** | `spawn_points[index % spawn_points.size()]` | Even distribution across all points |
| **Weighted random** | Weighted pick from `Array[Marker2D]` using `weight` property | Variety with designer control |
| **By ID** | Match `SpawnEntry.spawn_point_id` to `Marker2D.point_id` | Story missions, specific entry lanes |
| **All points** | Iterate all enabled points, spawn from each | Siege waves, multi-directional attacks |
| **Furthest from base** | Sort by `distance_to(base.global_position)` descending | Challenge waves, overwhelming force |

### 7. Path-Based Entry (Spawn → Base Route)

For fixed-path TD games, the spawn point feeds into a `Path2D`:

1. Enemy spawns at Marker2D position (or first point of Path2D curve)
2. Enemy is added as child of a `PathFollow2D` node
3. `PathFollow2D.progress` increments each frame: `progress += speed * delta`
4. PathFollow2D's child enemy automatically follows the curve

For multi-segment or per-enemy paths, each spawned enemy gets its own `PathFollow2D` instance added to the shared `Path2D` node.

### 8. Limiting Concurrent Spawn Locations

Track recently-used spawn points to prevent all enemies from entering through the same point:

```
var _last_used_index: int = -1

func pick_spawn_point() -> Marker2D:
    var points: Array = get_tree().get_nodes_in_group("spawn_points")
    var available: Array = points.duplicate()
    if _last_used_index >= 0:
        available.erase(points[_last_used_index])  # deprioritize last point
    var chosen: Marker2D = available[randi() % available.size()]
    _last_used_index = points.find(chosen)
    return chosen
```

---

## Code Snippet Examples

### SpawnPoint (extended Marker2D)

```gdscript
class_name SpawnPoint
extends Marker2D

@export var point_id: String = ""
@export var weight: int = 1
@export var enabled: bool = true
@export var preferred_types: Array[PackedScene] = []

func _ready() -> void:
    add_to_group("spawn_points")
```

### SpawnEntry Resource

```gdscript
class_name SpawnEntry
extends Resource

enum FormationType { NONE, LINE, ROW, ARC, STAGGERED }

@export var spawn_point_id: String = ""
@export var enemy_scene: PackedScene
@export var count: int = 1
@export var delay_between: float = 0.5
@export var formation: FormationType = FormationType.NONE
@export var formation_spacing: float = 16.0
@export var position_jitter: float = 4.0
```

### SpawnDirector — spawn point selection

```gdscript
class_name SpawnDirector
extends Node

signal enemy_spawned(enemy: Node2D)

@export var spawn_points_parent: Node2D

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func get_spawn_points() -> Array[SpawnPoint]:
    var result: Array[SpawnPoint] = []
    for child in spawn_points_parent.get_children():
        if child is SpawnPoint and child.enabled:
            result.append(child)
    return result

func pick_spawn_point_by_id(id: String) -> SpawnPoint:
    for sp in get_spawn_points():
        if sp.point_id == id:
            return sp
    return null

func pick_weighted_random() -> SpawnPoint:
    var points: Array[SpawnPoint] = get_spawn_points()
    if points.is_empty():
        return null
    var total_weight: int = 0
    for sp in points:
        total_weight += sp.weight
    var roll: int = _rng.randi_range(1, total_weight)
    var cumulative: int = 0
    for sp in points:
        cumulative += sp.weight
        if roll <= cumulative:
            return sp
    return points.back()

func spawn_enemy(entry: SpawnEntry, index: int) -> Node2D:
    var point: SpawnPoint = null
    if entry.spawn_point_id:
        point = pick_spawn_point_by_id(entry.spawn_point_id)
    if not point:
        point = pick_weighted_random()
    if not point:
        return null

    var enemy: Node2D = entry.enemy_scene.instantiate()
    var base_pos: Vector2 = point.global_position
    var offset: Vector2 = _compute_formation_offset(entry, index)
    var jitter: Vector2 = Vector2(
        _rng.randf_range(-entry.position_jitter, entry.position_jitter),
        _rng.randf_range(-entry.position_jitter, entry.position_jitter)
    )
    enemy.global_position = base_pos + offset + jitter
    enemy_spawned.emit(enemy)
    return enemy

func _compute_formation_offset(entry: SpawnEntry, index: int) -> Vector2:
    match entry.formation:
        SpawnEntry.FormationType.LINE:
            return Vector2(index * entry.formation_spacing, 0)
        SpawnEntry.FormationType.ROW:
            var cols: int = 4
            var row: int = index / cols
            var col: int = index % cols
            var half: float = (cols - 1) * entry.formation_spacing * 0.5
            return Vector2(col * entry.formation_spacing - half, row * entry.formation_spacing)
        SpawnEntry.FormationType.ARC:
            var total: float = entry.count - 1
            var angle_step: float = PI / (total + 1) if total > 0 else 0
            var start_angle: float = -PI * 0.5
            var dir: Vector2 = Vector2.from_angle(start_angle + index * angle_step)
            return dir * entry.formation_spacing
        _:
            return Vector2.ZERO
```

### Edge-Based Spawning via Path2D

```gdscript
# Place a closed Path2D around the visible play area perimeter
@onready var edge_path: Path2D = %EdgePath
@onready var path_follow: PathFollow2D = %EdgePath/PathFollow

func random_edge_position() -> Vector2:
    path_follow.progress_ratio = randf()
    return path_follow.global_position
```

### Weighted Spawn Point Selection (utility)

```gdscript
static func weighted_pick(points: Array[SpawnPoint], rng: RandomNumberGenerator) -> SpawnPoint:
    var total: int = 0
    for p in points:
        total += p.weight
    var roll: int = rng.randi_range(1, total)
    var accumulated: int = 0
    for p in points:
        accumulated += p.weight
        if roll <= accumulated:
            return p
    return points.back()
```

### PathFollow2D Enemy Spawning (path-based movement)

```gdscript
# In WaveManager or SpawnDirector
@onready var enemy_path: Path2D = %EnemyPath

func spawn_on_path(entry: SpawnEntry) -> void:
    for i in entry.count:
        var enemy: Node2D = entry.enemy_scene.instantiate()
        var follow: PathFollow2D = PathFollow2D.new()
        follow.loop = false
        follow.rotate = true
        follow.progress = 0.0
        enemy_path.add_child(follow)
        follow.add_child(enemy)
        enemy.global_position = follow.global_position
        # Store reference so enemy can advance itself each frame:
        enemy.set("path_follow", follow)
        await get_tree().create_timer(entry.delay_between).timeout
```

### Spawn Score/Difficulty Budget with Location Constraints

```gdscript
func score_spawn_point(point: SpawnPoint, wave_index: int) -> float:
    var score: float = 0.0
    score += point.weight * 2.0
    score += randf_range(0.0, 5.0)  # small randomness for variety
    if wave_index > 5 and point.point_id in ["boss_gate", "secret_passage"]:
        score += 20.0  # unlock harder spawn points later
    return score
```

---

## Limitations

| Aspect | Limitation |
|--------|------------|
| **Editor visibility** | Marker2D gizmo extents may be hard to see at zoomed-out level. Set `gizmo_extents` larger (e.g., 30–50) for visibility |
| **Group collection cost** | `get_tree().get_nodes_in_group("spawn_points")` O(n) each call. Cache in `_ready()` for performance |
| **Formation on non-flat terrain** | Formation offsets assume flat plane; for games with elevation, project offsets onto walkable surface |
| **Path2D per enemy overhead** | Each enemy needs its own `PathFollow2D` child on the shared `Path2D`. 100+ enemies = 100+ PathFollow2D nodes. Acceptable for most TD games (<200 enemies) |
| **Edge path viewport mismatch** | If camera moves/scales, the edge Path2D must match the visible area. Either camera-lock or re-bake the path on resize |
| **Serialization of PackedScene in resources** | `PackedScene` as `@export` works in inspector but serializes as path string. Ensure scenes are not moved/renamed after .tres creation |
| **Weighted selection predictability** | Pure weighted random can cluster on the same point. Add deweighting logic (reduce weight temporarily after selection) |
| **Per-point `preferred_enemy_types`** | If all preferred-types checks fail, may select an incompatible point. Add fallback: any enabled point if no match |

## Alternatives

| Alternative | Trade-off |
|-------------|-----------|
| **Hardcoded Vector2 arrays** | Fastest to prototype, no editor-visual placement. Brittle when positions change |
| **TileMap custom data layers** | Good for grid-based games. No visual dragging, requires tile coordinate math via `map_to_local()` |
| **Plugin-based (ArtinTheCoder Spawner)** | Drag-and-drop spawn areas with CollisionShape bounds. Less control over weighted selection and formations |
| **Single Path2D for both entry and path** | Use one Path2D for spawn-to-base movement; spawn at `progress_ratio = 0.0`. Simplified topology but no multi-point entry |
| **NavigationAgent2D instead of Path2D** | Dynamic pathfinding from spawn to base — enemies navigate around obstacles. Higher CPU cost, supports mazing gameplay |
| **Object pooling with spawn-position reset** | Enemies recycled from pool are repositioned to spawn point. Must call `set_deferred("global_position", ...)` to avoid physics glitches |
| **Procedural edge points (no Marker2D)** | Compute `spawn_points` at runtime from `get_viewport_rect()` bounds. No editor tuning, but adapts to any screen size |
