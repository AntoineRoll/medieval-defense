# State Machine Pattern in Godot 4

## References

- **Godot FSM Demo (official)**: `godot-demo-projects` → `2d/finite_state_machine/` — enum + match and node-based patterns. PR #252 by NathanLovato (GDQuest).
- **GDQuest FSM Guide**: https://gdquest.com/tutorial/godot/design-patterns/finite-state-machine/
- **Godot Foundry Node-Based FSM**: https://godotfoundry.com/blog/godot-4-state-machine-tutorial/
- **The Shaggy Dev State Machines**: https://shaggydev.com/2023/10/08/godot-4-state-machines/
- **Godot 4.3+ HFSM (DEV.to)**: https://dev.to/ubr4x/godot-43-hierachical-state-machine-2pd
- **LimboAI (C++ plugin, BT + HSM)**: https://github.com/limbonaut/limboai
- **StateGraph (plugin, graph-editor FSM)**: https://github.com/MrBSmith/StateGraph
- **Pushdown Automata (JarkkoPar)**: https://github.com/JarkkoPar/Godot_PushdownAutomata
- **Godot AnimationTree docs**: https://docs.godotengine.org/en/4.5/tutorials/animation/animation_tree.html
- **Game Programming Patterns — State**: https://gameprogrammingpatterns.com/state.html
- **Comparison BT vs FSM (arXiv)**: https://arxiv.org/html/2405.16137v1
- **Godot Docs — Autoloads vs Regular Nodes**: https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html

---

## Recommended Pattern

| Complexity | Pattern | When to Use |
|---|---|---|
| 2–4 states, simple | **Enum + match** | Menu states, door open/close, simple toggles |
| 5–10 states, moderate | **Node-based (State pattern)** | Player controller, enemy AI, unit behavior |
| 10+ with sub-behaviors | **Hierarchical FSM** | Grounded → Idle/Run/Crouch/Slide, boss phases |
| Stackable/interruptible | **Pushdown Automaton** | Pause menu over gameplay, inventory open, dialogue |
| Complex AI, many conditions | **Behavior Tree (LimboAI)** | Enemy with 15+ states, tactical decisions |
| Animation-driven | **AnimationTree StateMachine** | Characters where only animation differs per state |

**Start with enum + match. Refactor to node-based when `match` grows unwieldy or you need state reuse across entities. Do not over-engineer early.**

---

## Implementation Patterns

### 1. Enum + Match (simplest, inline)

A single script with a `state` enum and a `match` block in `_process`/`_physics_process`. Best for small, self-contained machines. No reusability, no separation of concerns.

### 2. Node-Based State Pattern (community standard)

Used by GDQuest, The Shaggy Dev, Godot Foundry, and most production Godot 4 projects.

**Structure:**
```
Character (CharacterBody2D)
  └── StateMachine (Node)
        ├── IdleState (Node, script extends State)
        ├── WalkState (Node, script extends State)
        ├── AttackState (Node, script extends State)
        └── ...
```

- `State.gd` — abstract base class defining `enter()`, `exit()`, `update(delta)`, `physics_update(delta)`, and a `transition_to()` signal or method.
- Each state is a **child node** with its own script extending `State`.
- `StateMachine.gd` — iterates children in `_ready()`, indexes them by name in a `Dictionary`, connects `transitioned` signals, delegates `_process`/`_physics_process` to the current state.
- States call `transition_to("next_state")` on themselves — the signal is picked up by the `StateMachine`.
- States access the parent entity via `owner` or an exported `@onready var parent`.
- State nodes can have `@export` variables tweaked per-instance in the Inspector.

**Key design rule:** States decide their own transitions. The StateMachine is a passive router.

### 3. Hierarchical FSM (HFSM)

States contain child (sub-)states. A parent "Grounded" state delegates to "Idle", "Run", "Crouch" sub-states. Entering a parent implicitly activates its initial child. Transitions can happen at any level. Implementation via nested StateMachine nodes or the `AnimationNodeStateMachine` graph (which supports nested sub-state machines natively).

### 4. Pushdown Automaton (Stack Machine)

States live on a stack. The top-most state is active. Pushing a new state suspends the previous one; popping it resumes the previous state. Perfect for pause menus, inventory screens, or any "interrupt and return" pattern. The `pushdown_automata` approach by JarkkoPar provides `on_state_pushed()`, `on_state_popped()`, `on_state_deactivated()`, `on_state_reactivated()`, and `tick_state(delta)` lifecycle hooks.

### 5. AnimationTree StateMachine (visual)

Godot's built-in `AnimationNodeStateMachine` provides a visual graph editor for animation states. Controlled via `AnimationNodeStateMachinePlayback.travel("state_name")`. Supports A*-based pathfinding through transitions, crossfade blending, conditions, and nested sub-state machines. Best for animation-driven logic where states differ primarily in which animation plays.

### 6. Autoload vs Per-Entity vs Scene-Based

