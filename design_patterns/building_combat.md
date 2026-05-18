# Building / Tower Combat in Godot 4

## References

- **quiver-dev/tower-defense-godot4** (GitHub, 85★): 2D tile-based TD template for Godot 4. Tower placement, weapon types, projectiles, FSM pattern, collision layers (`infantry`, `turret`, `projectile`, `objective`). Superseded by Outpost Assault course repo.
- **ape1121/Godot-4-Tower-Defense-Template** (GitHub, 60★): 4 demo turrets (gatling, flamethrower, ray, explosive), drag-drop placement, upgrade/sell, data-driven config via autoload dictionary.
- **AzyrGames/GodotProjectileEngine** (GitHub): Modular projectile engine with object pooling, template resources, spawner/composer/timing components.
- **quinnvoker/qurobullet**: Bullet-hell pooling server for Godot (C++ module). Pre-allocated bullet objects (not nodes), `BulletServer` + `BulletSpawner` + `BulletType` resource, collision signals.
- **thedivergentai/gd-agentic-skills**: Tower defense skill blueprint — states (Idle/AcquireTarget/Attack/Cooldown), 5 targeting priorities (First/Last/Strongest/Weakest/Closest), projectile prediction formula.
- **GDQuest / Learn 2D Gamedev GD4 (Tower Defense module)**: Weapon stats resource, upgrade database autoload, `Resource`-based turret stats, AStar pathfinding, coin collection.
- **KidsCanCode / Godot Recipes**: `Area2D` range detection, `look_at()` rotation, projectile spawning via `Marker2D`, rigid body torque rotation.
- **Wayline.io TD tutorial**: Area2D range detection, `get_tree().get_nodes_in_group("enemies")` targeting, fire rate timer, projectile `KinematicBody2D` with `move_and_collide()`.
- **Game Dev Journey**: Furthest-progress targeting, range check, PathFollow3D progress comparison.
- **Wide Arch Shark (YouTube)**: Turret state machine (pending/acquiring/attacking), first-vs-last array indexing for targeting, enemy-disappeared-during-acquire handling.
- **Lio Goes Indie (YouTube)**: Targeting modes enum (closest/farthest/weakest/strongest/random), OptionButton UI switching, `distance_to()` vs health comparison.
- **Game Development Center (YouTube)**: Range indicator sprite tween, tower scene inheritance hierarchy, progress-based tracking.
- **radaucg/game-mechanics-optimizations**: Object pooling pattern — pre-allocate, activate/deactivate via show/hide + set_process(false). O(1) retrieval. Bullet pools 500-2000.

---

## Recommended Pattern

### Scene Structure

```
Tower (Node2D)
  Sprite2D (base / body)
  Sprite2D (turret / barrel — rotates independently)
  Marker2D (muzzle / projectile spawn point)
  Area2D (detection_range)
    CollisionShape2D (CircleShape2D, radius in pixels)
  Timer (attack_cooldown)
```

- Detection area uses `body_entered` / `body_exited` signals to maintain `targets_in_range: Array[Node2D]`
- Set `collision_layer = 0` on detection Area2D to avoid physics interference
- Use typed layers: `enemies=1`, `towers=2`, `projectiles=3` in Project Settings

### State Machine

4 states, best implemented as enum + `match`:

1. **Idle** — No targets in range. Turret may face default direction or slowly rotate.
2. **AcquireTarget** — Find best target from `targets_in_range` array based on priority. Transition to Attack.
3. **Attack** — Rotate turret toward target. When aimed (or immediately for instant attacks), fire projectile / apply damage. Start cooldown timer → Cooldown.
4. **Cooldown** — Wait for timer. Re-check target validity each frame. On timer done → if target still valid and in range → Attack, else → AcquireTarget.

If target dies or leaves range during any state, immediately transition to AcquireTarget.

### Targeting System

Maintain `targets_in_range` array via Area2D signals:
- `body_entered`: `if body.is_in_group("enemies"): targets_in_range.append(body)`
- `body_exited`: `if body == current_target: current_target = null; targets_in_range.erase(body)`

Targeting priorities (configurable per tower via enum):
- `CLOSEST` — min distance to tower
- `FURTHEST` — max distance to tower
- `FIRST` — first element in array (oldest in range)
- `LAST` — last element in array (newest in range)
- `WEAKEST` — min HP
- `STRONGEST` — max HP
- `FURTHEST_PROGRESS` — enemy closest to goal (most common TD default)

Re-evaluate target when: current target dies, leaves range, or a new enemy enters range with higher priority.

### Projectile Patterns

