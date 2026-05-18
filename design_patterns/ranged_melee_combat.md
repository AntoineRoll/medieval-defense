# Ranged vs Melee Combat Behavior in Godot 4

## References

- **Kiting & Range Dynamics (AoE2)** — Wayward Strategy: attack wind-up, cooldown, snaring, target locking
- **Steering Behaviors** — Craig Reynolds (Seek, Flee, Pursuit, Evasion); konbel/steering-behaviors-godot-4 (GitHub); GDQuest/godot-steering-ai-framework
- **Godot 4 RayCasting** — `PhysicsRayQueryParameters2D.create()`, `intersect_ray()`; docs.godotengine.org; kidsCanCode raycast recipes
- **Object Pooling** — UhiyamaLab "Complete Guide to Object Pooling"; raduacg/game-mechanics-optimizations (GitHub); GodotPerfBullets C++ plugin; AzyrGames/GodotProjectileEngine
- **Godot RTS Combat** — philipbeaucamp/godot-rts-entity-controller (GitHub, SC2-inspired); gameidea.org RTS Godot tutorial
- **Follower AI (maintain distance)** — studyraid.com (idle/follow radius pattern); kidsCanCode changing_behaviors
- **Perpendicular Projection (anti-oscillation)** — slashskill.com steering behaviors for avoidance
- **AoE2 Melee Attack Timing** — aoezone.net (reload time, animation duration, fire delay, TTK calculations)
- **Vision/LoS** — d-bucur/godot-vision-cone (GitHub); GDQuest raycasting vision tutorial; makeuseof.com RayCast2D line-of-sight

---

## Recommended Pattern

### Architecture: Shared Combat State Machine

Both ranged and melee units share a common state machine. The `current_state` variable determines behavior every physics tick. The distinction between ranged and melee lives entirely in the **attack behavior** and **movement during engagement**.

```
enum UnitState { IDLE, MOVE, CHASE, ATTACK, FLEE, DEAD }
```

| State | Melee | Ranged |
|-------|-------|--------|
| CHASE | Move directly toward target, full speed | Move to preferred range, stop at max_attack_range - buffer |
| ATTACK | Stop moving, play melee animation, apply damage via Area2D/RayCast on contact frame | Stop (or slow), fire projectile/hitscan, may begin kiting |
| FLEE | N/A (melee closes distance) | Move away from target while maintaining facing to fire |

### Unit Data (Resource-based)

```gdscript
class_name UnitCombatStats extends Resource

@export var attack_range: float         # grid units
@export var attack_damage: int
@export var attack_cooldown: float      # seconds between attacks
@export var attack_windup: float        # delay before damage frame
@export var projectile_scene: PackedScene  # null for melee
@export var projectile_speed: float
@export var preferred_range: float      # ranged only: distance to maintain
@export var detection_radius: float     # engage radius
```

---

## Implementation Patterns

### 1. Ranged Unit Behavior (Maintain Distance / Kite)

**Core loop per physics frame:**

1. Calculate distance to target.
2. If target outside attack range + buffer → move toward target to close gap.
3. If target inside preferred_range → move away from target (kite/flee).
4. If target within attack_range AND cooldown elapsed → fire projectile.
5. While kiting, face target (flip sprite or rotate).

```
func _ranged_behavior(target: Node2D, delta: float) -> void:
    var dist = global_position.distance_to(target.global_position)
    var dir_to_target = global_position.direction_to(target.global_position)
    
    if dist > attack_range * 1.1:
        velocity = dir_to_target * move_speed       # approach
    elif dist < preferred_range:
        velocity = -dir_to_target * move_speed       # retreat / kite
    else:
        velocity = velocity.move_toward(Vector2.ZERO, 0.5)  # slow/stop
        
    if dist <= attack_range and _can_attack():
        _fire_projectile(target)
```

**Key tuning parameters:**
- `preferred_range`: sweet spot the archer tries to maintain (e.g. 60-80% of max range)
- `kite_speed_multiplier`: often 0.5-0.8 of full speed (shoot-and-scoot)
- `attack_windup`: frames before the projectile spawns; cannot move during windup (commitment)

### 2. Projectile System (Hitscan vs Travel-Time)

#### Hitscan (instant)
```
func _fire_hitscan(target: Node2D) -> void:
    var space = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        global_position,
        target.global_position
    )
    query.collision_mask = DAMAGE_MASK
    query.exclude = [self]
    var result = space.intersect_ray(query)
    if result and result.collider.has_method("take_damage"):
        result.collider.take_damage(attack_damage)
```

#### Projectile (travel-time)
Spawn a `CharacterBody2D` or `Area2D` bullet, set velocity toward target, detect collision. Use object pooling for >10 simultaneous projectiles.

