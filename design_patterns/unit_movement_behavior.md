# Unit Movement & Idle Behavior (Godot 4 2D RTS)

## References

- Godot NavigationAgent2D docs: https://docs.godotengine.org/en/stable/classes/class_navigationagent2d.html
- Using NavigationAgents: https://docs.godotengine.org/en/4.6/tutorials/navigation/navigation_using_navigationagents.html
- CharacterBody2D move_and_slide: https://docs.godotengine.org/en/4.6/tutorials/physics/using_character_body_2d.html
- Godot 2D navigation overview: https://docs.godotengine.org/en/4.6/tutorials/navigation/navigation_introduction_2d.html
- gameidea RTS unit series: https://gameidea.org/2024/12/13/making-an-rts-unit-that-moves/
- Godot RTS Entity Controller addon: https://philipbeaucamp.github.io/godot-rts-entity-controller/
- Changing Behaviors (patrol pattern): https://kidscancode.org/godot_recipes/4.x/ai/changing_behaviors/
- Godot RTS formation tutorial: https://www.youtube.com/watch?v=y4yzgBWivNk
- The Liquid Fire state machine: https://theliquidfire.com/2024/03/19/godot-tactics-rpg-04-state-machine/
- rluders/rts-framework (Godot 4): https://github.com/rluders/rts-framework
- SlashSkill RTS combat guide: https://www.slashskill.com/how-to-build-a-combat-system-for-your-rts-game-complete-guide/

---

## Recommended Pattern

### CharacterBody2D + NavigationAgent2D + State Machine

```
CharacterBody2D (root)
├── CollisionShape2D
├── Sprite2D / AnimatedSprite2D
├── NavigationAgent2D
└── DetectionArea2D (optional, for auto-aggro)
```

**Why this stack:**
- `CharacterBody2D` with `move_and_slide()` gives collision-aware movement with slide response.
- `NavigationAgent2D` handles pathfinding via NavigationServer2D, with built-in RVO avoidance.
- A simple enum-based state machine (IDLE, MOVE, ATTACK, HOLD, PATROL, RETURN) is sufficient for RTS units — no need for a full hierarchical FSM unless complexity demands it.
- `DetectionArea2D` (child Area2D with `collision_layer = 0`) enables auto-engagement without interfering with physics.

### State Machine Approach
Use an enum + match pattern rather than a class-based FSM for low unit counts (< 100). For higher counts, centralize iteration in a UnitManager.

```gdscript
enum UnitState { IDLE, MOVE, ATTACK, HOLD, PATROL, RETURN }
var state: UnitState = UnitState.IDLE
var base_position: Vector2  # post to return to when idle
var target_position: Vector2
var command_queue: Array[Command]
```

### Movement Method
Use `move_and_slide()` with velocity derived from NavigationAgent2D `get_next_path_position()`. Do NOT set `position` directly on CharacterBody2D.

---

## Implementation Patterns

### 1. Core Movement (Move-to-Position)

Set `NavigationAgent2D.target_position` and poll `get_next_path_position()` each physics frame. Check `is_navigation_finished()` to detect arrival.

**Key constraints:**
- `target_desired_distance` and `path_desired_distance` should be tuned to stop units at correct distance (default ~4px is tight enough for RTS).
- `path_max_distance` controls repath threshold (higher = less frequent repath, better perf for many units).
- Unit must `await get_tree().physics_frame` in `_ready()` before first path query, because NavigationServer map is empty on frame 0.

### 2. Return to Post (Idle → Return)

Store `base_position` (assigned when unit is placed or right-click-moved). When a unit finishes its current command (attack target dead, destination reached, no queued commands), check if `global_position.distance_to(base_position) > return_threshold`. If so, transition state to RETURN and path back to base_position.

This creates a natural "idle drifting back to post" behavior. The return can be interrupted by any new command or auto-aggro detection.

**Prevent constant return jitter:** Use a hysteresis buffer (e.g., `return_threshold = 3 units, return_complete_threshold = 1 unit`).

### 3. Patrol

Store an array of patrol waypoints and an index. On reaching a waypoint, advance to the next. Wrap around.

Patrol should be interruptible by commands and auto-aggro. When interrupted, the unit remembers its patrol state (current waypoint index) and resumes patrolling after the interruption ends (if no new permanent command was given).

### 4. Hold Position / Stand Ground

Set `state = HOLD`. The unit does NOT move toward enemies — only attacks targets within attack range. Does not reposition or chase.

### 5. Attack-Move (Move-Attack)

A combined command: path to destination, but check DetectionArea2D each frame. If an enemy enters detection radius, pause movement and engage (transition to ATTACK). When target dies or exits chase range, resume pathing to original destination.

Implementation options:
- Each frame check: detection radius scan → if enemy found, override target_position to enemy position.
- DetectionArea2D body_entered/body_exited signals for trigger-based approach.