| Scope | Pattern | Pros | Cons |
|---|---|---|---|
| **Global** | Autoload (singleton) | Accessible everywhere, persists across scenes | Tight coupling, pollutes global namespace |
| **Per-Entity** | Node-based FSM as child | Self-contained, reusable across entity types | Needs entity reference passed in |
| **Scene-Based** | FSM lives in scene root | Automatically destroyed on scene exit, scoped to level | Cannot persist across scene changes |

**Rule of thumb:** Game-wide flow (menu → gameplay → pause) can use autoload. Entity behavior (player, enemy, unit) should use per-entity node-based FSMs. Level-specific state (boss fight, puzzle) should be scene-based.

---

## Code Snippet Examples

### State Base Class (node-based pattern)

```gdscript
class_name State
extends Node

signal transitioned(state_name: String)

var parent: Node


func enter() -> void:
    pass


func exit() -> void:
    pass


func update(_delta: float) -> void:
    pass


func physics_update(_delta: float) -> void:
    pass
```

### StateMachine Node

```gdscript
class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var _states: Dictionary = {}


func _ready() -> void:
    for child in get_children():
        if child is State:
            _states[child.name.to_lower()] = child
            child.transitioned.connect(_on_state_transitioned)

    if initial_state:
        initial_state.enter()
        current_state = initial_state
    else:
        push_warning("StateMachine: no initial_state set")


func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)


func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)


func _on_state_transitioned(state: State, new_state_name: String) -> void:
    if state != current_state:
        return

    var new_state = _states.get(new_state_name.to_lower())
    if not new_state:
        push_warning("StateMachine: state '%s' not found" % new_state_name)
        return

    current_state.exit()
    current_state = new_state
    new_state.enter()
```

### Concrete State Example (Idle → Walk)

```gdscript
class_name IdleState
extends State

@export var friction: float = 5.0


func enter() -> void:
    (parent as CharacterBody2D).velocity = Vector2.ZERO


func update(_delta: float) -> void:
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if input_dir.length() > 0:
        transitioned.emit("Walk")


func physics_update(delta: float) -> void:
    var body = parent as CharacterBody2D
    body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)
    body.move_and_slide()
```

### AnimationTree StateMachine Control

```gdscript
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = \
    animation_tree.get("parameters/playback")

# In _process or state logic:
if attack_pressed:
    playback.travel("attack")
elif velocity.length() > 0:
    playback.travel("run")
else:
    playback.travel("idle")
```

### Pushdown Automaton (using signal-based approach)

```gdscript
extends Node

var _state_stack: Array[State] = []


func push_state(state: State) -> void:
    if _state_stack.size() > 0:
        _state_stack.back().exit()
    _state_stack.append(state)
    state.enter()


func pop_state() -> void:
    if _state_stack.size() == 0:
        return
    var popped = _state_stack.pop_back()
    popped.exit()
    if _state_stack.size() > 0:
        _state_stack.back().enter()


func get_current_state() -> State:
    return _state_stack.back() if _state_stack.size() > 0 else null
```

---

## Limitations

1. **Rigid structure** — transitions are hard-coded. Adding a new state often means updating all states that can transition to it.
2. **Single active state** — cannot represent "running AND shooting" simultaneously. Solution: multiple concurrent FSMs (one per concern).
3. **Boilerplate** — node-based pattern requires one scene/node per state. For 15+ states this becomes management overhead.
4. **Code duplication across states** — shared logic (e.g., gravity, ground check) must be extracted to helper functions or injected via reference.
5. **No guard conditions by default** — any state can transition to any other. Need to manually add `can_enter()` checks to prevent invalid transitions (e.g., Dead → Jump).
6. **Scales poorly to complex AI** — an FSM with 15+ states and many conditional transitions becomes hard to reason about. Behavior trees handle this better.

---

## Alternatives

| Pattern | Best For | Trade-offs |
|---|---|---|
| **Behavior Trees** (LimboAI, beehave) | Complex enemy AI, tactical decisions | Heavier implementation, needs plugin for Godot. More modular and runtime-adaptable than FSM. Composite nodes (Selector, Sequence, Parallel) compose behaviors declaratively. |
| **Utility AI** | Dynamic prioritization (e.g., choose between attack/heal/flee based on scored options) | More complex to set up. Best when many equally-valid actions compete. Not built-in; needs custom implementation or plugin. |
| **GOAP** (Goal-Oriented Action Planning) | Open-ended problem solving (e.g., survival crafting NPCs) | Heavy planning overhead. Unpredictable behavior. Rare in Godot; no mature plugin. |
| **AnimationTree Alone** | Animation-driven characters | No game logic separation. Cannot handle physics, input, or cooldowns — only animation selection and blending. |
| **Concurrent FSMs** | Characters needing parallel state (locomotion + combat) | Multiple small FSMs on the same entity, each managing one concern. More total code but better separation. |
