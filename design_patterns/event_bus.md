# Event Bus / Signal Architecture in Godot 4

## References

- **Godot Signals Docs** — https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- **Signal (Variant) API** — https://docs.godotengine.org/en/4.5/classes/class_signal.html
- **Autoloads vs Regular Nodes** — https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html
- **Scene Organization** — https://docs.godotengine.org/en/4.6/getting_started/workflow/best_practices/scene_organization.html
- **GDQuest Event Autoload Pattern** — https://gdquest.com/tutorial/godot/gdscript/events-signals-pattern/
- **Godot Event Bus (Nicola Dau)** — https://nicoladau.com/2024/05/25/sending-signals-across-your-godot-4-project-with-game-events/
- **Signal Architecture Guide (Febucci)** — https://blog.febu/cci.com/2024/12/godot-signals-architecture/
- **Godot Signal Bus (OpenIllumi)** — https://openillumi.com/en/en-godot-signal-bus-multiple-instances-decouple/
- **Events Are The Way To Go(dot) — GodotCon 2025** — https://www.youtube.com/watch?v=yB3Wv-Lr7pg
- **Godot Patterns: EventBus (DevOops)** — https://mcgillij.dev/godot-patterns-event-bus.html
- **Signals & Observer Pattern** — https://slicker.me/godot/signals-observer-pattern.html
- **GodotProposals: Dependency Injection in GDScript (#8322)** — https://github.com/godotengine/godot-proposals/issues/8322
- **chickensoft-games/AutoInject (C#)** — https://github.com/chickensoft-games/autoinject
- **TheColorRed/godot-di** — https://github.com/TheColorRed/godot-di
- **Technikhighknee/GodotEventBus** — https://github.com/Technikhighknee/GodotEventBus
- **Memory Leaks in Godot (Bugnet)** — https://bugnet.io/blog/how-to-find-memory-leaks-in-godot-games
- **Godot Signal disconnect() Fix** — https://bugnet.io/blog/fix-godot-signal-disconnect-error
- **Facade Pattern in Godot 4** — https://www.syntaxcache.com/blog/godot-patterns/facade-pattern-godot-4
- **Messenger/Mediator Pattern in Godot** — https://joshanthony.info/2022/01/17/implementing-the-messenger-pattern-in-godot/
- **Godot Performance: Signal HashMap PR #72421** — https://github.com/godotengine/godot/pull/72421
- **Godot Forum: Signal Performance Discussion** — https://forum.godotengine.org/t/performance-of-signals/116202
- **Game Programming Patterns: Observer** — https://gameprogrammingpatterns.com/observer.html
- **Godot Engine Best Practices** — https://docs.godotengine.org/en/stable/tutorials/best_practices/

---

## Recommended Pattern

### General Architecture

| Scope | Pattern | When |
|-------|---------|------|
| Parent → Child | Direct method call | Parent owns the child; data flows down |
| Child → Parent | Direct signal | Child notifies its direct parent of events |
| Siblings (same scene) | Local signal via shared parent | Both nodes are in the same scene subtree |
| Across systems / scenes | **Event Bus (Autoload)** | Nodes have no direct reference to each other |
| One-shot / temp | `CONNECT_ONE_SHOT` | Connection should fire exactly once |
| Dynamic instances | **Event Bus** | Many emitters of the same type (e.g. enemies) |

### Rule of Thumb

> Data flows down (parent calls child directly). Events flow up (child signals parent). Events across unrelated branches go through an Event Bus.

### Event Bus: Single vs Per-System

**Single global bus** — one autoload with all signals. Simpler to set up, easy to find all signals in one place. Risk of becoming a "god object" with hundreds of signals.

**Per-system buses** — separate autoloads (e.g. `CombatBus`, `UIBus`, `AudioBus`). Better separation of concerns, clearer signal domains, easier to avoid naming collisions. More files to manage.

**Recommended**: Start with 2-3 domain buses (game, UI, audio). Split further only when a bus exceeds ~30 signals or becomes hard to navigate. Avoid going to extremes — a single mega-bus or dozens of tiny buses both create problems.

---

## Implementation Patterns

### 1. Simple Event Bus (Autoload)

Create a script, add to Project Settings → Autoload. Minimal, no state, just signals.

```
# EventBus.gd
extends Node

signal unit_spawned(unit: Node)
signal unit_died(unit: Node)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal game_over(victory: bool)
signal gold_changed(amount: int)
```

### 2. Per-System Event Buses

```
# GameEvents.gd  — game state, combat, units
extends Node
signal unit_spawned(unit: Node)
signal unit_died(unit: Node)
signal enemy_spawned(enemy: Node)
signal wave_started(wave_number: int)
signal gold_changed(amount: int)

# UIEvents.gd  — UI-specific notifications
extends Node
signal message_displayed(text: String)
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)

# AudioEvents.gd  — audio triggers
extends Node
signal sound_played(sound_id: String, position: Vector2)
signal music_changed(track_id: String)
```

### 3. Resource-Based Shared Variables

For cases where you need current state (not just event notification), use a `Resource` with an `on_changed` signal.

```gdscript
# SharedValue.gd
extends Resource
class_name SharedValue

signal on_changed(new_value, old_value)

var value:
    set(v):
        var old = value
        value = v
        on_changed.emit(value, old)
```

Both emitter and listener reference the same `.tres` resource instance. The setter emits the signal, listeners connect to `on_changed` in `_ready`.

### 4. Dependency Injection (GDScript)

No native DI in GDScript. Workarounds:
- Pass references via `_init()` parameters.
- Use `@export var` and wire in the editor.
- Use community addons like `godot-di` or manual provider pattern (walking ancestors).
- For C# projects, `chickensoft-games/AutoInject` provides robust DI.

---

## Code Snippet Examples

### Emitter (any node)

```gdscript
# enemy.gd
extends Node2D

func die():
    EventBus.unit_died.emit(self)
    queue_free()
```

### Listener (any node)

```gdscript
# hud.gd
extends CanvasLayer

func _ready():
    EventBus.unit_died.connect(_on_unit_died)
    EventBus.gold_changed.connect(_on_gold_changed)

func _exit_tree():
    if EventBus.unit_died.is_connected(_on_unit_died):
        EventBus.unit_died.disconnect(_on_unit_died)
    if EventBus.gold_changed.is_connected(_on_gold_changed):
        EventBus.gold_changed.disconnect(_on_gold_changed)

func _on_unit_died(unit: Node):
    update_score()

func _on_gold_changed(amount: int):
    update_gold_display(amount)
```

### Safe connection pattern

```gdscript
func safe_connect(source_node: Node, signal_name: String, callable: Callable) -> bool:
    if not is_instance_valid(source_node):
        push_error("Invalid source node")
        return false
    if not source_node.has_signal(signal_name):
        push_error("Signal %s not found on %s" % [signal_name, source_node.name])
        return false
    source_node.connect(callable)
    return true
```

### Lambda with CONNECT_ONE_SHOT

```gdscript
# No cleanup needed — auto-disconnects after first fire
EventBus.wave_started.connect(
    func(n: int):
        print("Wave %d started!" % n),
    CONNECT_ONE_SHOT
)
```

### Binding extra arguments

```gdscript
# Store the bound callable for cleanup
var _bound_handler := _on_button_pressed.bind(button_id)

EventBus.button_pressed.connect(_bound_handler)

func _exit_tree():
    if EventBus.button_pressed.is_connected(_bound_handler):
        EventBus.button_pressed.disconnect(_bound_handler)
```

### Deferred signal (runs at end of frame)

```gdscript
EventBus.game_over.emit.bind(true).call_deferred()
# or via CONNECT_DEFERRED flag
EventBus.game_over.connect(_on_game_over, CONNECT_DEFERRED)
```

### Autoload as pure relay (no state)

```gdscript
# EventBus.gd — stateless, only signals
extends Node

signal unit_spawned(unit: Node)
signal unit_died(unit: Node)
signal wave_started(wave_number: int)
```

---

## Signal Connection & Cleanup Rules

### When to disconnect

| Connection type | Cleanup needed? |
|---|---|
| Both nodes in same subtree, parent outlives child | No — engine auto-cleans when child is freed |
| Signal on autoload, listener is a scene node | **Yes** — disconnect in `_exit_tree` or connection persists |
| Signal on temporary node, listener on persistent node | **Yes** — or emitting on freed node causes errors |
| `CONNECT_ONE_SHOT` | No — auto-disconnects after first emit |
| Lambda (anonymous function) | Only if stored in variable; inline lambdas cannot be disconnected |

### Safe disconnect pattern

```gdscript
func _exit_tree():
    if EventBus.signal_name.is_connected(_my_handler):
        EventBus.signal_name.disconnect(_my_handler)
```

### Why `_exit_tree` (not `_notification(NOTIFICATION_PREDELETE)`)

- `_exit_tree` fires when the node leaves the tree (scene change, `remove_child`, `queue_free`).
- Both source and target nodes are still valid at this point, so `disconnect()` works.
- `NOTIFICATION_PREDELETE` fires too late for safe disconnection.

---

## Limitations

1. **Debugging visibility** — Signal connections are invisible in script files. Editor has a Debugger → Signals tab, but tracking data flow across many connects/emits is hard.
2. **No compile-time safety** — Typed signals (`signal died(unit: Node)`) give editor validation, but connecting with wrong callable signature only produces runtime errors.
3. **Performance at scale** — ~3× slower than raw `Array[Callable]` iteration in benchmarks (3587 µs/pass vs 889 µs/pass for 2000 runs). Not a concern for typical game events (<100 concurrent connections).
4. **Cannot easily trace "who is listening"** — No built-in introspection tool to list all listeners for a signal at a glance.
5. **Signal overload risk** — A single bus with 100+ signals becomes hard to navigate and prone to naming collisions.
6. **No event ordering guarantees** — Listeners are called in connection order, but relying on this is fragile.
7. **Lambdas cannot be disconnected** — Each `func(...): ...` expression creates a new `Callable` object; anonymous lambdas cannot be passed to `disconnect()`.
8. **C# event syntax requires manual cleanup** — Using `+=` syntax in C# does NOT auto-disconnect custom signals; must use `-=` in `_ExitTree`.

---

## Alternatives

### Direct method call
- Simplest pattern. Best for parent→child or tightly coupled systems.
- Creates hard coupling. Brittle under refactoring.

### Direct signal (local)
- Child signals parent. Low coupling, high clarity.
- Requires emitter and listener to have a reference to each other.

### Groups (`add_to_group`, `call_group`)
- Broadcast to many nodes without individual references.
- No type safety. String-based. Hard to trace.

### Mediator pattern
- A dedicated object coordinates communication between multiple objects.
- More structured than raw signals; useful for complex multi-step workflows.
- Overkill for simple emit-react scenarios.

### Dependency Injection
- Pass dependencies via constructor or property injection.
- GDScript has no native DI; requires manual wiring or community addons.
- Best for testability (swap mocks). Over-engineered for small projects.

### Messenger pattern (string-based event bus)
- Generic `emit("event_name", data)` / `on("event_name", callback)` API.
- More dynamic than typed signals — events can be created at runtime.
- Loses all type safety. Harder to maintain. Generally **not recommended** over typed signals.

### Resource-based shared variables
- A `Resource` wrapping a value with an `on_changed` signal.
- Both setter and getter reference the same `.tres` instance.
- Solves the "can't query current value from event bus" problem.
- Adds file management overhead for each shared variable.

### Observer pattern (manual)
- Implement your own observer list with `Array[Callable]`.
- Maximum performance (no signal dispatch overhead).
- Lose editor integration, autocomplete, and Godot's built-in safety.
- Only worthwhile for hot-path systems (10k+ emissions/frame).

### Facade pattern
- Wraps multiple subsystems behind a single simplified interface.
- Returns data structs, emits signals for decoupled listeners.
- Good for complex operations (e.g., "end turn" coordinatings calendar, economy, AI).

---

## Summary

| Aspect | Recommendation |
|---|---|
| **Bus structure** | 2-3 domain buses (game, UI, audio) |
| **State in bus** | None — stateless relay only |
| **Connection method** | `signal.connect(callable)` in code (not editor) |
| **Disconnection** | `_exit_tree` with `is_connected` guard |
| **Signal args** | Typed, minimal (pass Node refs, not raw data) |
| **Avoid** | Lambdas needing cleanup; mega-bus; string-based messenger |
| **Test with** | Emit signals in test scripts, assert listener side effects |
