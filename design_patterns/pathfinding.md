# Pathfinding & Navigation in Godot 4 2D

## References

- Godot 4.6 Navigation docs: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html
- NavigationAgent2D docs: https://docs.godotengine.org/en/4.6/classes/class_navigationagent2d.html
- NavigationServer2D docs: https://docs.godotengine.org/en/4.1/classes/class_navigationserver2d.html
- NavigationPolygon docs: https://docs.godotengine.org/en/4.6/classes/class_navigationpolygon.html
- NavigationPathQueryParameters2D: https://docs.godotengine.org/en/4.6/classes/class_navigationpathqueryparameters2d.html
- Optimizing Navigation Performance: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html
- Using NavigationObstacles: https://docs.godotengine.org/cs/4.x/tutorials/navigation/navigation_using_navigationobstacles.html
- Using navigation meshes (runtime bake): https://docs.godotengine.org/en/4.5/tutorials/navigation/navigation_using_navigationmeshes.html
- Official Godot 2D Navigation Polygon demo: https://github.com/godotengine/godot-demo-projects/tree/master/2d/navigation
- Official AStarGrid2D demo: https://github.com/godotengine/godot-demo-projects/tree/master/2d/navigation_astar
- smix8 navigation PRs (Godot core contributor): https://github.com/godotengine/godot/pulls?q=is%3Apr+author%3Asmix8+navigation
- Quiver Tower Defense Godot 4: https://github.com/quiver-dev/tower-defense-godot4
- Godot RTS Entity Controller: https://github.com/philipbeaucamp/godot-rts-entity-controller
- Dante's Lab 2D Navigation guide: https://www.dlab.ninja/2025/02/2d-navigation-in-godot.html
- Pathfinding with AStarGrid2D (papierkorp): https://papierkorp.github.io/blog/posts/godot-4-2d-pathing

---

## Recommended Pattern

**Primary: NavigationServer2D + NavigationRegion2D + NavigationAgent2D**

For a top-down 2D tower defense / medieval defense game with buildings that block movement, the NavigationServer2D-based mesh system is the recommended approach. This is the same pattern Godot's official 2D navigation demo uses.

**Why:**
- Mesh-based navigation scales well — large open areas are covered by few polygons
- NavigationAgent2D provides built-in RVO avoidance between units
- NavigationObstacle2D can dynamically push away agents from buildings
- Supports runtime rebaking when buildings are placed/destroyed
- A* is handled internally on the NavigationServer, not per-unit
- Battle-tested in Quiver's Outpost Assault TD and similar projects

**Fallback: AStarGrid2D** for grid-based maps where all movement snaps to a tile grid and building placement is tile-aligned. Simpler to update dynamically (just call `set_point_solid()`), but requires more memory for large maps and agents move cell-to-cell rather than smoothly.

---

## Implementation Patterns

### 1. Static Navigation Mesh Setup (Editor)

1. Add `NavigationRegion2D` as a child of the main level node
2. Assign a `NavigationPolygon` resource — draw the outer boundary outline (walkable area)
3. Add child `StaticBody2D` nodes with `CollisionShape2D` for map obstacles (trees, rocks, map walls)
4. In the NavigationPolygon resource, set `parsed_collision_mask` to match the collision layer of obstacles
5. Click **Bake NavigationPolygon** — this carves holes in the nav mesh for each obstacle
6. Set `agent_radius` in NavigationPolygon to the unit collision radius (~8px = 0.5 grid units) to shrink the mesh so unit centers stay within walkable area

### 2. Unit Movement with NavigationAgent2D

Each moving unit (enemies, player units) gets a `CharacterBody2D` with a `NavigationAgent2D` child. In `_physics_process`:

```
func _physics_process(_delta):
    if navigation_agent.is_navigation_finished():
        return
    var next = navigation_agent.get_next_path_position()
    velocity = global_position.direction_to(next) * speed
    move_and_slide()
```

Call `navigation_agent.target_position = destination` to initiate pathfinding. Wait for one physics frame after scene load before querying paths (NavigationServer syncs at end of physics frame).

### 3. Dynamic Building Placement — Rebaking

When a building is placed or destroyed at runtime:

**Option A: Full rebake (simplest, most expensive)**
```
navigation_region.bake_navigation_polygon()
```
This parses all child StaticBody2D nodes and rebakes. Must be called deferred:
```
call_deferred("bake_navigation_polygon")
```
Performance: 1-2 rebakes per second max. Frame drops expected during bake (runs on background thread but parsing is main-thread).

