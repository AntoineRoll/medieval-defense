# Game State Management in Godot 4

## References

| Source | Link | Key Insight |
|--------|------|-------------|
| Godot Docs: Autoloads vs Regular Nodes | https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html | Autoloads persist across scene changes; warns against God-class anti-pattern |
| Godot Docs: Singletons (Autoload) | https://docs.godotengine.org/en/latest/getting_started/step_by_step/singletons_autoload.html | Official scene switcher pattern with `call_deferred` |
| Godot Docs: Background Loading | https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html | `load_threaded_request` / `load_threaded_get` / `load_threaded_get_status` API |
| Godot Docs: Change Scenes Manually | https://docs.godotengine.org/en/4.4/tutorials/scripting/change_scenes_manually.html | Manual scene tree manipulation: delete, hide, or remove from tree |
| Godot Docs: SceneTree class | https://docs.godotengine.org/en/4.4/classes/class_scenetree.html | `change_scene_to_file` vs `change_scene_to_packed` behavior (4.2+) |
| Godot Foundry: Node-Based State Machine | https://godotfoundry.com/blog/godot-4-state-machine-tutorial | State nodes as children; `transition_to()` pattern with `@export` references |
| The Shaggy Dev: Advanced State Machines | https://shaggydev.com/2023/11/28/godot-4-advanced-state-machines/ | Concurrent FSMs, hierarchical states, shared data stores |
| Juan Camilo Farfan: Singleton in Godot 4 | https://juancamilofarfan.com/en/blog/singleton-godot-4 | 4 singleton variants: Autoload, Scene-based, Manual Root, Static |
| GitHub: glass-brick/Scene-Manager | https://github.com/glass-brick/Scene-Manager | Transition plugin with pattern shaders, signals, and callbacks |
| GitHub: DaviD4Chirino/Awesome-Scene-Manager | https://github.com/DaviD4Chirino/Awesome-Scene-Manager | Background loading + animated transitions addon |
| GitHub: IUXGames/EasyTransition | https://github.com/IUXGames/EasyTransition | 16 shader-based transition animations, autoload singleton |
| GitHub: KodeKnave/Eitan-AsyncScene | https://github.com/KodeKnave/Eitan-AsyncScene | Fully async scene loader with progress tracking, transitions, parameter passing |
| GitHub Issue #85852 | https://github.com/godotengine/godot/issues/85852 | `change_scene_to_*` needs `call_deferred` since Godot 4.2 |
| GitHub Issue #86286 | https://github.com/godotengine/godot/issues/86286 | Scene change completion detection: `await` two `process_frame` or use `node_added` signal |
| Godot Proposal #10386 | https://github.com/godotengine/godot-proposals/issues/10386 | Community desire for signal-based async load completion |
| PR #109036 | https://github.com/godotengine/godot/pull/109036 | Adds `load_threaded()` with callback (no polling) — merged for future release |
| Blog: bugnet.io | https://bugnet.io/blog/fix-godot-resource-preload-thread-safety | Thread safety rules for `load_threaded_*`; never touch scene tree from background |
| Blog: hortopan.com | https://blog.hortopan.com/how-to-speed-up-loading-times-in-your-godot-game-by-using-resourceloader-load_threaded_request/ | Practical loading screen with Tween-based polling |
| Uhiyama Lab: Autoload Data Management | https://uhiyama-lab.com/en/notes/godot/autoload-global-data-management | Autoload best practices, signal-based loose coupling, alternative patterns |
| Uhiyama Lab: Dynamic Loading | https://uhiyama-lab.com/en/notes/godot/dynamic-loading-resource-management/ | `preload` vs `load` vs `load_threaded_request` comparison |
| GDQuest: Scene Transition Rect | https://www.gdquest.com/tutorial/godot/2d/scene-transition-rect/ | ColorRect + AnimationPlayer fade transition |

---

## Recommended Pattern

**Hybrid approach: Autoload GameState + Per-Scene FSM + Autoload SceneManager**

This combines three layers:

1. **GameManager (Autoload)** — Persistent singleton that holds global state (gold, wave number, unlocked content). Survives all scene changes. Exposes typed signals for state changes. Does NOT reference scene nodes directly.

2. **SceneManager (Autoload)** — Handles scene transitions with fade effects and optional background loading. Uses `call_deferred` for all scene changes (required since Godot 4.2). Emits `scene_changed` / `transition_finished` signals.

3. **Scene-level State Machine** — Each scene (title, gameplay, pause) uses a lightweight FSM (node-based or enum-based) for its internal states. Scene-specific state dies with the scene.

---

## Implementation Patterns

### Pattern 1: Autoload GameManager (Persistent Data)

- Store gold, wave number, unlocked content, settings
- Use typed signals (`gold_changed`, `wave_changed`) instead of direct node manipulation
- Provide setter functions with validation (no public vars)
- One autoload per concern domain (GameManager, AudioManager, SaveManager) — avoid God-class

