# Debug Visualization in Godot 4

## References

- **Custom drawing in 2D (Godot docs):** https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html
- **Overview of debugging tools:** https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html
- **Performance singleton (Godot docs):** https://docs.godotengine.org/en/stable/classes/class_performance.html
- **Custom performance monitors:** https://docs.godotengine.org/en/4.2/tutorials/scripting/debug/custom_performance_monitors.html
- **CanvasLayer (Godot docs):** https://docs.godotengine.org/en/latest/classes/class_canvaslayer.html
- **Displaying debug data (KidsCanCode):** https://kidscancode.org/godot_recipes/4.x/ui/debug_overlay/index.html
- **CanvasItem._draw() (Godot docs):** https://docs.godotengine.org/en/latest/classes/class_canvasitem.html#class-canvasitem-private-method-draw
- **2D coordinate systems & transforms:** https://docs.godotengine.org/en/4.5/tutorials/2d/2d_transforms.html
- **Debug drawing utility (C++ GDExtension):** https://github.com/DmitriySalnikov/godot_debug_draw_3d
- **godot-debugdraw2d addon:** https://github.com/idbrii/godot-debugdraw2d
- **Godot Debug Menu addon:** https://github.com/godot-extended-libraries/godot-debug-menu
- **ScreenDebug plugin:** https://github.com/Saulo-de-Souza/Screen-Debug

## Recommended Pattern

Use a **dedicated `DebugManager` autoload** as the central hub for all debug visualization. It owns:
- A **`CanvasLayer` at layer 128** (above all gameplay) for screen-space overlay text and stats.
- A **`Node2D` child** inside that `CanvasLayer` that overrides `_draw()` for all shape-based debug primitives (hitboxes, detection rings, paths).
- A **boolean flag** (`debug_enabled`) to toggle all drawing; expose a keybind to flip it at runtime.
- A **per-node registration system**: nodes call `DebugManager.register(self, "hitbox_radius")` and the manager draws their debug shapes each frame.

All debug nodes live under the autoload scene tree, not in the main game scene. Toggle `CanvasLayer.visible` to hide everything at once.

## Implementation Patterns

### 1. DebugManager Autoload (scene structure)

```
res://debug/debug_manager.tscn  →  autoload name "DebugManager"
  └── CanvasLayer (layer: 128, visible: true)
      ├── DebugShapes (Node2D, handles _draw())
      └── DebugStats (MarginContainer → VBoxContainer → Labels)
```

- `DebugShapes._draw()` calls `queue_redraw()` every frame from `_process()`.
- `DebugStats` is a separate scene with a `MarginContainer` root, populated dynamically.

### 2. Shape Drawing (hitboxes, detection ranges)

- Override `_draw()` on a `Node2D` that lives under the `CanvasLayer`.
- Call `queue_redraw()` in `_process()` for continuous updates (performance cost is acceptable for debug-only).
- Use `draw_circle(center, radius, color)` for circular hitboxes/detection rings.
- Use `draw_arc(center, radius, start_angle, end_angle, segments, color, width)` for partial arcs (e.g. 180-front-facing detection cones).
- Use `draw_rect(rect, color, filled)` for AABB hitboxes.
- Use `draw_line(from, to, color, width)` for paths or range indicators.
- Coordinates passed to `_draw()` are in the `CanvasItem`'s local space. Use `draw_set_transform(Vector2, rotation, scale)` to shift the draw origin, or compute positions in global screen coordinates via `get_viewport().get_canvas_transform()`.

### 3. Performance Stats Overlay

- Access `Performance.get_monitor(Performance.TIME_FPS)` for FPS.
- Access `Performance.get_monitor(Performance.TIME_PROCESS)` for frame time.
- Access `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` for draw calls.
- Access `Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)` for physics time.
- Access `Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)` for active physics bodies.
- Access `Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)` for collision pairs.
- Access `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` for total nodes.
- Register custom monitors via `Performance.add_custom_monitor("category/name", callable)`.
- Display values in `RichTextLabel` or `Label` nodes with mono fonts, updating every frame or every 0.5s.

### 4. Built-in Engine Debug Tools (no-code)

- **Debug > Visible Collision Shapes** — renders all `CollisionShape2D` / `CollisionShape3D` outlines at runtime.
- **Debug > Visible Navigation** — renders navigation meshes/polygons.
- **Debug > Debug CanvasItem Redraws** — flashes red when a canvas item is redrawn (useful for spotting wasteful `queue_redraw()` calls).
- **Project Settings > Debug > Shapes** — customize colors for collision/navigation debug shapes.

### 5. Conditional Compilation / Release Build Removal

- **Wrapping code in `if OS.is_debug_build()` or `if not Engine.is_editor_hint()`** prevents execution in release exports.
- **Export filter**: add `addons/debug*` or `res://debug/*` to the "Filters to exclude files" in your export preset to strip debug scenes/tools from release builds.
- **Autoload toggle**: disable the `DebugManager` autoload in `Project > Autoload` before exporting, or check a project setting at runtime.
- Custom export templates compiled with `target=template_release` strip most debug features.

## Code Snippet Examples

### DebugManager (simplified autoload)