#### Object Pool (simplified)
```
class_name ObjectPool

var _pool: Array[Node] = []
var _scene: PackedScene

func _init(scene: PackedScene, size: int):
    _scene = scene
    for i in size:
        var obj = _scene.instantiate()
        obj.visible = false
        obj.set_process(false)
        obj.set_physics_process(false)
        _pool.append(obj)

func get() -> Node:
    if _pool.is_empty():
        return _scene.instantiate()    # emergency growth
    var obj = _pool.pop_back()
    obj.visible = true
    obj.set_process(true)
    obj.set_physics_process(true)
    return obj

func release(obj: Node) -> void:
    obj.visible = false
    obj.set_process(false)
    obj.set_physics_process(false)
    _pool.append(obj)
```

### 3. Melee Unit Behavior (Close Distance / Surround)

**Core loop:**

1. CHASE: move directly toward target at full speed.
2. When within `attack_range`, stop and enter ATTACK.
3. On attack frame: enable a hitbox Area2D (child of unit) for 1 frame, detect overlaps, apply damage.
4. After attack cooldown, if target still in range → attack again; if target moved → CHASE again.

```
func _melee_behavior(target: Node2D, delta: float) -> void:
    var dist = global_position.distance_to(target.global_position)
    
    if dist > attack_range:
        velocity = global_position.direction_to(target.global_position) * move_speed
    else:
        velocity = Vector2.ZERO
        if _can_attack():
            _melee_attack()
```

**Melee hitbox activation pattern:**
- Add child `Area2D` with `CollisionShape2D` (rectangle or circle)
- Hide/disable it by default
- On attack windup frame: `hitbox.monitoring = true` (or change collision layer)
- On followup frame or via `Timer`: disable

### 4. Line of Sight (Raycast Obstruction)

Ranged units should validate LoS before attacking. Pattern:

```
func _has_line_of_sight(target: Node2D) -> bool:
    var space = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        global_position,
        target.global_position
    )
    query.collision_mask = LOS_BLOCKER_MASK
    var result = space.intersect_ray(query)
    return result.is_empty() or result.collider == target
```

- Use a separate collision layer for "LoS blockers" (terrain, walls, buildings)
- Run LoS check once when target enters detection radius, then every 0.2-0.5s (not every frame)
- Fallback: target remembered position if LoS lost ("last known location")

### 5. Ammo / Reload (Ranged Only)

```
var ammo: int = max_ammo
var reloading: bool = false

func _can_attack() -> bool:
    if reloading or ammo <= 0:
        return false
    return cooldown_timer.is_stopped()

func _fire_projectile(target: Node2D) -> void:
    ammo -= 1
    # ...spawn projectile...
    cooldown_timer.start()
    if ammo <= 0:
        _start_reload()

func _start_reload() -> void:
    reloading = true
    reload_timer.start(reload_time)

func _on_reload_timer_timeout() -> void:
    ammo = max_ammo
    reloading = false
```

- Ammo should be a `UnitStats.tres` resource field
- Reload blocks attack input; UI shows reload progress bar (optional)

### 6. Separation / Swarming Logic

#### Melee swarming (units surround target)
- Use steering "Offset Pursuit" — each unit targets a position offset from the target's center
- Compute approach angle: slot units into surrounding positions based on index in group
- Simple alternative: units naturally spread as they collide with each other (Godot `move_and_slide()` handles push-apart with `collision_safe_margin`)

#### Ranged separation (maintain spacing from allies)
- Add a repulsion force when allies are within `min_spacing` distance
- Perpendicular projection prevents oscillation:

```
var perp = Vector2(-desired_dir.y, desired_dir.x)
var side_dot = repulsion_force.dot(perp)
velocity += perp * side_dot * AVOIDANCE_STRENGTH
```

#### Building push-apart (existing convention)
- Units push away from buildings on collision (use area/body detection)
- No same-type or cross-type unit push-apart (allows melee swarm through allies)

### 7. RPS Counter System

```
# In unit_stats or a dedicated counter table
var strong_against: Array[String] = ["infantry"]    # e.g., archers strong vs infantry
var weak_against: Array[String] = ["cavalry"]       # archers weak vs fast cavalry

func get_damage_multiplier(target_type: String) -> float:
    if target_type in strong_against: return 1.5
    if target_type in weak_against: return 0.75
    return 1.0
```

