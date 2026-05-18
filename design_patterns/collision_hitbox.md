# Collision Hitbox

## References

- Godot 4 Area2D documentation: https://docs.godotengine.org/en/4.4/classes/class_area2d.html
- Godot 4 Using Area2D tutorial: https://docs.godotengine.org/en/stable/tutorials/physics/using_area_2d.html
- Godot 4 Collision Shapes (2D): https://docs.godotengine.org/en/4.5/tutorials/physics/collision_shapes_2d.html
- GDQuest hitbox/hurtbox demo: https://github.com/gdquest-demos/godot-4-hitbox-hurtbox
- Godot Health/Hitbox/Hurtbox plugin (cluttered-code): https://github.com/cluttered-code/godot-health-hitbox-hurtbox
- Godot Forum — collision layer/mask best practices: https://forum.godotengine.org/t/whats-the-best-practice-for-setting-up-collision-layers-masks/121503
- UhiyamaLab — organizing collision detection with layers and masks: https://uhiyama-lab.com/en/notes/godot/collision-layers-masks-organization/
- KidsCanCode — RTS drag-select with physics queries: https://kidscancode.org/godot_recipes/4.x/input/multi_unit_select/index.html
- Godot 4 Tower Defense Template (LucasFerguson): https://github.com/LucasFerguson/Godot-4-Tower-Defense-Template

## Recommended Pattern

### Hitbox/Hurtbox (Area2D-based)

Use **separate Area2D children** for hit detection rather than relying on the physics body itself. Each entity has up to three Area2D child nodes:

1. **Hurtbox** (Area2D + CollisionShape2D) — child of the entity. Represents the area that can receive damage. Set `collision_layer` to the entity's layer (e.g., `enemies`), `collision_mask` to `0` (does not actively scan). `monitorable = true`, `monitoring = false`. The hurtbox is *passive* — it is detected by others but does not detect.

2. **Hitbox** (Area2D + CollisionShape2D) — child of a weapon/projectile/attack. Represents the area that deals damage. Set `collision_layer` to `hitboxes`, `collision_mask` to the hurtbox layer it should hit (e.g., `enemies`). Activate only during attack frames via `monitoring`.

3. **Detection Zone** (Area2D + CollisionShape2D) — child of units/enemies. A circular area used for sensing (aggro, target acquisition). Set `collision_layer` to `0`, `collision_mask` to the layers it should detect (e.g., `enemies`, `buildings`). `monitoring = true`, `monitorable = false`.

| Component | Layer | Mask | monitoring | monitorable |
|-----------|-------|------|------------|-------------|
| Hurtbox | its team layer | 0 | false | true |
| Hitbox | hitboxes | target team layer | true (during attack) | false |
| Detection | 0 | layers to detect | true | false |

**Why separate nodes:**
- Decouples movement physics (CharacterBody2D) from overlap detection
- Allows precise control over when an attack can connect (toggle `monitoring`)
- Enables different shapes per purpose (circle for detection, rectangle for sword swing)
- Follows Godot 4's unidirectional detection model: only the active scanner pays the cost

### Collision Layer Organization (TD Game)

Name layers in `Project Settings > Layer Names > 2D Physics`:

| Bit | Layer Name | Used By |
|-----|-----------|---------|
| 1 | `world` | TileMap, walls, obstacles (StaticBody2D) |
| 2 | `units` | Friendly units (CharacterBody2D hurtbox) |
| 3 | `enemies` | Enemy units (CharacterBody2D hurtbox) |
| 4 | `buildings` | Town center, towers (StaticBody2D hurtbox) |
| 5 | `hitboxes` | All attack Area2Ds |
| 6 | `detection` | Detection/aggro zones |
| 7 | `projectiles` | Arrow, bullet Area2Ds |

**Rule of thumb:** An object's `collision_layer` says "I am on this team." Its `collision_mask` says "I want to interact with these teams." In Godot 4, detection is unidirectional — the object with the mask does the scanning.

### Shape Selection

| Shape | Relative Performance | Best For |
|-------|---------------------|----------|
| CircleShape2D | Fastest | Detection radius, projectile hitbox, round entity hurtbox |
| RectangleShape2D | Fast | Sword swing, building footprint, drag-select box |
| CapsuleShape2D | Fast (slightly slower than rect) | Elongated character hurtbox, avoids edge-catching |
| ConvexPolygonShape2D | Slower | Irregular obstacles, precise hitboxes |
| ConcavePolygonShape2D | Slowest (StaticBody only) | Level geometry, tile collision |

**Always prefer primitive shapes (circle, rectangle, capsule) over polygon shapes for dynamic objects.** CircleShape2D is documented as the fastest shape for collision checking.

## Implementation Patterns

### Pattern A: CharacterBody2D + Hurtbox + Detection Zone

Entity scene tree structure:

```
CharacterBody2D (movement, physics)
├── CollisionShape2D (physics body shape, blocks movement)
├── Sprite2D
├── Hurtbox (Area2D) — receives damage
│   └── CollisionShape2D (same or similar shape)
└── DetectionZone (Area2D) — senses enemies/buildings
    └── CollisionShape2D (large circle)
```

- CharacterBody2D handles `move_and_slide()` for movement and wall collision
- Hurtbox Area2D receives `area_entered` from enemy Hitboxes
- DetectionZone Area2D scans for targets via `body_entered` / `area_entered`

### Pattern B: Projectile with Hitbox