### Pattern 2: Autoload SceneManager with Fade Transition

- `CanvasLayer` at layer 128 with `ColorRect` child and `AnimationPlayer`
- `change_scene(path)` → play "fade_out" → await → `change_scene_to_file` via `call_deferred` → play "fade_in" → await → emit `transition_finished`
- `process_mode = PROCESS_MODE_ALWAYS` so pause doesn't freeze transitions
- Optional: accept `PackedScene` parameter for preloaded scenes

### Pattern 3: Background Loading with Loading Screen

- `ResourceLoader.load_threaded_request(path)` on transition start
- Poll status in `_process` via `load_threaded_get_status(path, progress)`
- Update progress bar while `THREAD_LOAD_IN_PROGRESS`
- When `THREAD_LOAD_LOADED`: `load_threaded_get(path)` → `change_scene_to_packed(scene)`
- Loading screen must be Autoload (otherwise it gets destroyed on scene change)
- **Thread safety**: never call `add_child`, `queue_free`, or `change_scene_to_*` from non-main thread; use `call_deferred`

### Pattern 4: Node-Based Finite State Machine (Per-Scene)

- `State` base class: `enter(previous_state)`, `exit()`, `process(delta)`, `physics_process(delta)`
- `StateMachine` node: holds `@export initial_state`, iterates children of type `State`, injects `parent` reference, delegates `_process`/`_physics_process`
- States call `state_machine.transition_to(target_state)` themselves (decentralized transition logic)
- `@export` references for sibling states (loose coupling, Inspector-configurable)

### Pattern 5: Game Flow State Transitions

```
[TITLE] --start--> [SELECT (sergeant)] --confirm--> [PLAY (wave defense)]
                                                      |
                                                      +--> [PAUSE] --resume--> [PLAY]
                                                      |
                                                      +--> [GAME_OVER] --restart--> [TITLE]
```

- Implemented via SceneManager switching scenes
- GameManager tracks persistent flow state (e.g., `current_wave`, `game_result`)
- PAUSE implemented as overlay scene added to tree (not a scene switch) so gameplay state is preserved

### Pattern 6: `call_deferred` for Safe Scene Changes

Since Godot 4.2, `change_scene_to_file` and `change_scene_to_packed` remove the current scene immediately. This causes errors during physics callbacks (`_on_body_entered`, etc.). Always defer:

```gdscript
get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
# or
get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
```

### Pattern 7: Detecting Scene Change Completion

`change_scene_to_*` has no completion signal. Reliable detection:

- **`await get_tree().create_timer(0).timeout`** — simplest, fires after scene change at end of frame
- **Connect to `SceneTree.node_added`** — detect when `new_node == get_tree().current_scene`, then await its `ready` signal
- **`await get_tree().process_frame` (twice)** — works but fragile across engine versions

---

## Code Snippet Examples

### GameManager Autoload

```gdscript
extends Node
class_name GameManager

signal gold_changed(amount: int)
signal wave_changed(wave: int)

var gold: int = 100 : set = _set_gold
var current_wave: int = 0 : set = _set_wave

func _set_gold(value: int) -> void:
    gold = max(value, 0)
    gold_changed.emit(gold)

func _set_wave(value: int) -> void:
    current_wave = value
    wave_changed.emit(current_wave)
```

### SceneManager Autoload with Fade

```gdscript
extends CanvasLayer

signal transition_finished

@onready var color_rect: ColorRect = $ColorRect
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    color_rect.visible = false

func change_scene(path: String) -> void:
    color_rect.visible = true
    anim_player.play("fade_out")
    await anim_player.animation_finished
    get_tree().call_deferred("change_scene_to_file", path)
    await get_tree().create_timer(0).timeout
    anim_player.play("fade_in")
    await anim_player.animation_finished
    transition_finished.emit()
```

### Background Loading Screen (Autoload)

```gdscript
extends CanvasLayer

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $Label

var _target_path: String = ""

func load_scene(path: String) -> void:
    _target_path = path
    show()
    ResourceLoader.load_threaded_request(path)
    set_process(true)

func _process(_delta: float) -> void:
    if _target_path.is_empty():
        return
    var progress: Array = []
    var status: int = ResourceLoader.load_threaded_get_status(_target_path, progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            progress_bar.value = progress[0] * 100.0
            status_label.text = "Loading... %d%%" % int(progress[0] * 100.0)
        ResourceLoader.THREAD_LOAD_LOADED:
            set_process(false)
            var scene: PackedScene = ResourceLoader.load_threaded_get(_target_path)
            get_tree().call_deferred("change_scene_to_packed", scene)
            _target_path = ""
            hide()
        ResourceLoader.THREAD_LOAD_FAILED:
            set_process(false)
            status_label.text = "Load failed."
```

### Node-Based State Machine

```gdscript
# state.gd
class_name State
extends Node

var parent: Node
var state_machine: StateMachine

func enter(previous_state: State) -> void:
    pass

func exit() -> void:
    pass

func tick(_delta: float) -> void:
    pass

func physics_tick(_delta: float) -> void:
    pass
```