**AoE2-derived counter triangle:**
| Type | Strong vs | Weak vs |
|------|-----------|---------|
| Archer (ranged) | Infantry | Fast cavalry, skirmishers |
| Melee infantry | Cavalry, buildings | Archers (can't close gap) |
| Fast cavalry (melee) | Archers (close gap quickly) | Spearmen (anti-cav) |

### 8. Attack Animation Timing (AoE2-style)

```
# Melee: damage lands at 50% of animation duration
# Ranged: projectile spawns at end of windup animation

@export var animation_duration: float = 1.0
@export var damage_frame: float = 0.5     # 0.0-1.0 normalized position in animation

func _on_attack_animation_frame(frame: int):
    if frame == damage_frame:
        if is_melee:
            _activate_hitbox()
        else:
            _spawn_projectile()
```

---

## Code Snippet Examples

### Full Ranged Unit State Machine

```gdscript
extends CharacterBody2D

enum State { IDLE, MOVE, CHASE, ATTACK, FLEE }
@export var state: State = State.IDLE
@export var stats: UnitCombatStats

var target: Node2D = null
var cooldown_timer: float = 0.0

func _physics_process(delta: float) -> void:
    match state:
        State.IDLE:
            velocity = Vector2.ZERO
        State.MOVE:
            _move_to_position(delta)
        State.CHASE:
            _ranged_chase(delta)
        State.ATTACK:
            _ranged_attack(delta)
        State.FLEE:
            _ranged_flee(delta)
    move_and_slide()

func _ranged_chase(delta: float) -> void:
    if not target: return
    var dist = global_position.distance_to(target.global_position)
    var dir = global_position.direction_to(target.global_position)

    if dist > stats.attack_range * 1.2:
        velocity = dir * stats.move_speed
    elif dist < stats.preferred_range:
        velocity = -dir * stats.move_speed * 0.7
    else:
        velocity = velocity.move_toward(Vector2.ZERO, delta * 5.0)
        if cooldown_timer <= 0 and _has_line_of_sight(target):
            _fire_projectile(target)

    cooldown_timer = max(0, cooldown_timer - delta)

func _ranged_flee(delta: float) -> void:
    if not target: return
    var dir = global_position.direction_to(target.global_position)
    velocity = -dir * stats.move_speed
    if cooldown_timer <= 0:
        _fire_projectile(target)
    cooldown_timer = max(0, cooldown_timer - delta)

func _fire_projectile(target: Node2D) -> void:
    cooldown_timer = stats.attack_cooldown
    var proj = projectile_pool.get()
    proj.global_position = global_position
    proj.direction = global_position.direction_to(target.global_position)
    proj.speed = stats.projectile_speed
    proj.damage = stats.attack_damage
```

### Full Melee Unit State Machine

```gdscript
extends CharacterBody2D

enum State { IDLE, MOVE, CHASE, ATTACK }
@export var state: State = State.IDLE
@export var stats: UnitCombatStats

var target: Node2D = null
var cooldown_timer: float = 0.0

@onready var hitbox: Area2D = %HitboxArea

func _physics_process(delta: float) -> void:
    match state:
        State.IDLE:
            velocity = Vector2.ZERO
        State.MOVE:
            _move_to_position(delta)
        State.CHASE:
            _melee_chase(delta)
        State.ATTACK:
            _melee_attack(delta)
    move_and_slide()

func _melee_chase(delta: float) -> void:
    if not target: return
    var dist = global_position.distance_to(target.global_position)
    if dist > stats.attack_range:
        velocity = global_position.direction_to(target.global_position) * stats.move_speed
    else:
        velocity = Vector2.ZERO
        state = State.ATTACK
        cooldown_timer = 0.0

func _melee_attack(delta: float) -> void:
    if not target:
        state = State.IDLE
        return
    var dist = global_position.distance_to(target.global_position)
    if dist > stats.attack_range:
        state = State.CHASE
        return
    if cooldown_timer <= 0:
        hitbox.monitoring = true
        cooldown_timer = stats.attack_cooldown
        # hitbox disables itself after one frame via timer or _physics_process
    else:
        cooldown_timer -= delta

func _on_hitbox_body_entered(body: Node2D) -> void:
    if body.has_method("take_damage"):
        body.take_damage(stats.attack_damage)
    hitbox.monitoring = false
```

### Targeting Priority (enemy AI choosing between unit and building)

```gdscript
# From existing convention: enemy within detection radius of military unit = target unit
# No unit in detection = target building

func _select_target() -> Node2D:
    var nearest_unit = null
    var nearest_unit_dist = INF
    var nearest_building = null
    var nearest_building_dist = INF

    for body in detection_area.get_overlapping_bodies():
        if body.is_in_group("military_units"):
            var d = global_position.distance_squared_to(body.global_position)
            if d < nearest_unit_dist:
                nearest_unit_dist = d
                nearest_unit = body
        elif body.is_in_group("buildings"):
            var d = global_position.distance_squared_to(body.global_position)
            if d < nearest_building_dist:
                nearest_building_dist = d
                nearest_building = body

    if nearest_unit and nearest_unit_dist <= detection_radius_sq:
        return nearest_unit
    return nearest_building
```

### Perpendicular Projection for Anti-Oscillation Avoidance

```gdscript
func _compute_avoidance(neighbors: Array) -> Vector2:
    var avoid = Vector2.ZERO
    for other in neighbors:
        var diff = global_position - other.global_position
        var dist = diff.length()
        if dist < min_spacing and dist > 0.01:
            avoid += diff.normalized() / dist
    return avoid

func _apply_steering(base_dir: Vector2, avoidance: Vector2, strength: float) -> Vector2:
    var perp = Vector2(-base_dir.y, base_dir.x)
    var side_dot = avoidance.dot(perp)
    var steer = perp * side_dot * strength
    return (base_dir + steer).normalized()
```

---

## Limitations

### 1. Pathfinding Integration
- Direct `position.direction_to()` steering does not navigate around walls
- To combine with `NavigationAgent2D`, set `target_position` on the agent but override velocity with combat steering when target is close
- Ranged kiting + navmesh pathfinding is complex: the agent must move to a retreat point, not just opposite direction from target

### 2. Performance with Many Units
- Per-frame `intersect_ray()` for LoS checks scales poorly above ~50 units; use event-driven Area2D detection + periodic LoS verification
- Object pooling helps projectile spawn but each active projectile still costs physics ticks
- Melee hitbox activation (Area2D monitoring toggle) is cheap; overlapping multiple hitboxes is not
- Consider spatial partitioning (grid) for neighbor queries in large fights

### 3. Kiting Balance
- Infinite kiting (ranged can always escape) is frustrating — AoE2's answer is "snaring" (slow on hit), faster melee units, and minimum range
- Ranged units must commit to attack windup (cannot move during windup) or suffer accuracy penalty while moving
- Melee with higher speed than ranged projectile travel time can dodge

### 4. Animation Alignment
- Godot `AnimationPlayer` does not natively trigger code at exact frames unless you use `animation_track` with call method tracks or `AnimatedSprite2D.frame_changed`
- Use `call_method_track` in the animation or check `sprite.frame == damage_frame` in `_process`

### 5. Collision Layer Complexity
- LoS blockers, hitbox targets, projectile collisions, and unit-vs-unit separation each need distinct layer/mask configurations
- Misconfiguration leads to units blocking their own projectiles or hitting themselves

### 6. No Native RTS Group Formations
- Godot has no built-in "maintain formation" — must implement via offset pursuit or formation slots
- Units with different speeds (ranged slower than melee) break formation naturally

---

## Alternatives

### Alternative 1: Pure Area2D Detection (No Raycasts)
- Use multiple Area2D rings: DetectionRing, PreferredRing, AttackRing, FleeRing
- Signals trigger state transitions: `body_entered` / `body_exited`
- Simpler but loses LoS obstruction — units will "see" through walls

### Alternative 2: Godot RTS Entity Controller (Third-party)
- github.com/philipbeaucamp/godot-rts-entity-controller
- SC2-inspired built-in attack/move/ability components
- Has weapon system, auto-targeting, movement — modify combat component to differentiate ranged/melee
- Requires learning the addon's component API

### Alternative 3: Steering Behavior Framework (GDQuest GSAI)
- github.com/GDQuest/godot-steering-ai-framework
- Built-in Seek, Flee, Pursuit, Evasion, OffsetPursuit
- "Evade" = ranged flee; "Pursue" = melee chase; "OffsetPursuit" = formation slots
- Blended behaviors: sum weighted outputs (e.g., seek_target * 1.0 + avoid_neighbor * 0.5)
- Requires integrating acceleration-based movement instead of direct velocity setting

### Alternative 4: No Ammo / Simplified Ranged
- Skip ammo entirely; use cooldown-only (infinite arrows)
- Eliminates reload state, simplifies UI, matches AoE2 archer model
- Add "fire rate" and "volley size" as tuning knobs instead

### Alternative 5: Single Attack Range (No Preferred Range)
- Simplest: ranged units behave exactly like melee but with longer attack range and projectile spawn
- No kiting logic — units stand still and fire, melee charges through projectiles
- Game balance shifts entirely to damage stats and speed; micro-managed kiting must be done manually by player

### Alternative 6: C++ Bullet Plugins for High Volume
- Moonzel/Godot-PerfBullets (MultiMesh-based, GDExtension)
- nikoladevelops/godot-blast-bullets-2d (C++, automatic object pooling, homing)
- Only necessary when projectiles exceed ~500 active on screen (bullet hell territory)
