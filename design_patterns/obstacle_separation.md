# Obstacle Separation / Push-Apart Physics in Godot 4

## References

- Craig Reynolds, "Steering Behaviors For Autonomous Characters" (1999) — origin of separation steering
- Godot 4 PhysicsBody2D docs: `move_and_collide()`, `move_and_slide()`, `get_slide_collision()`
- Godot 4 Area2D docs: `body_entered`/`body_exited` signals, `get_overlapping_bodies()`
- Godot 4 PhysicsServer2D docs: `body_test_motion()`, `body_collide_shape()`
- Godot 4 PhysicsDirectSpaceState2D docs: `intersect_shape()`, `collide_shape()`
- Godot 4 SeparationRayShape2D docs — built-in separation ray for depenetration
- KidsCanCode: Character to RigidBody Interaction (impulse-based pushing)
- CatlikeCoding: Movable Objects (CharacterBody2D-to-CharacterBody2D push)
- GDQuest: godot-steering-ai-framework (steering behaviors including separation)
- SlashSkill: Steering Behaviors — perpendicular projection anti-oscillation fix

---

## Recommended Pattern

For a top-down RTS/tower-defense game where units are `CharacterBody2D` nodes and buildings are `StaticBody2D` or `Area2D`:

**Use manual distance-based push-apart with Area2D overlap detection.** Do NOT rely on `move_and_slide()` collision response between units — it causes jittering, stuck units, and the "character body pushing character body" problem where `move_and_slide()` has undefined/non-deterministic behavior between two kinematic bodies.

### Decision Matrix

| Scenario | Approach |
|---|---|
| Unit ↔ Unit push-apart | Manual distance-based separation via `_physics_process` loop + spatial partitioning |
| Unit ↔ Building collision | `move_and_collide()` with collision response; building has `StaticBody2D` with `CollisionShape2D` |
| Building ↔ Building overlap on placement | Editor-time snap check + Area2D overlap query; no runtime physics |
| Enemy detection radius | Area2D child node (`collision_layer = 0`) with `body_entered`/`body_exited` signals |
| Enemy ↔ Unit push-apart | Same as Unit ↔ Unit (symmetric separation) |

---

## Implementation Patterns

### Pattern 1: Distance-Based Push-Apart (Primary)

Each unit has a `push_radius` (e.g., 1.5 grid units = 24px). In `_physics_process`:
1. Query nearby entities using a spatial hash/grid or `get_overlapping_bodies()` on an Area2D.
2. For each neighbor within `push_radius`, compute overlap vector and push distance.
3. Apply equal-and-opposite displacement proportional to overlap.

**Push factor rules** (who pushes whom):
- Units push units equally (mass-independent, symmetric)
- Buildings do NOT get pushed (infinite mass)
- Enemy ↔ Unit: symmetric push (same as unit↔unit)
- Static obstacles (walls): handled by `move_and_collide()`, not by push-apart

### Pattern 2: `move_and_collide()` Collision Response

Use `move_and_collide()` instead of `move_and_slide()` for primary movement. After movement:
- If collision is with a building/static body → stop, slide along normal
- If collision is with another unit → ignore (handled by Pattern 1 push-apart after movement)
- Use collision exceptions (`add_collision_exception_with()`) to prevent `move_and_collide()` from resolving unit↔unit collisions (let push-apart handle them)

### Pattern 3: Area2D Overlap Detection

Attach an Area2D child to each unit:
- `collision_layer = 0` (no physics response)
- `collision_mask` = unit layer + building layer
- Connect `body_entered`/`body_exited` to track current overlaps
- Use `get_overlapping_bodies()` in `_physics_process` to get the list of currently overlapping entities for push-apart computation

**Note:** `get_overlapping_bodies()` updates once per physics frame, not immediately. Signals (`body_entered`/`body_exited`) fire after the physics step. This one-frame delay is acceptable for push-apart since the correction happens the same physics frame via position adjustment.

### Pattern 4: Separation Steering (Reynolds)

For units navigating toward a target while avoiding each other:
- Compute a repulsion vector from each neighbor within separation radius
- Weight by inverse distance (closer = stronger push)
- Sum all repulsion vectors, normalize, apply as a steering force
- Blend with seek force toward target destination
- Optional: Project avoidance onto perpendicular of desired direction to prevent oscillation (see Anti-Oscillation below)

### Pattern 5: PhysicsServer2D Low-Level (Advanced)