**Option B: Procedural region update (faster, manual)**
1. Maintain a single large `NavigationPolygon`
2. When a building is placed, add its collision outline as an obstruction to `NavigationMeshSourceGeometryData2D`
3. Use `NavigationServer2D.bake_from_source_geometry_data_async()` on a background thread
4. On completion callback, call `NavigationServer2D.region_set_navigation_polygon(region_rid, new_polygon)`

```
var source_geo = NavigationMeshSourceGeometryData2D.new()
source_geo.add_traversable_outline(bounds_outline)
for building in all_buildings:
    source_geo.add_obstruction_outline(building.collision_outline)
NavigationServer2D.bake_from_source_geometry_data_async(
    navigation_polygon, source_geo, on_bake_finished
)
```

**Option C: NavigationObstacle2D (no rebake, avoidance-only)**
- Add a `NavigationObstacle2D` child to each building with `avoidance_enabled = true` and `radius` set
- This does NOT affect pathfinding — only the RVO avoidance layer
- Units will still path through buildings unless you also update the nav mesh
- Best used as a supplement to Option A/B to push units away from building edges

### 4. Hybrid Approach (Recommended for Medieval Defense)

1. Bake a static navigation mesh at startup for the map terrain (including walls, trees, etc.)
2. For buildings placed during gameplay, use `NavigationObstacle2D` with static vertices for avoidance
3. Batch-rebake the nav mesh every ~5-10 building placements (or after a short delay) using `bake_from_source_geometry_data_async`
4. Mark dirty flag on building placement, rebake in `_process` when dirty and enough time has elapsed

This avoids per-building rebake cost while still eventually updating actual pathfinding.

### 5. AStarGrid2D Alternative

For a strictly tile-based approach (64px grid):

```
var astar = AStarGrid2D.new()
astar.region = Rect2i(0, 0, map_width, map_height)
astar.cell_size = Vector2i(16, 16)
astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
astar.update()

# Mark building tiles as solid
for building_pos in building_tiles:
    astar.set_point_solid(building_pos)

# Query path
var path = astar.get_point_path(start_cell, end_cell)
```

Update is O(1) per cell — call `set_point_solid()` on placement/destruction and `update()`. No rebaking needed. But path is a series of tile centers, requiring smoothing for natural movement.

---

## Code Snippet Examples

### Minimal NavigationAgent2D movement

```
extends CharacterBody2D

@export var speed: float = 60.0
@onready var nav: NavigationAgent2D = $NavigationAgent2D

func _ready():
    nav.path_desired_distance = 4.0
    nav.target_desired_distance = 4.0
    actor_setup.call_deferred()

func actor_setup():
    await get_tree().physics_frame
    nav.target_position = global_position + Vector2(100, 0)

func _physics_process(_delta):
    if nav.is_navigation_finished():
        return
    var next = nav.get_next_path_position()
    velocity = global_position.direction_to(next) * speed
    move_and_slide()
```

### Runtime nav mesh rebake on building placed

```
extends Node2D

@onready var nav_region: NavigationRegion2D = %NavigationRegion2D
var nav_polygon: NavigationPolygon
var rebuild_queued := false

func _ready():
    nav_polygon = nav_region.navigation_polygon.duplicate()

func on_building_placed(building_position: Vector2, building_size: Vector2):
    # Add a new StaticBody2D child to the nav region for rebaking
    var obstacle = StaticBody2D.new()
    var shape = CollisionShape2D.new()
    shape.shape = RectangleShape2D.new()
    shape.shape.size = building_size
    obstacle.position = building_position
    nav_region.add_child(obstacle)
    
    if not rebuild_queued:
        rebuild_queued = true
        rebuild_navmesh.call_deferred()

func rebuild_navmesh():
    nav_region.bake_navigation_polygon()
    rebuild_queued = false
```

### AStarGrid2D for tile-based pathfinding

```
extends Node2D

var astar: AStarGrid2D
var current_path: PackedVector2Array

func _ready():
    astar = AStarGrid2D.new()
    astar.region = Rect2i(0, 0, 64, 64)
    astar.cell_size = Vector2i(16, 16)
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    astar.update()

func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
    var from_cell = local_to_map(from_world)
    var to_cell = local_to_map(to_world)
    return astar.get_point_path(from_cell, to_cell)

func add_obstacle(cell: Vector2i):
    astar.set_point_solid(cell)

func remove_obstacle(cell: Vector2i):
    astar.set_point_solid(cell, false)

func local_to_map(world_pos: Vector2) -> Vector2i:
    return Vector2i(
        int(floor(world_pos.x / 16.0)),
        int(floor(world_pos.y / 16.0))
    )
```

