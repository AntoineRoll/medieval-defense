# Targeting System Patterns (Godot 4)

## References

- Godot docs: `Area2D` overlap detection (body_entered/exited signals) — docs.godotengine.org/en/4.6/tutorials/physics/using_area_2d.html
- Godot docs: `PhysicsDirectSpaceState2D.intersect_shape()` — docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html
- Godot docs: `PhysicsShapeQueryParameters2D` — docs.godotengine.org/en/4.5/classes/class_physicsshapequeryparameters2d.html
- Godot docs: Groups system — docs.godotengine.org/en/4.0/tutorials/scripting/groups.html
- Godot docs: Node alternatives (Resource vs Node for data) — docs.godotengine.org/en/4.2/tutorials/best_practices/node_alternatives.html
- Godot docs: Scene organization best practices — docs.godotengine.org/en/4.2/tutorials/best_practices/scene_organization.html
- kidscancode.org: Chasing the player pattern (Area2D detect radius) — kidscancode.org/godot_recipes/4.x/ai/chasing
- kidscancode.org: Changing behaviors (dual-area detect/attack radii) — kidscancode.org/godot_recipes/4.x/ai/changing_behaviors
- kidscancode.org: Node communication patterns — kidscancode.org/godot_recipes/4.x/basics/node_communication
- GameDev Academy: RTS tutorial (target-check loop, attack rate) — gamedevacademy.org/godot-rts-tutorial
- GitHub: godot-rts-entity-controller (component-based RTS addon) — github.com/philipbeaucamp/godot-rts-entity-controller
- GitHub: godot-open-rts (open source RTS template) — github.com/edgency/godot-open-rts
- Reddit/SlashSkill: Scaling CharacterBody3D vs MultiMesh (per-node overhead limits) — slashskill.com/godot-4-characterbody3d-vs-multimesh
- Tower defense targeting priority (closest/weakest/strongest/farthest/random) — youtube.com/watch?v=B3W35PH4-A8
- MOBA tower aggro priority (Hero > Minion priority chain) — github.com/thedivergentai/gd-agentic-skills (godot-genre-moba skill)
- Physics query limit: `intersect_shape` hard-coded to 2048 max results — github.com/godotengine/godot/issues/83541
- `has_overlapping_bodies()` is 6.5x faster than `!get_overlapping_bodies().is_empty()` — github.com/godotengine/godot/pull/65591

---

## Recommended Pattern

**Hybrid approach: signal-based tracking + cooldown-based priority re-evaluation.**

1. **Detection:** Attach an `Area2D` (child `CollisionShape2D` with a `CircleShape2D`) to each unit. Use `body_entered`/`body_exited` signals to maintain a live `Array` of targets-in-range. This avoids per-frame physics queries.

2. **Acquisition:** On a cooldown timer (e.g. every 0.2–0.5s), scan the live array to pick the best target using the configured priority mode (closest, lowest-HP, highest-progress, etc.). Cache the chosen target.

3. **Validation:** Before attacking, check `is_instance_valid(target)` and re-check distance. If invalid or out of range, re-acquire.

4. **Scale:** For < 100 units this pattern is sufficient. For 100–500 units, centralize scanning via a manager node (avoid per-unit timers). For 500+ units, use `intersect_shape` on a central manager with staggered per-frame queries.

---

## Context: Medieval Defense Game

This game needs targeting for two actor types:

- **Military units** (Foot Soldier, Archer, Cavalry) — auto-engage enemies within detection radius (`detection_radius` in grid units from unit_stats.tres). Units have a detection Area2D set to this radius. They attack at `attack_rate` intervals.

- **Enemies** — target the nearest military unit within detection range; if none found, target the building (Base). Enemies use a larger detection Area2D.

The existing codebase uses:
- **Grid units** for all game measurements (1 unit = 64px). Conversion: `detection_radius_pixels = detection_radius_units * 64`.
- **Hitbox radius in pixels** for CollisionShape2D (NOT grid units).
- **Detection Area2D children** must set `collision_layer = 0` to avoid interfering with hitbox collision layers.
- **UnitStats Resource (.tres)** for data-driven config values.
- **Groups**: `"enemies"`, `"units"`, `"buildings"` for broad categorization.
- **Direct references** over fragile `$` paths: use `@onready var x := %UniqueName`.
- `distance_squared_to()` over `distance_to()` for performance (avoids `sqrt`).

---

## Implementation Patterns