- **Single target (homing or straight)**: Instance projectile at Marker2D, set direction toward target, move each frame, destroy on hit.
- **AoE splash**: Spawn projectile that on impact creates an Area2D explosion, damaging all enemies in radius.
- **Multi-shot**: Spawn N projectiles simultaneously, each toward same target (spread pattern) or toward N closest targets.
- **Hitscan (instant)**: RayCast2D from tower to target, apply damage immediately with visual tracer. No projectile node needed.
- **Piercing**: Projectile passes through enemies, damaging each, removed after N hits or max distance.

### Rotation / Turn Rate

```gdscript
var rotation_speed: float = TAU  # radians per second (full circle = TAU)

func _rotate_turret(target_pos: Vector2, delta: float) -> void:
    var dir: Vector2 = (target_pos - global_position).normalized()
    var target_angle: float = dir.angle()
    var angle_diff: float = angle_difference($Turret.rotation, target_angle)
    var step: float = rotation_speed * delta
    if abs(angle_diff) < step:
        $Turret.rotation = target_angle
    else:
        $Turret.rotation += sign(angle_diff) * step
```

- Use `angle_difference()` for shortest-path rotation (avoids TAU wrapping issues)
- Fast towers (high turn rate) track instantly; slow towers (cannons, artillery) have visible delay
- Can optionally `look_at()` for instant rotation on acquire, then smooth during attack

### Range Visualization

**Placement preview**: Sprite2D child with circle texture, tween scale to match tower range on hover. Disappear on placement.
```gdscript
# RangePreview.gd (Sprite2D child)
func appear(range_radius_px: float) -> void:
    var scale_ratio: float = (range_radius_px * 2.0) / texture.get_width()
    var tween: Tween = create_tween()
    tween.tween_property(self, "scale", Vector2(scale_ratio, scale_ratio), 0.15)
    tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0.3), 0.15)
```

**In-game**: Optionally draw range circle via `_draw()` with `draw_arc()` when tower is selected. Clear on deselect.

### Upgrade System

Use `Resource`-based stats (not hardcoded):

```gdscript
# tower_stats.gd
class_name TowerStats extends Resource
@export var damage: float = 10.0
@export var fire_rate: float = 1.0  # attacks per second
@export var range_radius: float = 128.0  # pixels
@export var rotation_speed: float = TAU
@export var projectile_speed: float = 400.0
```

Upgrade progression stored in an autoload dictionary or JSON:
```gdscript
# UpgradeDatabase.gd (autoload)
const UPGRADES: Dictionary = {
    "arrow_tower": [
        { "cost": 100, "damage_bonus": 5, "fire_rate_bonus": 0.1, "range_bonus": 16 },
        { "cost": 200, "damage_bonus": 10, "fire_rate_bonus": 0.15, "range_bonus": 24 },
    ]
}
```

When upgrading: apply bonuses to a `TowerStats` resource instance, or use a multiplier formula:
- `new_damage = base_damage * (1.0 + level * 0.25)`
- `new_range = base_range * (1.0 + level * 0.1)`

### De-targeting / Re-acquisition

- If `current_target` is `null`, `not is_instance_valid(current_target)`, or outside detection range → clear target and re-acquire next frame
- On re-acquisition, re-run priority sort — target priority can shift if new enemies entered range
- Consider a "target lock" period: don't re-evaluate for N seconds after acquiring to prevent flickering between equal-priority targets
- MOBA-style priority stack: check multiple conditions in order (e.g., attacking-ally > minion > hero > closest)

### Object Pooling for Projectiles

```gdscript
class_name ProjectilePool extends Node

var _pool: Array[Area2D] = []
var _prefab: PackedScene

func init(prefab: PackedScene, size: int = 100) -> void:
    _prefab = prefab
    for i in size:
        var p: Area2D = prefab.instantiate()
        p.visible = false
        p.set_process(false)
        p.set_physics_process(false)
        (p as CollisionObject2D).set_collision_layer_value(3, false)
        add_child(p)
        _pool.append(p)

func get_projectile() -> Area2D:
    if _pool.is_empty():
        return _prefab.instantiate()  # grow on demand
    var p: Area2D = _pool.pop_back()
    p.visible = true
    p.set_process(true)
    p.set_physics_process(true)
    (p as CollisionObject2D).set_collision_layer_value(3, true)
    return p

func return_projectile(p: Area2D) -> void:
    p.visible = false
    p.set_process(false)
    p.set_physics_process(false)
    (p as CollisionObject2D).set_collision_layer_value(3, false)
    _pool.append(p)
```

Typical pool size: 200-500 for tower defense projectiles. Grow by 1.5x if exhausted.

---

## Implementation Patterns

### Detection Radius Setup

Add Area2D child in `_ready()`:
```gdscript
@onready var detection_area: Area2D = $DetectionArea
@onready var collision_shape: CollisionShape2D = $DetectionArea/CollisionShape2D

func _update_detection_radius(pixels: float) -> void:
    (collision_shape.shape as CircleShape2D).radius = pixels
```