### NavigationObstacle2D for building avoidance (no rebake)

```
extends StaticBody2D

@onready var nav_obstacle: NavigationObstacle2D = $NavigationObstacle2D

func _ready():
    nav_obstacle.radius = 8.0  # half a tile
    nav_obstacle.avoidance_enabled = true
    nav_obstacle.avoidance_layers = 1

# For buildings with a defined shape, use static vertices:
func set_static_obstacle_shape(vertices: PackedVector2Array):
    nav_obstacle.vertices = vertices
    nav_obstacle.radius = 0.0  # disable dynamic radius when using static
```

---

## Limitations

| Approach | Limitation |
|----------|-----------|
| NavigationServer2D rebaking | Runtime rebake is expensive (main-thread parsing). Max 1-2x/sec. Frame drops during parse. |
| NavigationServer2D rebaking | TileMap baking from many cells creates thousands of tiny polygons — path search slows dramatically when target unreachable |
| NavigationAgent2D avoidance | Avoidance creates callback per agent — 5000+ agents with avoidance enabled tanks FPS to single digits |
| NavigationAgent2D avoidance | RVO simulation exists independent of nav mesh — agents can be pushed off the mesh by crowd pressure |
| NavigationObstacle2D | Does NOT affect pathfinding, only avoidance velocity. Units will still path through buildings. |
| Static NavigationObstacle vertices | Cannot move each frame (must rebuild = expensive). Use dynamic radius for moving objects. |
| AStarGrid2D | Path is cell-aligned — requires post-processing for natural movement, no built-in avoidance |
| NavigationLink2D | Only connects two points, not suitable for dynamic obstacle networks |
| NavigationAgent2D `get_next_path_position()` | Must call every physics frame; calling after path finished = jitter |
| `velocity_computed` signal | Only fires when `avoidance_enabled = true`; missing in some Godot 4.x versions |

### Key performance numbers (from Godot issues & docs)
- 5000 agents with avoidance ON: 4-5 FPS → ON DEMAND toggle: 44-52 FPS (10x improvement)
- 15264 TileMap cells as individual nav polys: 50000+ polygon edges → path search on unreachable target stutters badly
- Runtime parse from MeshInstance2D nodes: stalls rendering (GPU→CPU readback)
- Rebuild static NavigationObstacle vertices: expensive per-frame, intended for placement only

---

## Alternatives

| Alternative | Use Case | Trade-off |
|-------------|----------|-----------|
| **AStar2D** (manual graph) | Non-grid irregular graphs (waypoint networks) | Must manually add/connect nodes; no built-in avoidance |
| **AStarGrid2D** | Strict tile grids (Fire Emblem-style) | Cell-aligned movement; no avoidance; very cheap per-cell updates |
| **NavigationLink2D** | Connecting disjoint nav meshes (bridges, teleporters) | Not for dynamic obstacles; used for level design |
| **Manual RVO library** | Full control over avoidance behavior | Must implement from scratch; Godot's built-in RVO2 already integrated |
| **NavigationServer2D direct API** (no nodes) | Maximum control, no scene tree overhead | Must manage RIDs, maps, agents manually |
| **PathFollow2D** | Fixed patrol paths (no dynamic pathfinding) | Not true pathfinding; ignores obstacles |
| **Custom A* over world grid** | Simple games with small maps | Reinventing the wheel; no built-in debug visualization |
| **Avoidance-only (no pathfinding)** | Ambient creatures, flocks | Units can't find routes around obstacles; only push away |

### When to choose AStarGrid2D over NavigationServer2D

- Map is strictly tile-based (buildings snap to grid)
- You need O(1) obstacle updates (just `set_point_solid`)
- Movement is tile-to-tile (RPG, tactics)
- You have < 5000 cells and < 100 agents

### When to choose NavigationServer2D over AStarGrid2D

- Freeform movement (pixel-based, not grid-snapped)
- Large open areas between obstacles
- Many agents with RVO avoidance needed
- Buildings are not strictly tile-aligned
- You need navigation layers for different unit types (ground vs flying)