### 6. Command Queue (Shift-Click)

Store an `Array[Command]`. Each Command is a dictionary or small resource with:
- `type` (MOVE, ATTACK, PATROL, etc.)
- `target_position` (Vector2)
- `target_entity` (Node, optional)
- `metadata` (patrol waypoints, etc.)

Process one command at a time. When current command finishes, pop to next. Shift-click appends to queue; regular click clears queue first.

### 7. Unit Facing / Sprite Flipping

Use `sprite.flip_h = velocity.x < 0` for horizontal flipping, or `sprite.flip_h = direction.x < 0` where direction is from `global_position.direction_to(next_path_position)`.

For 8-directional or free rotation, use `sprite.rotation = velocity.angle()` or `look_at(target_position)` but constrain to Z-axis only (top-down).

**Do NOT** flip via `scale.x = -1` on CharacterBody2D — it flips collision shapes and causes physics issues. Flip the Sprite2D child only.

### 8. Tween vs Manual Position Update

**Do NOT use Tweens for continuous unit movement.** Tweens are for one-shot transitions (e.g., a quick dodge or knockback). RTS movement must be responsive to interruption, path recalculation, and collision. Use `move_and_slide()` each physics frame.

**Acceptable Tween uses:**
- Death animation (fade out, scale down)
- Brief knockback / stutter on hit
- Building placement animation

### 9. RVO Avoidance (NavigationAgent2D Options)

Enable `avoidance_enabled = true` on NavigationAgent2D. Set `radius` to unit's hitbox radius. Call `nav_agent.set_velocity(desired_velocity)` and connect to `velocity_computed` signal. Use the `safe_velocity` from the signal to call `move_and_slide()`.

Two code paths:
- **With avoidance:** `set_velocity()` → `velocity_computed` signal → `move_and_slide()`
- **Without avoidance (simpler):** compute velocity directly → `move_and_slide()`

---

## Code Snippet Examples

### A. Basic Movement State Machine

```gdscript
extends CharacterBody2D
class_name Unit

enum State { IDLE, MOVE, ATTACK, HOLD, PATROL, RETURN }

@export var speed: float = 100.0
@export var click_radius: float = 32.0
@export var return_threshold: float = 48.0  # px distance to trigger return

var state: State = State.IDLE
var base_position: Vector2
var target_position: Vector2
var selected: bool = false

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    await get_tree().physics_frame
    base_position = global_position

func _physics_process(_delta: float) -> void:
    match state:
        State.IDLE:
            _handle_idle()
        State.MOVE:
            _handle_move()
        State.ATTACK:
            _handle_attack()
        State.HOLD:
            _handle_hold()
        State.PATROL:
            _handle_patrol()
        State.RETURN:
            _handle_return()
    _update_facing()

func _handle_move() -> void:
    if nav_agent.is_navigation_finished():
        state = State.IDLE
        return
    var next_pos: Vector2 = nav_agent.get_next_path_position()
    velocity = global_position.direction_to(next_pos) * speed
    move_and_slide()

func _handle_idle() -> void:
    velocity = Vector2.ZERO
    move_and_slide()
    if global_position.distance_to(base_position) > return_threshold:
        _start_return()

func _handle_return() -> void:
    if nav_agent.is_navigation_finished():
        state = State.IDLE
        return
    var next_pos: Vector2 = nav_agent.get_next_path_position()
    velocity = global_position.direction_to(next_pos) * speed
    move_and_slide()

func move_to(pos: Vector2) -> void:
    state = State.MOVE
    target_position = pos
    nav_agent.target_position = pos

func _start_return() -> void:
    state = State.RETURN
    nav_agent.target_position = base_position

func _update_facing() -> void:
    if velocity.length_squared() > 0.0:
        sprite.flip_h = velocity.x < 0

### NOTE FOR GODOT 4: move_and_slide() reads from the built-in `velocity` property.
### Do NOT declare a local `var velocity` — it shadows the property.
### Assign directly to `velocity` (inherited from CharacterBody2D).
```

> **Key Godot 4 gotcha:** `move_and_slide()` takes no arguments and reads from the node's built-in `velocity` property. Declaring `var velocity` locally will shadow it and silently break movement.

### B. Patrol Pattern

```gdscript
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0

func start_patrol(points: Array[Vector2]) -> void:
    patrol_points = points
    patrol_index = 0
    state = State.PATROL
    if patrol_points.size() > 0:
        nav_agent.target_position = patrol_points[0]

func _handle_patrol() -> void:
    if patrol_points.is_empty():
        state = State.IDLE
        return
    if nav_agent.is_navigation_finished():
        patrol_index = (patrol_index + 1) % patrol_points.size()
        nav_agent.target_position = patrol_points[patrol_index]
        return
    var next_pos: Vector2 = nav_agent.get_next_path_position()
    velocity = global_position.direction_to(next_pos) * speed
    move_and_slide()
```

