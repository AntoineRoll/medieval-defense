# Grid-Based Placement & Validation in Godot 4

## References

- [Grid Placement Plugin v5.0.3](https://chris-tutorials.itch.io/grid-placement-godot) — mature open-source plugin with 1,753 automated tests, TileMapLayer-based
- [Grid Building Plugin README (Pastebin)](https://pastebin.com/xGBhnSHc) — architecture docs for rule-based placement validation
- [16BitDev: Base Building System RTS YouTube](https://www.youtube.com/watch?v=CJz4Oo3ISy4) — grid snapping, overlap avoidance, preview tile in Godot 4
- [PhysicsDirectSpaceState2D docs (Godot 4.6)](https://docs.godotengine.org/en/4.6/classes/class_physicsdirectspacestate2d.html) — intersect_shape, intersect_point, intersect_ray API
- [PhysicsShapeQueryParameters2D docs](https://docs.godotengine.org/en/4.2/classes/class_physicsshapequeryparameters2d.html) — shape, transform, collision_mask, exclude usage
- [Godot Physics Ray-Casting docs](https://docs.godotengine.org/en/4.5/tutorials/physics/ray-casting.html) — space state lifecycle, must query in `_physics_process`
- [RTS Framework (rluders)](https://github.com/rluders/rts-framework) — Godot 4 RTS framework with construction pipeline, entity-component design
- [GodotInGameBuildingSystem (MarkoDM)](https://github.com/MarkoDM/GodotInGameBuildingSystem) — grid-based + free-form building, BuildableResource pattern
- [Refactoring Building Placement (Ryan Stefan)](https://dashwood.net/blog/2025-06-02-from-grid-to-geometry-refactoring-building-placement-in-a-hex-based-3d-rts) — real-world case study: abandoned cell-based occupancy for physics `intersect_shape`
- [Simple Asset Placer (fabian-becker)](https://github.com/fabian-becker/simple-asset-placer) — grid snapping formula `snapped = floor((pos - offset) / step) * step + offset`
- [TileMapLayer docs (Godot stable)](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html) — `map_to_local`, `local_to_map`, TileSet-based grid

---

## Recommended Pattern

**Hybrid approach: TileMapLayer for static terrain + individual Area2D/StaticBody2D nodes for placeable buildings.**

| Concern | Recommendation |
|---|---|
| Terrain & walkability | TileMapLayer with collision-enabled tiles (ground, water, obstacles) |
| Placed buildings | Individual Area2D/StaticBody2D with CircleShape2D or RectangleShape2D |
| Grid snapping math | `snapped()` function for alignment to tile grid |
| Overlap detection | `PhysicsDirectSpaceState2D.intersect_shape()` in `_physics_process` |
| Preview / ghost | Temporary Node2D instance with modulated Sprite2D, updated each frame |
| Placement validation | Rule-based system: collision check → tile type check → bounds check → resource cost check |

---

## Implementation Patterns

### 1. Grid Snapping Math

Two approaches:

**Snapped function (built-in):**
```gdscript
var tile_size := Vector2(16, 16)
var mouse_pos: Vector2 = get_global_mouse_position()
var snapped_pos: Vector2 = mouse_pos.snapped(tile_size)
```

**Manual floor-divide (with offset support):**
```gdscript
func snap_to_grid(pos: Vector2, tile_size: Vector2, offset: Vector2 = Vector2.ZERO) -> Vector2:
    var grid = (pos - offset) / tile_size
    return grid.floor() * tile_size + offset
```

The `snapped()` function rounds to nearest multiple, so position may land at tile edges. For center-based placement, subtract half tile_size, snap, then add half tile_size back. Use `map_to_local()` if using TileMapLayer coordinates.

### 2. Placement Validation via Physics Queries

**intersect_shape** (recommended for buildings with area):
```gdscript
func is_placement_valid(shape: Shape2D, transform: Transform2D, exclude: Array) -> bool:
    var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
    var params := PhysicsShapeQueryParameters2D.new()
    params.shape = shape
    params.transform = transform
    params.exclude = exclude
    params.collide_with_bodies = true
    params.collide_with_areas = true
    params.collision_mask = PLACEMENT_MASK  # dedicated layer for buildings
    var results: Array = space_state.intersect_shape(params)
    return results.is_empty()
```

**Key notes:**
- Must call in `_physics_process` — space state is locked during `_process`/`_input`
- `exclude` assignment replaces the array each time (bug: setting via `append` doesn't work; see godotengine#93895)
- Add a dedicated collision layer for placed buildings; query only that layer
- `intersect_shape` has a `max_results` cap (default 32); increase for dense maps
- Performance degrades with 3000+ overlapping Area2Ds (godotengine#94367) — use `collision_mask` filtering and simplified collision shapes

**Alternative: intersect_point:**
```gdscript
var point_params := PhysicsPointQueryParameters2D.new()
point_params.position = snapped_pos
point_params.collide_with_areas = true
point_params.collision_mask = PLACEMENT_MASK
var hits = space_state.intersect_point(point_params)
```
Only useful for single-tile occupancy checks. Not suitable for multi-tile buildings.

**Alternative: Manual distance check:**
```gdscript
func is_area_free(pos: Vector2, radius: float) -> bool:
    for building in get_tree().get_nodes_in_group("buildings"):
        if building.global_position.distance_to(pos) < radius + building.get_hitbox_radius():
            return false
    return true
```
Simpler, no physics dependency, but O(n) scan and doesn't catch non-building colliders.

### 3. Ghost / Preview Object

```gdscript
@onready var preview: Sprite2D = $PreviewSprite

func _physics_process(_delta: float) -> void:
    var mouse_pos: Vector2 = get_global_mouse_position()
    var snapped: Vector2 = mouse_pos.snapped(tile_size) + tile_size * 0.5  # center
    preview.global_position = snapped

    var shape := preview.get_node("CollisionShape2D").shape
    var xform := Transform2D(0, snapped)
    var valid := is_placement_valid(shape, xform, [self])
    preview.modulate = Color(0, 1, 0, 0.5) if valid else Color(1, 0, 0, 0.5)
```

**Two approaches for the ghost:**
- **Instance the actual scene** (set `modulate`, disable processing). Accurate collision shape matching, but heavier.
- **Use a dedicated preview node** with matching Sprite2D and CollisionShape2D. Lightweight, manually keep in sync.

### 4. TileMapLayer vs Individual Node2D

| Aspect | TileMapLayer | Individual Node2D (Area2D/StaticBody2D) |
|---|---|---|
| Terrain | Excellent — optimized for large grids, built-in collision per tile | Overkill — 1000s of nodes for background |
| Dynamic buildings | Awkward — tile data isn't designed for HP, upgrades, animations | Natural — each node is a full scene with scripts, state, children |
| Runtime modification | `set_cell()` valid, but limited to tile atlas | Full freedom: move, rotate, scale, animate |
| Overlap detection | Manual cell-occupancy tracking | Built-in physics queries / Area signals |
| Navigation updates | Must re-bake navigation layer | Can add/remove NavigationObstacle2D per building |
| Save/load | Cell coordinates + source IDs | Node persistence via Resource |
| Multi-tile buildings | Need multi-cell claim logic, bookkeeping | Single collision shape covers whole footprint |

**Hybrid recommendation:** TileMapLayer for ground/obstacles/walkability map. Placeable buildings as individual Area2D scenes with collision. Use `intersect_shape` against the building collision layer to detect overlaps, and TileMapLayer cell queries to check terrain type underneath.

### 5. RTS Overlap Detection Strategies

1. **Physics-based (recommended for Godot 4):** Use `intersect_shape` with a shape matching the building footprint. No occupancy map to maintain. Handles rotated buildings naturally. Pre-compute simplified collision shapes for performance.

2. **Cell-based occupancy grid:** Maintain a Dictionary/Array of claimed cells. Fast lookup O(1), but requires multi-cell building claim logic, manual sync on move/destroy, and doesn't integrate with physics.

3. **Area2D overlaps_area():** Node-based, waits one frame for overlap results. Can use `get_overlapping_areas()` after adding to tree, but the async delay makes it unreliable for instant validation.

### 6. PhysicsDirectSpaceState2D Lifecycle

```gdscript
# Only valid during _physics_process
func _physics_process(_delta: float) -> void:
    var space_state := get_world_2d().direct_space_state  # safe to use here
    # queries...

# NOT valid here:
func _process(_delta: float) -> void:
    # get_world_2d().direct_space_state may return null or stale data
    pass
```

The space state is locked outside the physics callback. Cache the reference inside `_physics_process` if needed elsewhere, but don't store across frames.

---

## Code Snippet Examples

### Complete Placement Controller

```gdscript
class_name PlacementController
extends Node2D

@export var tile_size := Vector2(16, 16)
@export var building_scene: PackedScene
@export var placement_mask := 2  # collision layer for placed buildings

var is_placing := false
var preview_instance: Node2D

func _ready() -> void:
    preview_instance = building_scene.instantiate()
    preview_instance.modulate = Color(1, 1, 1, 0.5)
    for child in preview_instance.find_children("*", "CollisionShape2D"):
        child.disabled = false
    preview_instance.process_mode = PROCESS_MODE_DISABLED
    add_child(preview_instance)

func _physics_process(_delta: float) -> void:
    if not is_placing:
        preview_instance.visible = false
        return
    var mouse_pos: Vector2 = get_global_mouse_position()
    var snapped_pos: Vector2 = mouse_pos.snapped(tile_size) + tile_size * 0.5
    preview_instance.global_position = snapped_pos
    preview_instance.visible = true

    var valid := _check_placement(snapped_pos)
    preview_instance.modulate = Color(0, 1, 0, 0.4) if valid else Color(1, 0, 0, 0.4)

func _check_placement(pos: Vector2) -> bool:
    var space_state := get_world_2d().direct_space_state
    var shape_node := preview_instance.find_child("CollisionShape2D") as CollisionShape2D
    if not shape_node or not shape_node.shape:
        return false
    var params := PhysicsShapeQueryParameters2D.new()
    params.shape = shape_node.shape
    params.transform = Transform2D(0, pos)
    params.collision_mask = placement_mask
    params.collide_with_bodies = true
    params.collide_with_areas = true
    params.exclude = [preview_instance]
    return space_state.intersect_shape(params).is_empty()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("place") and is_placing:
        var pos := preview_instance.global_position
        if _check_placement(pos):
            var building := building_scene.instantiate()
            building.global_position = pos
            add_child(building)
            building.add_to_group("buildings")
```

### Grid Utilities (TileMapLayer-integrated)

```gdscript
func world_to_tile(world_pos: Vector2, tilemap: TileMapLayer) -> Vector2i:
    return tilemap.local_to_map(tilemap.to_local(world_pos))

func tile_to_world(tile: Vector2i, tilemap: TileMapLayer) -> Vector2:
    return tilemap.to_global(tilemap.map_to_local(tile))

func get_tile_data(tile: Vector2i, tilemap: TileMapLayer) -> Dictionary:
    var source_id := tilemap.get_cell_source_id(tile)
    var atlas_coords := tilemap.get_cell_atlas_coords(tile)
    return {"source": source_id, "atlas": atlas_coords}
```

---

## Limitations

| Limitation | Detail |
|---|---|
| Space state lock | `intersect_shape` only callable in `_physics_process` — lag in mouse position tracking vs validation |
| Physics query cost | `intersect_shape` scans the broadphase; with 3000+ overlapping Area2Ds it can return empty results due to internal result limits |
| Exclude array gotcha | Must use `params.exclude = [...]` (assignment), not `append()` — the latter silently fails |
| Ghost sync | Preview follows mouse in `_physics_process` but game logic runs at physics rate (60Hz), which can feel less responsive than `_process` |
| TileMapLayer rotation | TileMapLayer only supports 90-degree rotations on tiles; free rotation requires individual nodes |
| Multi-tile buildings | Each building needs a single collision shape covering its entire footprint for `intersect_shape` to work correctly; don't use per-tile Area2Ds |
| Navigation re-bake | Placed buildings block navigation; must update NavigationRegion2D or add NavigationObstacle2D dynamically |
| Cell-based adjacency | Physics queries don't distinguish "adjacent" vs "overlapping" — use `cast_motion` or manual distance checks if adjacency is needed |

---

## Alternatives

| Alternative | When to use |
|---|---|
| **Cell-based Dictionary grid** (`var grid: Dictionary = {}`) | Turn-based games, small grids, no physics system needed. Fast O(1) checks, no physics dependency. |
| **Area2D overlap signals** (`area_entered`/`area_exited`) | Simple validation where 1-frame delay is acceptable. Less code, no `_physics_process` dependency. |
| **Grid Placement Plugin (Chris' Tutorials)** | Production-ready, 1,753 tests, rule-based, active maintenance. Use if you want a framework rather than building from scratch. |
| **Free-form (no grid)** | Games where organic placement matters (e.g., survival crafting). Use `intersect_shape` without snapping. |
| **TileMap with custom layer for buildings** | Static buildings that never need to be moved/destroyed. Edit-time only placement. |
| **RTS Framework** | Full RTS game (units, buildings, construction queue). If building a complete RTS, consider this as a foundation. |