```gdscript
# state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State

func _ready() -> void:
    var root: Node = get_parent()
    for child in get_children():
        if child is State:
            child.parent = root
            child.state_machine = self
    if initial_state:
        current_state = initial_state
        current_state.enter(null)

func _process(delta: float) -> void:
    if current_state:
        current_state.tick(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_tick(delta)

func transition_to(target: State) -> void:
    if target == current_state or target == null:
        return
    var previous: State = current_state
    current_state.exit()
    current_state = target
    current_state.enter(previous)
```

### Game Flow State Machine (High-Level)

```gdscript
enum GameFlow { TITLE, SELECT, PLAY, PAUSE, GAME_OVER }

var flow_state: int = GameFlow.TITLE

func transition_to(state: int) -> void:
    flow_state = state
    match state:
        GameFlow.TITLE:
            SceneManager.change_scene("res://scenes/title_screen.tscn")
        GameFlow.SELECT:
            SceneManager.change_scene("res://scenes/sergeant_select.tscn")
        GameFlow.PLAY:
            SceneManager.change_scene("res://scenes/game.tscn")
        GameFlow.GAME_OVER:
            SceneManager.change_scene("res://scenes/game_over.tscn")
```

### Pause Overlay (Additive Scene, Not a Switch)

```gdscript
var pause_scene: PackedScene = preload("res://scenes/pause_menu.tscn")
var pause_instance: Node = null

func pause_game() -> void:
    if pause_instance:
        return
    pause_instance = pause_scene.instantiate()
    add_child(pause_instance)
    get_tree().paused = true

func unpause_game() -> void:
    if pause_instance:
        get_tree().paused = false
        pause_instance.queue_free()
        pause_instance = null
```

### Manual Scene Switcher with Persistent Scene

```gdscript
extends Node

var current_scene: Node = null

func _ready() -> void:
    current_scene = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

func switch_scene(path: String) -> void:
    call_deferred("_deferred_switch", path)

func _deferred_switch(path: String) -> void:
    current_scene.queue_free()
    var new_scene: PackedScene = load(path)
    current_scene = new_scene.instantiate()
    get_tree().root.add_child(current_scene)
    get_tree().current_scene = current_scene
```

---

## Limitations

| Pattern | Limitation |
|---------|------------|
| `change_scene_to_file`/`_packed` | Since Godot 4.2, removes current scene immediately. No built-in completion signal. Must use `call_deferred` in physics callbacks. |
| `ResourceLoader.load_threaded_request` | Texture loading is NOT asynchronous (textures block main thread on GPU upload). No built-in completion signal — requires polling. PR #109036 adds callback support for future release. |
| Autoload as God-class | Overuse creates tight coupling, makes testing impossible. One autoload per concern domain. |
| Node-based FSMs | More setup per state (Inspector configuration). Not suitable for 15+ states — use dictionary-based lookup instead. |
| Concurrent states | Single FSM cannot handle simultaneous states (e.g., running + shooting). Requires multiple state machines per actor. |
| Transition during paused game | Scene change while `get_tree().paused = true` may stall. Use `process_mode = PROCESS_MODE_ALWAYS` on transition nodes. |
| Manual scene switching | Must manually call `get_tree().current_scene = new_scene` or some features (e.g., `get_tree().reload_current_scene`) break. |

---

## Alternatives

| Alternative | Description | When to Use |
|-------------|-------------|-------------|
| **Scene-based Singleton** | Singleton created per-scene, destroyed on scene exit (e.g., BossFightDirector) | State only matters within one scene; cleanup on exit is desired |
| **Manual Root Singleton** | Instantiate persistent node from code and mount on `get_tree().root` | Need persistence between scenes but don't want autoload (control over creation timing) |
| **Static Singleton** | `class_name` + `static var` for in-memory config; no node tree presence | Configuration data that resets on game close; no lifecycle needed |
| **Custom Resource** | `extends Resource` for data blueprints (item stats, character config) | Data-driven content; Inspector-editable; reusable across scenes |
| **Dependency Injection** | Pass references via `@export` or constructor injection instead of global access | Unit testing; decoupled architecture; medium-to-large teams |
| **Behavior Tree** (LimboAI) | Node-based behavior trees for complex AI with 15+ states | Enemy AI with many conditional transitions; better than FSM at scale |
| **AnimationTree State Machine** | Built-in Godot 4 AnimationTree node with blend transitions | States differ only in animation, not in game logic |
| **Signal Bus (Event Bus)** | Autoload with only signals, no state — pure decoupled communication | Loose coupling between systems that should not know about each other |
| **Pushdown Automaton (State Stack)** | States pushed/popped from a stack; returns to previous state on pop | Menus, dialogue systems, interruption scenarios |
| **Additive Scene Loading** | Load new scene via `add_child()` without removing current scene | HUD overlays, pause menus, inventory screens that preserve game state below |