```
Area2D (projectile movement)
├── Sprite2D
└── Hitbox (Area2D) — deals damage
    └── CollisionShape2D (circle, small)
```

- The projectile itself is an Area2D (not a physics body) because it does not need to push things
- Hitbox `collision_mask` targets enemy hurtbox layer
- On `area_entered`, apply damage and queue_free()

### Pattern C: Weapon Swing Hitbox (transient)

```
Node2D (weapon)
├── Sprite2D
└── Hitbox (Area2D)
    └── CollisionShape2D (rectangle, oriented with swing)
```

- Enabled only during active attack frames via `hitbox.monitoring = true`
- Use `AnimationPlayer` callbacks or signals to toggle
- `collision_mask` targets hurtbox layers

### Pattern D: Building with Hurtbox + Detection

```
StaticBody2D (building)
├── CollisionShape2D (physics block)
├── Sprite2D
├── Hurtbox (Area2D) — receives damage
│   └── CollisionShape2D (rectangle or circle)
└── DetectionZone (Area2D) — turret targeting
    └── CollisionShape2D (large circle)
```

## Code Snippet Examples

### Hurtbox script (attached to Area2D)

```gdscript
class_name Hurtbox extends Area2D

@export var health_component: Node

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if not area is Hitbox:
        return
    var hitbox := area as Hitbox
    if health_component and health_component.has_method("take_damage"):
        health_component.take_damage(hitbox.damage)
```

### Hitbox script (attached to weapon/projectile Area2D)

```gdscript
class_name Hitbox extends Area2D

@export var damage: float = 10.0
@export var one_time: bool = true
var _already_hit: Array[Node] = []

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    var hurtbox := area as Hurtbox
    if not hurtbox:
        return
    if one_time and hurtbox in _already_hit:
        return
    if one_time:
        _already_hit.append(hurtbox)
```

### Programmatic Area2D creation (for runtime-spawned hitboxes)

```gdscript
func create_hitbox(position: Vector2, radius: float, damage: float) -> void:
    var area := Area2D.new()
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = radius
    shape.shape = circle
    area.add_child(shape)
    area.collision_layer = 0
    area.collision_mask = 4  # enemies layer
    area.global_position = position
    area.monitoring = true
    area.monitorable = false
    add_child(area)
```

### Physics query for detection (alternative to Area2D)

For one-shot checks or drag selection, use `PhysicsDirectSpaceState2D`:

```gdscript
func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
    var space := get_world_2d().direct_space_state
    var query := PhysicsShapeQueryParameters2D.new()
    var circle := CircleShape2D.new()
    circle.radius = radius
    query.shape = circle
    query.transform = Transform2D(0, center)
    query.collision_mask = 4  # enemies layer
    var results: Array[Dictionary] = space.intersect_shape(query)
    return results.map(func(r): return r.collider as Node2D)
```

## Limitations

1. **Per-node overhead at scale.** Each Area2D + CollisionShape2D pair adds CPU cost. At ~300+ entities with 3 collision shapes each, Godot's broadphase generates enough collision pairs to cause frame drops. Disabling unused collision shapes provides measurable improvement (~20 FPS per shape).

2. **`PhysicsDirectSpaceState2D.intersect_shape`** has a hardcoded limit on query results when many overlapping Area2Ds exist nearby (tracked in Godot issue #94367). Use signals for reliable overlap detection at scale.

3. **One-way collision shape does not work on Area2D children.** The `one_way_collision` property only applies to PhysicsBody2D, not Area2D.

4. **Coordinate system confusion.** Hitbox/Hurtbox positions are relative to their parent. When attached to a weapon that rotates with the character, the hitbox must be a child of the rotating sprite, not of the root CharacterBody2D.

5. **Signal timing.** `area_entered` / `body_entered` fire during the physics step. Do not modify the scene tree (queue_free) inside a signal handler connected to a large number of overlapping areas without caution — use `call_deferred` or a pending-delete pattern.

6. **Area2D does not respond to physics forces.** Use CharacterBody2D for entities that need to be blocked by walls or pushed. Use Area2D for purely detection-based entities (projectiles, triggers).

7. **Godot 4 unidirectional detection.** In Godot 4, detection is one-way. Only the object with the `collision_mask` actively scans. Both sides must have matching layer/mask if both need to detect each other. This is different from Godot 3 where detection was bidirectional by default.

## Alternatives

| Alternative | When to Use | Trade-off |
|------------|-------------|-----------|
| Single CharacterBody2D with `move_and_slide()` and `get_slide_collision()` | Simple games where touching == damage | No separate hitbox control; collision detection is tied to physics movement |
| CollisionPolygon2D instead of CollisionShape2D | Need pixel-precise irregular shapes | More expensive; use primitives whenever possible |
| `PhysicsDirectSpaceState2D.intersect_shape()` instead of persistent Area2D | One-shot checks (e.g., drag-select, line-of-sight) | No continuous monitoring; must call every frame; hit 4096-result limit in some cases |
| RayCast2D instead of large detection Area2D | Line-of-sight, targeting the nearest enemy in a direction | Single point check only, no area overlap |
| MultiMesh2D + manual spatial queries (no per-node physics) | 500+ entities (bullet-heaven / massive RTS) | No built-in collision; must implement spatial partitioning and hit testing manually; harder to debug |
| Servers API (RenderingServer + PhysicsServer2D) | 10,000+ entities | Maximum performance but zero editor tooling; all positions managed via packed arrays |