### Pattern A: Signal-Driven Target List + Timer-Based Priority Scan

```
Structure:
Unit (CharacterBody2D)
  ├─ DetectionArea (Area2D)          # collision_layer=0, collision_mask=enemy_layer
  │   └─ CollisionShape2D (CircleShape2D, radius in pixels)
  ├─ AttackArea (Area2D)               # inner ring for melee range (optional)
  │   └─ CollisionShape2D
  └─ Script (unit.gd)
```

- `DetectionArea.body_entered` → append to `targets_in_range`
- `DetectionArea.body_exited` → remove from `targets_in_range`
- Timer (0.25s) → calls `_reacquire_target()` → selects best from `targets_in_range`
- `_physics_process` → if target exists and in attack range → attack at rate

**Pros:** No per-frame iteration of all enemies; minimal physics queries; scales well to several dozen units.

**Cons:** Signal connections per unit; stale entries if a target is freed without emitting `body_exited` (mitigate with `is_instance_valid` check on scan).

### Pattern B: Per-Frame Overlap Query

```
Structure:
Unit (CharacterBody2D)
  ├─ DetectionArea (Area2D)
  │   └─ CollisionShape2D
  └─ Script
```

- No signal connections.
- Every `_physics_process` (or on a cooldown): call `detection_area.get_overlapping_bodies()`, iterate, find best target.
- `distance_squared_to()` for sorting.

**Pros:** Simpler setup; no stale-reference issues; no signal management.

**Cons:** `get_overlapping_bodies()` allocates a new Array each call; forces iteration of all overlapping bodies every scan. 6.5x slower than `has_overlapping_bodies()` for emptiness checks. Use `has_overlapping_bodies()` first, then only call `get_overlapping_bodies()` if non-empty.

### Pattern C: Physics Shape Query (Intersect Shape)

```
Structure:
Unit (CharacterBody2D)
  └─ Script (no Area2D child needed)
```

- Use `get_world_2d().direct_space_state.intersect_shape()` with a `CircleShape2D` + `PhysicsShapeQueryParameters2D` at the unit's position.
- No child nodes required.
- Set `collision_mask` to filter for enemies only.
- `max_results` defaults to 32; hard limit is 2048.

**Pros:** No Area2D nodes (reduces node count); instant query (no signal lag); can use any arbitrary shape/position (line-of-sight checks, cone detection); can exclude self via `query.exclude = [self]`; central manager can query for all units in one pass.

**Cons:** Allocates result arrays; must be called from a node in the scene tree (needs `get_world_2d()`); slightly more code; shape transform must be synced manually each query.

### Pattern D: Centralized Manager

```
Structure:
World/GameManager (Node)
  ├─ TargetingManager (Node)
  │   ├─ EnemyGroup: Array[Enemy]
  │   └─ UnitGroup: Array[MilitaryUnit]
  ├─ Enemy 1 (CharacterBody2D)
  ├─ Enemy 2
  └─ Unit A (CharacterBody2D)
```

- A single `TargetingManager` holds references to all combatants (registered via `add_to_group("enemies")` + `get_tree().get_nodes_in_group("enemies")`).
- Runs one batch query per `n` frames, distributes target assignments to all units.
- Can use `intersect_shape` for spatial queries without per-unit Area2D nodes.
- Stagger processing: only process 1/4 of units each frame.

**Pros:** Best performance at scale; single point of truth; avoids per-node overhead; easy to profile.

**Cons:** Couples targeting to a manager; more complex setup; groups must be maintained at spawn/despawn time; removes autonomy from individual units.

---

## Code Snippet Examples

### 1. Signal-based target tracking with timer-driven priority scan