### Targeting Enum + Match

```gdscript
enum TargetingPriority { CLOSEST, FURTHEST, WEAKEST, STRONGEST, FIRST, LAST, FURTHEST_PROGRESS }
@export var targeting_priority: TargetingPriority = TargetingPriority.CLOSEST

func _acquire_target() -> Node2D:
    var best: Node2D = null
    var best_val: float = INF if targeting_priority in [CLOSEST, WEAKEST, FIRST] else -INF

    for e in targets_in_range:
        if not is_instance_valid(e):
            continue
        var val: float
        match targeting_priority:
            CLOSEST:           val = global_position.distance_squared_to(e.global_position)
            FURTHEST:          val = -global_position.distance_squared_to(e.global_position)
            WEAKEST:           val = e.hp
            STRONGEST:         val = -e.hp
            FIRST:             val = targets_in_range.find(e)
            LAST:              val = -targets_in_range.find(e)
            FURTHEST_PROGRESS: val = -e.progress  # negative so smaller = better

        var better: bool = val < best_val if targeting_priority in [CLOSEST, WEAKEST, FIRST] else val > best_val
        if better:
            best = e
            best_val = val
    return best
```

### Projectile Spawning

```gdscript
@export var projectile_scene: PackedScene
@onready var muzzle: Marker2D = %Muzzle

func _fire() -> void:
    if not is_instance_valid(current_target):
        return
    var p: Area2D = projectile_scene.instantiate()
    get_tree().current_scene.add_child(p)
    p.global_transform = muzzle.global_transform
    p.set_direction((current_target.global_position - muzzle.global_position).normalized())
    p.damage = stats.damage
```

Or with pool:
```gdscript
var p: Area2D = projectile_pool.get_projectile()
p.global_transform = muzzle.global_transform
p.set_direction(...)
```

### AoE Splash

```gdscript
# On projectile impact
func _on_hit(position: Vector2) -> void:
    var explosion: Area2D = explosion_scene.instantiate()
    explosion.global_position = position
    get_tree().current_scene.add_child(explosion)
    # Explosion Area2D applies damage to all overlapping bodies
    for body in explosion.get_overlapping_bodies():
        if body.is_in_group("enemies"):
            body.take_damage(aoe_damage)
    explosion.queue_free()
```

### Homing Projectile

```gdscript
extends Area2D

var speed: float = 400.0
var homing_strength: float = 5.0  # higher = tighter tracking
var target: Node2D
var damage: float

func _physics_process(delta: float) -> void:
    if not is_instance_valid(target):
        queue_free()
        return
    var dir: Vector2 = (target.global_position - global_position).normalized()
    var velocity: Vector2 = dir * speed
    # Optional: apply homing curve
    # velocity = velocity.lerp(dir * speed, homing_strength * delta)
    global_position += velocity * delta
```

---

## Limitations

- `get_overlapping_bodies()` on detection Area2D won't trigger `body_entered` for newly spawned enemies already inside radius — must manually scan on spawn
- `is_instance_valid()` is required on every target reference because `queue_free()` doesn't null the reference
- Node pooling for projectiles adds complexity: must manually reset all state (position, rotation, collision layer, process mode, visibility) on return
- `angle_difference()` + `sign()` rotation can oscillate at very low turn rates near the target angle — add dead zone check
- Area2D detection radius changes not applied until collision shape is updated via `(shape as CircleShape2D).radius = new_radius`
- Large numbers of towers each with their own detection Area2D can impact physics performance — use collision layer masks aggressively, consider spatial hashing for 50+ towers

---

## Alternatives

| Approach | Pros | Cons |
|---|---|---|
| **Area2D signals** (`body_entered`/`exited`) | Automatic, event-driven, no per-frame scan | Manual array management, missed spawn-in-range edge case |
| **`get_overlapping_bodies()` per frame** | Always accurate, simpler code | O(n) per tower per frame, worse with many towers |
| **Group scan** (`get_tree().get_nodes_in_group("enemies")`) | No Area2D needed, works globally | O(all enemies) per tower per frame, no range check built-in |
| **Hitscan (RayCast2D)** | No projectiles, instant, no pooling | Less visually satisfying, no dodge chance, no splash variants |
| **Projectile nodes** (instantiate/free) | Simple, no pool management | GC spikes, stutter under high fire rates |
| **RenderingServer / MultiMesh** | Best performance for 1000s of projectiles | C++-level, no per-projectile collision, complex setup |
| **Resource-based stats** | Save/load ready, editor-friendly, data-driven | More files, indirection |
| **Autoload dictionary stats** | Simple, centralized | No editor preview, harder to refactor |
| **Tower with child turret** | Turret can rotate independently | Extra transform math for spawn points |
| **Tower as single node** | Simpler scene tree | Cannot rotate barrel without rotating entire tower |