```gdscript
extends CanvasLayer

var debug_enabled := true
var shapes_layer: Node2D
var stats_label: RichTextLabel

func _ready():
    layer = 128
    shapes_layer = Node2D.new()
    shapes_layer.name = "DebugShapes"
    add_child(shapes_layer)

    stats_label = RichTextLabel.new()
    stats_label.name = "StatsLabel"
    stats_label.anchors_preset = Control.PRESET_TOP_LEFT
    stats_label.position = Vector2(8, 8)
    add_child(stats_label)

func _process(_delta):
    if not debug_enabled:
        stats_label.text = ""
        return

    var fps = Performance.get_monitor(Performance.TIME_FPS)
    var frame_time = Performance.get_monitor(Performance.TIME_PROCESS)
    var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
    var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

    stats_label.text = "FPS: %d\nFrame: %.2f ms\nDraw: %d\nPhysics: %.2f ms\nNodes: %d" % [fps, frame_time * 1000, draw_calls, physics_time * 1000, nodes]

func toggle():
    debug_enabled = not debug_enabled
    visible = debug_enabled

func queue_shape_redraw():
    shapes_layer.queue_redraw()
```

### Debug Shapes Drawing (hitboxes + detection ranges)

```gdscript
extends Node2D

var registered: Array[Dictionary] = []

func _process(_delta):
    queue_redraw()

func _draw():
    for entry in registered:
        var node = entry.node
        if not is_instance_valid(node):
            continue
        var color = entry.color
        var hitbox_radius = entry.get("hitbox_radius", 0)
        var detection_radius = entry.get("detection_radius", 0)
        var global_pos = node.global_position

        # Detection ring (outer, hollow)
        if detection_radius > 0:
            draw_circle(global_pos, detection_radius, Color(color, 0.1))
            draw_arc(global_pos, detection_radius, 0, TAU, 64, Color(color, 0.4), 1.0)

        # Hitbox (inner, filled)
        if hitbox_radius > 0:
            draw_circle(global_pos, hitbox_radius, Color(color, 0.3))
            draw_arc(global_pos, hitbox_radius, 0, TAU, 32, Color(color, 0.7), 1.5)

func register(node: Node2D, hitbox_radius: float = 0, detection_radius: float = 0, color: Color = Color.YELLOW):
    registered.append({ "node": node, "hitbox_radius": hitbox_radius, "detection_radius": detection_radius, "color": color })

func unregister(node: Node2D):
    registered = registered.filter(func(e): return e.node != node)
```

### Toggle Debug Mode (in main.gd or any input handler)

```gdscript
func _unhandled_input(event: InputEvent):
    if event.is_action_pressed("toggle_debug"):
        DebugManager.toggle()
```

Add a `toggle_debug` action in Input Map (e.g. bound to F3).

### Conditional Execution (release-safe)

```gdscript
func show_debug_hitbox():
    if not OS.is_debug_build():
        return
    DebugManager.shapes.register(self, hitbox_radius, detection_radius)
```

## Limitations

1. **`_draw()` coordinate system** — draw commands use the `CanvasItem`'s local space. When the `DebugShapes` node is under a `CanvasLayer`, its origin is the top-left of the screen. You must pass global positions (e.g. `node.global_position`) directly unless you offset with `draw_set_transform()`.
2. **Performance overhead** — calling `queue_redraw()` every frame from `_process()` and iterating over many registered nodes adds CPU cost. Keep registrations minimal (tens, not hundreds). For many objects, batch into a single `_draw()` pass.
3. **No z-ordering within CanvasLayer** — all debug shapes draw at the same layer. For per-object draw ordering, use separate `CanvasLayer` instances or manage draw order manually within `_draw()`.
4. **`draw_circle()` is filled-only** — for outline-only circles, use `draw_arc()` with the full TAU range.
5. **Built-in collision shape debug (`Debug > Visible Collision Shapes`)** has known performance regressions (Godot 4.4+), and its appearance is affected by `rendering/2d/snap/snap_2d_transforms_to_pixel` which can cause visual misalignment with actual physics shapes.
6. **No built-in 2D debug draw API** — unlike Unity's `Debug.DrawLine` or Unreal's draw debug helpers, Godot has no engine-level immediate-mode 2D debug draw. You must use `_draw()` + `queue_redraw()`.

## Alternatives

| Approach | Pros | Cons |
|---|---|---|
| **Built-in Debug > Visible Collision Shapes** | Zero code, works with any CollisionShape2D | No control over colors, appearance; performance regression in 4.4+; no custom shapes |
| **Per-node `_draw()` on each unit/building** | Coordinates are local, no transform math | Scattered across many scripts, harder to toggle globally |
| **SubViewport overlay** | Separate rendering context, no interference with game view | More complex setup, extra rendering pass cost |
| **C++ GDExtension (DmitriySalnikov/godot_debug_draw_3d)** | Fast, feature-rich, immediate-mode API, 3D+2D | C++ dependency, compiled binary, 3D-focused |
| **GDScript addon (idbrii/godot-debugdraw2d)** | Plugin-based, immediate-mode 2D draw | Third-party dependency, may lag behind Godot versions |
| **godot-debug-menu addon** | Polished FPS/frametime overlay with graphs | Limited to performance stats, no hitbox/shape visualization |
| **ScreenDebug plugin** | Inspect any node's properties at runtime | Read-only property display, no custom shape drawing |