```gdscript
extends CharacterBody2D

enum TargetPriority { CLOSEST, LOWEST_HP, HIGHEST_PROGRESS, RANDOM }

@export var priority: TargetPriority = TargetPriority.CLOSEST

var current_target: Node2D
var targets_in_range: Array[Node2D] = []

@onready var detection_area: Area2D = $DetectionArea
@onready var reacquire_timer: Timer = $ReacquireTimer
@onready var stats: UnitStats = %UnitStats

func _ready():
    detection_area.body_entered.connect(_on_target_entered)
    detection_area.body_exited.connect(_on_target_exited)
    reacquire_timer.timeout.connect(_reacquire_target)
    reacquire_timer.start()

func _on_target_entered(body: Node2D):
    if not targets_in_range.has(body):
        targets_in_range.append(body)

func _on_target_exited(body: Node2D):
    targets_in_range.erase(body)
    if current_target == body:
        current_target = null

func _reacquire_target():
    if current_target and is_instance_valid(current_target):
        var dist_sq = global_position.distance_squared_to(current_target.global_position)
        if dist_sq <= stats.detection_radius_px * stats.detection_radius_px:
            return

    current_target = null
    if targets_in_range.is_empty():
        return

    # Prune invalid
    targets_in_range = targets_in_range.filter(func(t): return is_instance_valid(t))

    match priority:
        TargetPriority.CLOSEST:
            var best_dist_sq = INF
            for t in targets_in_range:
                var d = global_position.distance_squared_to(t.global_position)
                if d < best_dist_sq:
                    best_dist_sq = d
                    current_target = t
        TargetPriority.LOWEST_HP:
            var best_hp = INF
            for t in targets_in_range:
                if t.hp < best_hp:
                    best_hp = t.hp
                    current_target = t
        TargetPriority.RANDOM:
            current_target = targets_in_range.pick_random()

func target_in_attack_range() -> bool:
    if not is_instance_valid(current_target):
        return false
    var dist_sq = global_position.distance_squared_to(current_target.global_position)
    return dist_sq <= stats.attack_radius_px * stats.attack_radius_px
```

### 2. Per-frame overlap query (lightweight)

```gdscript
func _select_target() -> Node2D:
    if not detection_area.has_overlapping_bodies():
        return null

    var bodies = detection_area.get_overlapping_bodies()
    var best: Node2D = null
    var best_dist_sq = INF

    for body in bodies:
        if not is_instance_valid(body):
            continue
        var d = global_position.distance_squared_to(body.global_position)
        if d < best_dist_sq:
            best_dist_sq = d
            best = body

    return best
```

### 3. Physics shape query (no Area2D)

```gdscript
func _find_targets_in_radius(radius: float, mask: int) -> Array[Node2D]:
    var space = get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var shape = CircleShape2D.new()
    shape.radius = radius
    query.set_shape(shape)
    query.transform = Transform2D(0, global_position)
    query.collision_mask = mask
    query.exclude = [self]

    var results = space.intersect_shape(query, 32)
    var targets: Array[Node2D] = []
    for r in results:
        var collider = r.collider as Node2D
        if collider:
            targets.append(collider)
    return targets
```

### 4. Centralized manager (staggered scan)

```gdscript
class_name TargetingManager
extends Node

var enemies: Array[Node2D] = []
var units: Array[Node2D] = []
var scan_index: int = 0
var scan_fraction: float = 0.25

func _ready():
    EnemyRegistry.enemy_spawned.connect(_on_enemy_spawned)
    EnemyRegistry.enemy_despawned.connect(_on_enemy_despawned)

func _physics_process(_delta: float):
    var batch_size = ceil(units.size() * scan_fraction)
    for i in range(batch_size):
        var idx = (scan_index + i) % units.size()
        var unit = units[idx]
        if is_instance_valid(unit):
            unit.assign_target(_find_closest_enemy(unit.global_position))
    scan_index = (scan_index + batch_size) % units.size()

func _find_closest_enemy(from: Vector2) -> Node2D:
    var closest: Node2D = null
    var closest_dist_sq = INF
    for e in enemies:
        if not is_instance_valid(e):
            continue
        var d = from.distance_squared_to(e.global_position)
        if d < closest_dist_sq:
            closest_dist_sq = d
            closest = e
    return closest
```

### 5. Target validation + attack loop

```gdscript
func _physics_process(delta: float):
    if not is_instance_valid(current_target):
        _reacquire_target()
        return

    if current_target.hp <= 0:
        current_target = null
        return

    var dist = global_position.distance_to(current_target.global_position)
    var in_range = dist <= stats.attack_radius_px

    if not in_range:
        _move_towards(current_target.global_position)
    else:
        _try_attack()
```

### 6. Enemy priority: target units first, then building

```gdscript
func _reacquire_enemy_target():
    var nearest_unit: Node2D = null
    var nearest_unit_dist_sq = INF
    var nearest_building: Node2D = null
    var nearest_building_dist_sq = INF
    var detect_radius_px = detection_radius * 16

    for body in detection_area.get_overlapping_bodies():
        if not is_instance_valid(body):
            continue
        var d = global_position.distance_squared_to(body.global_position)
        if body.is_in_group("units") and d < nearest_unit_dist_sq and d <= detect_radius_px * detect_radius_px:
            nearest_unit_dist_sq = d
            nearest_unit = body
        elif body.is_in_group("buildings") and d < nearest_building_dist_sq:
            nearest_building_dist_sq = d
            nearest_building = body

    current_target = nearest_unit if nearest_unit else nearest_building
```

