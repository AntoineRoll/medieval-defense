# Pause System — Godot 4 Research

## References

- [Godot Docs: Pausing games and process mode (4.6)](https://docs.godotengine.org/en/4.6/tutorials/scripting/pausing_games.html)
- [SceneTree.paused documentation](https://docs.godotengine.org/en/4.6/classes/class_scenetree.html#class-scenetree-property-paused)
- [Node.ProcessMode enum](https://docs.godotengine.org/en/4.6/classes/class_node.html#enum-node-processmode)
- [Godot proposals: make create_timer process_always default to false](https://github.com/godotengine/godot-proposals/issues/9924)
- [Godot proposals: Refactor pause system for arbitrary tree pausing](https://github.com/godotengine/godot-proposals/issues/1011)
- [GitHub: godot-pause-menu (markhj)](https://github.com/markhj/godot-pause-menu) — Example with `WhenPaused` approach, Godot 4.2
- [Issue #72974: Physics not paused by process_mode=ALWAYS + disable_mode=KEEP_ACTIVE](https://github.com/godotengine/godot/issues/72974) — Confirmed intentional: physics server stops globally
- [Issue #83160: NOTIFICATION_PAUSED/NOTIFICATION_UNPAUSED reversed for WHEN_PAUSED mode](https://github.com/godotengine/godot/issues/83160)
- [Issue #114694: AudioStreamPlayer.play() ignores get_tree().paused](https://github.com/godotengine/godot/issues/114694)
- [PR #46191: Refactor Process Mode](https://github.com/godotengine/godot/pull/46191) — The PR that introduced the current ProcessMode system

---

## Recommended Pattern

Use `get_tree().paused = true` with a **CanvasLayer overlay** set to `PROCESS_MODE_WHEN_PAUSED`. Keep pause/unpause logic in two separate processing contexts to avoid re-entrancy bugs (rapid ESC toggling). Do NOT rely on `_input` in the pause menu — use button signals (`pressed`) instead, since signals fire regardless of pause state.

### Architecture

- **Pause trigger node** (main game scene, `PROCESS_MODE_PAUSABLE`): catches `ui_cancel` input, sets `get_tree().paused = true`, shows the pause overlay.
- **Pause overlay** (CanvasLayer, `PROCESS_MODE_WHEN_PAUSED`): contains Resume/Quit buttons. Only processes when paused. Resume button hides overlay and sets `get_tree().paused = false`.
- **Autoloads**: set to `PROCESS_MODE_ALWAYS` if they must keep running (e.g., audio managers). Otherwise leave as default.
- **SceneTreeTimers**: always pass `process_always = false` as second arg to `create_timer()` so they pause correctly. Or wrap in a helper.

### Two-context rule

The code that *enters* pause (input-handling in the game scene) must be separate from the code that *exits* pause (button signals in the pause overlay). If you try to toggle pause from a single `_process()`, rapid ESC presses can cause double-toggle bugs.

---

## Implementation Patterns

### Pattern A: CanvasLayer overlay with WHEN_PAUSED (recommended)

Pause overlay scene structure:
```
PauseOverlay (CanvasLayer, process_mode = WHEN_PAUSED)
  ColorRect (full-screen dim)
  VBoxContainer (centered)
    Button "Resume"
    Button "Quit"
```

Game scene catches ESC:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_tree().paused = true
        $PauseOverlay.show()
        get_viewport().set_input_as_handled()
```

Pause overlay script:

```gdscript
extends CanvasLayer

func _ready() -> void:
    hide()

func _on_resume_pressed() -> void:
    hide()
    get_tree().paused = false

func _on_quit_pressed() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

### Pattern B: Autoload pause manager

Use an autoload with `PROCESS_MODE_ALWAYS` that owns the pause state, to avoid coupling pause to any particular scene:

```gdscript
extends CanvasLayer

class_name PauseManager

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    hide()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        toggle()

func toggle() -> void:
    if get_tree().paused:
        hide()
        get_tree().paused = false
    else:
        show()
        get_tree().paused = true
    get_viewport().set_input_as_handled()
```

Note: This uses `PROCESS_MODE_ALWAYS` which means `_unhandled_input` runs even when unpaused. Use `get_viewport().set_input_as_handled()` to prevent the event from propagating to game logic.

### Pattern C: WITHIN the game scene with a Control child

Simplest for small projects — embed the pause UI directly in the main scene:

```gdscript
# In main.gd
@onready var pause_overlay: Control = %PauseOverlay

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if get_tree().paused:
            pause_overlay.hide()
            get_tree().paused = false
        else:
            pause_overlay.show()
            get_tree().paused = true
        get_viewport().set_input_as_handled()
```

Set `PauseOverlay.process_mode = PROCESS_MODE_WHEN_PAUSED` so buttons inside it work when paused.

---

## Code Snippet Examples

### Pause-safe SceneTreeTimer wrapper

```gdscript
static func delay(seconds: float) -> Signal:
    return get_tree().create_timer(seconds, false).timeout
```

### Pause-safe node child Timer

```gdscript
func start_cooldown(seconds: float) -> void:
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = seconds
    timer.process_callback = Timer.TIMER_PROCESS_PHYSICS  # pauses with tree
    add_child(timer)
    timer.start()
    await timer.timeout
    timer.queue_free()
```

### Re-enable physics for specific nodes (warning: janky)

```gdscript
# PhysicsServer2D can be kept active, but this affects ALL physics globally
PhysicsServer2D.set_active(true)
get_tree().paused = true
# Now _physics_process still runs on PROCESS_MODE_ALWAYS nodes,
# but collision detection may behave unexpectedly.
```

### Detecting pause state changes

```gdscript
func _notification(what: int) -> void:
    match what:
        NOTIFICATION_PAUSED:
            print("Paused")
        NOTIFICATION_UNPAUSED:
            print("Unpaused")
```

Note: Issue #83160 — `NOTIFICATION_PAUSED`/`NOTIFICATION_UNPAUSED` are **reversed** when `process_mode == WHEN_PAUSED`. The notification indicates "can I process?" not global pause state. On `PROCESS_MODE_ALWAYS`, these notifications are not received at all.

### Handling cursor capture during pause

```gdscript
func _on_pause() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    get_tree().paused = true

func _on_resume() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  # or HIDDEN
    get_tree().paused = false
```

---

## Limitations

| Limitation | Details |
|---|---|
| **Physics stops globally** | `get_tree().paused = true` shuts down the entire PhysicsServer2D/3D. Setting a node to `PROCESS_MODE_ALWAYS` does NOT keep its physics running. This is by design (confirmed in [#72974](https://github.com/godotengine/godot/issues/72974)). Works around: `PhysicsServer2D.set_active(true)`, but this is undocumented and may cause inconsistencies. |
| **Signals not paused** | Connected signal callbacks fire even on paused nodes, because signals bypass the process mode check. If a `Timer` node's `timeout` signal fires during pause, the connected function runs. Workaround: check `get_tree().is_paused()` at the top of signal handlers. |
| **AudioStreamPlayer quirks** | Audio does pause with the tree in Godot 4, but if `play()` is called from an unpaused node while the tree is paused, the audio starts playing ([#114694](https://github.com/godotengine/godot/issues/114694)). Also, re-adding an AudioStreamPlayer to the tree while paused can unpause the audio ([#83775](https://github.com/godotengine/godot/issues/83775)). |
| **SceneTreeTimer defaults to running while paused** | `get_tree().create_timer(1.0)` has `process_always = true` by default. You must pass `false`: `create_timer(1.0, false)`. Counter-intuitive and a common source of bugs. |
| **Buttons still show hover effects** | Mouse pointer events (`_gui_input`) are not disabled by pausing. Buttons react to hover visually even when paused, though they cannot be clicked. Workaround: add a transparent `ColorRect` mouse trap on top of the game layer. |
| **SubViewport input blocked** | Descendants of `SubViewport` may not receive `_input` even with `process_mode = ALWAYS` during pause. Workaround: set `SubViewportContainer.process_mode = PROCESS_MODE_ALWAYS`. |
| **Autoload inspector settings ignored when autoloading scripts** | If you autoload a `.gd` script (not a `.tscn` scene), the `process_mode` set in the inspector is lost. Always autoload a scene file if you need custom process mode on an autoload. Or set process_mode in `_ready()`. |
| **NOTIFICATION_PAUSED/UNPAUSED reversed for WHEN_PAUSED** | When `process_mode == WHEN_PAUSED`, `NOTIFICATION_PAUSED` fires on *unpause* and vice versa. Not received at all on `ALWAYS`. See [#83160](https://github.com/godotengine/godot/issues/83160). |

---

## Alternatives

### 1. Manual pause variable (full control)

Ignore the built-in system entirely. Add a `var paused: bool` to your game manager. Every `_process`/`_physics_process` checks it:

```gdscript
func _process(delta: float) -> void:
    if Global.paused:
        return
    # game logic
```

**Pros**: Full control over what pauses. Physics continues normally. **Cons**: Boilerplate, easy to forget a check, no built-in auto-pause of animations/audio/timers.

### 2. Group-based pause

Add nodes to a "pausable" group and toggle their `process_mode` manually:

```gdscript
func set_paused(paused: bool) -> void:
    for node in get_tree().get_nodes_in_group("pausable"):
        node.process_mode = PROCESS_MODE_DISABLED if paused else PROCESS_MODE_INHERIT
```

**Pros**: Selective pausing per group. **Cons**: Does not stop physics. Manual management.

### 3. Separate pause scene with change_scene_to_file

Switch to a dedicated pause scene instead of overlaying:

```gdscript
func _on_pause() -> void:
    get_tree().paused = true
    get_tree().change_scene_to_file("res://scenes/pause_menu.tscn")
```

**Pros**: Clean separation. **Cons**: Scene transition cost, lose game state visibility, more complex resume.

### 4. Tween-based timer replacement

Use `create_tween()` with `set_loops()` instead of `SceneTreeTimer` for pause-safe delays:

```gdscript
func delayed_action(delay: float) -> void:
    await create_tween().tween_callback(func(): pass).set_delay(delay).finished
```

Tweens pause correctly with the tree and respect node process mode.