For full control without scene tree overhead:
- Use `PhysicsServer2D.body_create()` with `BODY_MODE_KINEMATIC`
- Use `PhysicsDirectSpaceState2D.intersect_shape()` for overlap queries
- Use `PhysicsServer2D.body_test_motion()` to test movement before committing
- Manually apply position offsets for separation
- Trade-off: more code, but better performance for hundreds of units

---

## Code Snippet Examples

### 1. Distance-Based Push-Apart (Unit ↔ Unit)

```gdscript
extends CharacterBody2D

@export var push_radius: float = 24.0  # 1.5 grid units
@export var push_factor: float = 0.5

func _physics_process(delta: float) -> void:
    # 1. Move using move_and_collide (with unit exceptions handled separately)
    var collision := move_and_collide(velocity * delta)

    # 2. Push-apart against other units
    _separate_from_units()

func _separate_from_units() -> void:
    var space_state := get_world_2d().direct_space_state
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = CircleShape2D.new()
    query.shape.radius = push_radius
    query.transform = Transform2D(0, global_position)
    query.collide_with_bodies = true
    query.collide_with_areas = false
    query.exclude = [get_rid()]

    var results := space_state.intersect_shape(query)
    var push := Vector2.ZERO
    for result in results:
        var other := result.collider
        if other == self or not other is CharacterBody2D:
            continue
        var delta_vec := global_position - other.global_position
        var dist := delta_vec.length()
        if dist < 0.001:
            delta_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1))
            dist = 0.001
        var overlap := push_radius - dist
        if overlap > 0:
            push += delta_vec.normalized() * overlap * push_factor

    global_position += push
```

### 2. Area2D-Based Overlap Detection for Push-Apart

```gdscript
extends CharacterBody2D

@onready var detection_area: Area2D = %DetectionArea
@export var push_radius: float = 24.0
@export var push_strength: float = 1.0

func _physics_process(delta: float) -> void:
    move_and_collide(velocity * delta)
    _push_apart()

func _push_apart() -> void:
    var push := Vector2.ZERO
    for body in detection_area.get_overlapping_bodies():
        if body == self:
            continue
        var delta_vec := global_position - body.global_position
        var dist := delta_vec.length()
        if dist < 0.001:
            delta_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1))
            dist = 0.001
        var overlap := push_radius - dist
        if overlap > 0:
            push += delta_vec.normalized() * overlap * push_strength
    global_position += push
```

### 3. Symmetric Push-Apart (equal displacement)

```gdscript
static func resolve_unit_overlap(a: CharacterBody2D, b: CharacterBody2D,
        push_radius: float, push_strength: float) -> void:
    var delta_vec := a.global_position - b.global_position
    var dist := delta_vec.length()
    if dist < 0.001:
        delta_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1))
        dist = 0.001
    var overlap := push_radius - dist
    if overlap <= 0:
        return
    var direction := delta_vec.normalized()
    var offset := direction * overlap * push_strength * 0.5
    a.global_position += offset
    b.global_position -= offset
```

### 4. Building Push-Apart (unit pushed away, building stays)

```gdscript
extends CharacterBody2D

@export var building_push_radius: float = 32.0  # 2 grid units
@export var building_push_strength: float = 1.0

func _physics_process(delta: float) -> void:
    move_and_collide(velocity * delta)
    _push_from_buildings()

func _push_from_buildings() -> void:
    var space_state := get_world_2d().direct_space_state
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = CircleShape2D.new()
    query.shape.radius = building_push_radius
    query.transform = Transform2D(0, global_position)
    query.collide_with_bodies = true
    query.collide_with_areas = false

    var push := Vector2.ZERO
    for result in space_state.intersect_shape(query):
        var other := result.collider
        if other == self or other is CharacterBody2D:
            continue
        var delta_vec := global_position - other.global_position
        var dist := delta_vec.length()
        if dist < 0.001:
            continue
        var overlap := building_push_radius - dist
        if overlap > 0:
            push += delta_vec.normalized() * overlap * building_push_strength
    global_position += push
```

### 5. Separation Steering (Reynolds style)