---

## Limitations

| Limitation | Detail | Mitigation |
|---|---|---|
| **Stale references** | `body_exited` may not fire if target is freed or removed from tree abruptly. | Always call `is_instance_valid()` before using a target reference. Prune `targets_in_range` on each scan. |
| **Signal lag** | `get_overlapping_bodies()` is updated once per physics frame, not instantly after adding/moving a body. | Acceptable for targeting (sub-frame delay is invisible). For instant checks, use `intersect_shape`. |
| **Area2D scaling cost** | 100+ Area2Ds each with overlap detection creates O(n²) pair-checking in the physics broad phase. | Use Jolt Physics (scales better). For 500+ units, switch to a centralized manager with `intersect_shape`. |
| **Node count** | Each Area2D adds a node (memory + SceneTree traversal cost). | < 100: fine. 100–500: monitor. 500+: centralize. |
| **`intersect_shape` allocation** | Returns Array[Dictionary], allocating each call. | Reuse query parameters; avoid per-frame calls for every unit. |
| **max_results limit** | Physics queries cap at 32 by default, hard limit 2048. | For large queries, iterate with higher max or use spatial partitioning. |
| **Group performance** | `get_tree().get_nodes_in_group()` iterates all nodes in group each call. | Cache results; only refresh on spawn/despawn events. |
| **Physics engine choice** | GodotPhysics broad-phase degrades with many overlapping Area2Ds. Jolt handles ~20x more bodies. | Profile with target unit count. Consider Jolt if exceeding ~50 active bodies. |

---

## Alternatives

| Approach | When to Use | Tradeoff |
|---|---|---|
| **MultiMesh + manual targeting** | 500+ near-identical units with simple movement. No physics collision needed per unit. | Lose Area2D/CollisionShape2D per unit. Write all collision logic manually. Render thousands in 1 draw call. |
| **PhysicsServer2D direct (RID-based)** | 2000+ units where you need collision shapes but minimal node overhead. | Harder to debug. No editor visualization. Memory managed manually. |
| **Event-bus based targeting** | Highly decoupled systems where units should not know about each other directly. | Adds indirection. Debugging target selection is harder (follow signal chain). |
| **Spatial hash / grid partitioning** | Open world with sparse unit distribution; avoid checking enemies on the other side of the map. | More code for grid maintenance. Best combined with centralized manager. |
| **Behavior tree** | Complex targeting logic (retreat when low HP, switch targets on priority, focus-fire). | Overhead for simple closest-target logic. Worth it if enemies have complex decision-making. |
| **Per-unit `_process` distance check** | Prototype or < 20 units. | Simplest possible. Does not scale. Use signal-based approach from the start. |
| **ShapeCast2D for line-of-sight** | Archers that need a clear shot (no obstacles between unit and target). | Only checks one direction. Combine with Area2D for 360° detection + ShapeCast2D for LoS. |

### LoS (Line of Sight) check snippet

```gdscript
func has_los_to(target: Node2D) -> bool:
    var space = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        global_position,
        target.global_position,
        collision_mask,
        [self]
    )
    var result = space.intersect_ray(query)
    return result.is_empty()
```

---

## Summary for Medieval Defense

**Use Pattern A (signal-driven + timer scan)** for most cases:

- Attach a `DetectionArea` (Area2D with `collision_layer=0`) to each unit and enemy.
- Use `body_entered`/`body_exited` to maintain `targets_in_range` arrays.
- Re-evaluate best target on a 0.25s timer using `distance_squared_to()`.
- Validate with `is_instance_valid()` before attacking.
- For enemies, prioritize units over buildings (check `is_in_group("units")` first, fallback to `is_in_group("buildings")`).
- Detection/attack radii: convert grid units to pixels (`radius_px = radius_units * 16`) for CollisionShape2D `CircleShape2D.radius`.
- Keep hitbox radii in pixels as per existing conventions.

If the game exceeds ~100 active entities, migrate to Pattern D (centralized `TargetingManager`) with staggered per-frame scanning and cached group references, to avoid per-node timer/shape overhead.