### C. With RVO Avoidance

```gdscript
func _ready() -> void:
    nav_agent.velocity_computed.connect(_on_velocity_computed)
    await get_tree().physics_frame
    base_position = global_position

func _physics_process(_delta: float) -> void:
    if NavigationServer2D.map_get_iteration_id(nav_agent.get_navigation_map()) == 0:
        return
    match state:
        State.MOVE:
            if nav_agent.is_navigation_finished():
                state = State.IDLE
                return
            var next_pos: Vector2 = nav_agent.get_next_path_position()
            var desired: Vector2 = global_position.direction_to(next_pos) * speed
            nav_agent.set_velocity(desired)
        State.IDLE:
            move_and_slide()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
    velocity = safe_velocity
    move_and_slide()
```

### D. Auto-Engage via DetectionArea2D

```gdscript
@onready var detection_area: Area2D = $DetectionArea2D

func _ready() -> void:
    detection_area.body_entered.connect(_on_enemy_detected)
    detection_area.body_exited.connect(_on_enemy_lost)

func _on_enemy_detected(body: Node2D) -> void:
    if state in [State.IDLE, State.HOLD]:
        return  # HOLD ignores auto-engage
    if body.is_in_group("enemies"):
        _engage_target(body)

func _on_enemy_lost(body: Node2D) -> void:
    if current_target == body:
        current_target = null
        if state == State.ATTACK:
            # Resume previous command or return to idle
            _resume_command()
```

### E. Command Queue

```gdscript
class Command:
    enum Type { MOVE, ATTACK, PATROL, ATTACK_MOVE }
    var type: Type
    var target_position: Vector2
    var target_entity: Node2D
    var patrol_waypoints: Array[Vector2]

var command_queue: Array[Command] = []

func issue_command(cmd: Command, clear_queue: bool = true) -> void:
    if clear_queue:
        command_queue.clear()
    command_queue.append(cmd)
    _execute_next_command()

func _execute_next_command() -> void:
    if command_queue.is_empty():
        state = State.IDLE
        return
    var cmd: Command = command_queue[0]
    match cmd.type:
        Command.Type.MOVE:
            move_to(cmd.target_position)
        Command.Type.ATTACK:
            _attack_target(cmd.target_entity)
        Command.Type.PATROL:
            start_patrol(cmd.patrol_waypoints)
        Command.Type.ATTACK_MOVE:
            _start_attack_move(cmd.target_position)

func _on_command_complete() -> void:
    command_queue.pop_front()
    _execute_next_command()
```

---

## Limitations

| Pattern | Limitation |
|---|---|
| **CharacterBody2D + move_and_slide** | Physics collision resolution costs scale per unit. At 100+ units, consider direct position manipulation (skip PhysicsBody) and use NavigationServer directly. |
| **NavigationAgent2D per unit** | Each agent adds avoidance simulation cost. For 200+ units, manage RIDs manually via NavigationServer2D API. |
| **State machine per unit** | `_physics_process` on hundreds of nodes has overhead. For large armies, centralize state iteration in a UnitManager. |
| **Return-to-post** | Can cause oscillation if threshold is too tight. Needs hysteresis (bigger threshold to trigger return, smaller to consider returned). |
| **Patrol** | Simple point-to-point patrol doesn't handle dynamic obstacles well. Path will be recalculated via NavigationAgent2D naturally, but the waypoint list is static. |
| **DetectionArea2D per unit** | Area2D signals scale poorly. For many units, use spatial hash or manual distance checks in UnitManager. |
| **Command queue** | No built-in undo or replay support unless commands are full objects with serialization. |

---

## Alternatives

| Approach | When to Use |
|---|---|
| **Direct `position += direction * speed * delta`** | Minimal units (< 20), no physics collision needed, simple top-down movement. Cheapest CPU cost but no collision response. |
| **RigidBody2D** | When physics-driven movement is desired (knockback, momentum, physics interactions). Rarely suitable for RTS due to unpredictability. |
| **NavigationServer2D API directly** | Large-scale RTS (200+ units). Skip NavigationAgent2D helper, manage RIDs and path queries via NavigationServer2D.map_get_path(). Control movement in a central system. |
| **Tween-based movement** | Cutscene movement, scripted sequences, or movement where interruption is impossible. Do NOT use for interactive RTS units. |
| **Steering behaviors (arrive, pursue, separation)** | When organic/natural group movement is desired (boids-like). Can supplement pathfinding. Godot has no built-in steering system. |
| **Formation offsets** | For coordinated group movement. Each unit's target = group target + formation offset. Needs pathfinding per unit to the offset position. |
| **Event-based lazy state machine** | For simple units (e.g., enemy melee): no per-frame state checking. Use Area2D signals (body_entered/body_exited) to toggle between idle/attack. Good for small numbers but fragile at scale. |