```gdscript
extends CharacterBody2D

@export var separation_radius: float = 32.0
@export var separation_weight: float = 4.0
@export var max_speed: float = 100.0

var target_position: Vector2
var steering_velocity: Vector2

func _physics_process(delta: float) -> void:
    var seek_force := _seek(target_position)
    var separation_force := _separation()
    var acceleration := seek_force + separation_force * separation_weight
    steering_velocity += acceleration * delta
    steering_velocity = steering_velocity.limit_length(max_speed)
    velocity = steering_velocity
    move_and_slide()

func _seek(target: Vector2) -> Vector2:
    var desired := (target - global_position).normalized() * max_speed
    return desired - steering_velocity

func _separation() -> Vector2:
    var steer := Vector2.ZERO
    var neighbors := _get_nearby_units(separation_radius)
    var count := 0
    for other in neighbors:
        var delta_vec := global_position - other.global_position
        var dist := delta_vec.length()
        if dist < 0.001:
            continue
        steer += delta_vec.normalized() / dist
        count += 1
    if count > 0:
        steer /= count
        steer = steer.normalized() * max_speed
        steer -= steering_velocity
        steer = steer.limit_length(max_speed)
    return steer

func _get_nearby_units(radius: float) -> Array:
    var space_state := get_world_2d().direct_space_state
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = CircleShape2D.new()
    query.shape.radius = radius
    query.transform = Transform2D(0, global_position)
    query.collide_with_bodies = true
    var results := space_state.intersect_shape(query)
    var units: Array = []
    for r in results:
        if r.collider is CharacterBody2D and r.collider != self:
            units.append(r.collider)
    return units
```

### 6. Anti-Oscillation Perpendicular Projection

```gdscript
# Project avoidance onto perpendicular of desired direction
# Prevents tug-of-war oscillation between seek and separation
func _apply_avoidance(desired_dir: Vector2, avoidance: Vector2,
        strength: float, speed: float) -> Vector2:
    var nx := desired_dir.normalized()
    var perp := Vector2(-nx.y, nx.x)  # perpendicular
    var side_dot := avoidance.dot(perp)
    var steer := perp * side_dot
    nx += steer * strength / maxf(speed, 1.0)
    var mag := nx.length()
    if mag > 0.01:
        nx /= mag
    return nx
```

### 7. Building Hitbox Radius Accessor Pattern

```gdscript
extends StaticBody2D

@export var hitbox_radius: float = 16.0

func get_hitbox_radius() -> float:
    return hitbox_radius
```

---

## Limitations

| Issue | Detail |
|---|---|
| One-frame delay in Area2D | `get_overlapping_bodies()` is stale until next physics step; acceptable for push-apart but not for instant kill/trigger |
| CharacterBody2D ↔ CharacterBody2D collision | `move_and_slide()` / `move_and_collide()` behavior between two kinematic bodies is undefined — they may push each other, push only one way, or get stuck. Always use collision exceptions + manual push-apart |
| Overlapping units at spawn | Units placed on the same tile need an initial burst displacement; the random-direction fallback handles this |
| Many-body pileups | Multiple overlapping units can cause oscillation or chain displacement. Cap maximum push displacement per frame and iterate push-apart 2-3 times per physics step |
| Building corner pinning | A unit pushed into a building corner may get stuck between building push and unit push. Resolve by giving building push higher priority and ensuring `move_and_collide()` handles wall sliding |
| Performance at scale | `intersect_shape()` on every unit every frame is O(n*m). Use a spatial grid or `RID`-based broad phase for 100+ units |
| SeparationRayShape2D | Built-in separation ray is intended for stair/ground separation, not general push-apart between entities |

---

## Alternatives

| Alternative | Pros | Cons | Use When |
|---|---|---|---|
| RigidBody2D with physics forces | Built-in collision response, push-apart is automatic | Unpredictable for RTS, hard to control exact unit positioning, can jitter | Physics-puzzle games, games where realistic collision response is desired |
| Full PhysicsServer2D with custom callbacks | Maximum performance, no scene tree overhead | Much more code, no editor visualization, steep learning curve | 500+ units, need maximum control, building custom physics |
| Skip collision entirely, use only pathfinding in grid | Simple, no push-apart needed | Units overlap visually, no physical-feeling interaction, immersion-breaking | Abstract/iconic games where exact positioning doesn't matter |
| Composite rigid body group | One physics body for a squad of units | Complex to implement, limited flexibility per unit | Games where units always stay in formation |
| NavigationAgent2D + avoidance radius | Built-in RVO-like avoidance via NavigationServer2D | Avoidance radius != push-apart; units can still overlap at destination; no building push | When only navigation-time separation is needed (arrival overlap still requires separate handling) |
| Jolt Physics (Godot 4) | Better penetration resolution, Baumgarte stabilization | Still not ideal for kinematic↔kinematic; adds dependency | 3D projects, or if upgrading physics backend is already planned |
