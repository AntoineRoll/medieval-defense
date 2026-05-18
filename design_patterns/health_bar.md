# Health Bar

## References
- Godot 4.6 TextureProgressBar docs — Official API reference for texture-based progress bars (3 textures: under, progress, over; radial fill modes; nine-patch stretch) — https://docs.godotengine.org/en/4.6/classes/class_textureprogressbar.html
- Godot 4.6 ProgressBar docs — Official API reference for theme/StyleBox-based progress bar (lighter than TextureProgressBar, fewer features) — https://docs.godotengine.org/en/stable/classes/class_progressbar.html
- Godot 4.6 Range docs — Abstract base class inherited by both ProgressBar and TextureProgressBar (min_value, max_value, value, step, value_changed signal) — https://docs.godotengine.org/en/stable/classes/class_range.html
- Godot 4.6 CanvasLayer docs — Official docs for screen-space overlay rendering layer (used for HUD health bars) — https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html
- Godot 4.6 Custom Drawing in 2D — Official tutorial on overriding _draw() for custom CanvasItem rendering — https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html
- KidsCanCode 3D Unit Healthbars — SubViewport + Sprite3D pattern for rendering 2D health bars in 3D space (not needed for 2D games, but demonstrates the SubViewport technique) — https://kidscancode.org/godot_recipes/4.x/3d/healthbars/index.html
- gameidea.org tutorial — RTS health bar with TextureProgressBar, camera.unproject_position for 3D-to-screen mapping, distance-based scale — https://gameidea.org/2024/12/13/making-a-health-bar-and-health-system-in-godot/
- Dante's Lab tutorial — ProgressBar vs TextureProgressBar, SubViewport for 3D health bars, signal-based decoupled updates — https://www.dlab.ninja/2024/06/how-to-implement-health-bars-for.html
- GameDevAcademy guide — ProgressBar basics, normalized value (health / max_health) pattern, min/max/value usage — https://gamedevacademy.org/progressbar-in-godot-complete-guide
- godot-x/health-bar-x — Open-source shape-based health bar addon for Godot 4.5+ with HealthBarXControl (UI) and HealthBarX2D (world overlay), uses _draw() with vector shapes — https://github.com/godot-x/health-bar-x
- vi4hu/godot_health_bar_2d — Open-source addon extending TextureProgressBar with signal-based initialization pattern — https://github.com/vi4hu/godot_health_bar_2d
- LesusX/Progress-bar-shader — Shader-based progress bar with bar modes, fill modes, flash effects, segments — https://github.com/LesusX/Progress-bar-shader
- cluttered-code/godot-health-hitbox-hurtbox — Modular health component system with hitbox/hurtbox integration (decoupled from rendering) — https://github.com/cluttered-code/godot-health-hitbox-hurtbox
- I Love Sprites blog — Performance notes on 2D rendering: MultiMeshInstance2D for identical sprites, CanvasItem batching, atlas textures — https://ilovesprites.com/blog/godot-sprite-nuances-best-practices
- SlashSkill article — CharacterBody3D vs MultiMesh scaling analysis (relevant: per-node overhead with hundreds of entities) — https://www.slashskill.com/godot-4-characterbody3d-vs-multimesh-scaling-hundreds-of-units-without-killing-performance/

## Recommended Pattern

**TextureProgressBar as a child of the character's Node2D scene.**

For a 2D pixel-art game, this is the best general approach because:

1. Both the character (Node2D) and the health bar (Control → TextureProgressBar) exist in the same 2D coordinate system — the bar naturally follows the character in world space with zero extra positioning code.
2. TextureProgressBar accepts pixel-art textures (under, progress, over layers) which match the pixel art aesthetic.
3. It inherits from Range, giving free min/max/value clamping, step rounding, and the `value_changed` signal.
4. Nine-patch stretch allows the bar to resize cleanly without distortion.
5. Tint properties (tint_under, tint_progress, tint_over) enable color shifts (green → yellow → red) without swapping textures.

For screen-space bars (boss HP, player HUD), use CanvasLayer + TextureProgressBar anchored to the viewport.

For large-scale games (100+ entities requiring health bars simultaneously), consider the custom _draw() pattern to avoid Control node overhead.

## Implementation Patterns

### 1. TextureProgressBar (Child-of-Character)
Root node is TextureProgressBar, instanced as a child of the unit scene. Position offset above the character's head. Set min_value = 0, max_value = max_health, value = current health. Uses texture_under (background) and texture_progress (fill). Nine-patch stretch enables resizing.

### 2. ProgressBar (Theme-based)
Same parent-child relationship but uses StyleBoxFlat resources instead of textures. Lighter-weight setup but less visual control (no separate over texture, no radial fill, limited to 4 fill directions). Best for prototyping or minimal UI.

### 3. Custom _draw() on Node2D
Extend Node2D, override _draw() and call draw_rect() or draw_texture() with a computed fill width. Call queue_redraw() only when health changes (via signal or setter). Zero Control overhead. Best performance for large numbers of entities.

### 4. CanvasLayer Screen-Space Bar
Place TextureProgressBar/ProgressBar under a CanvasLayer. Anchor to viewport edges. Used for persistent HUD bars (player health, boss health) that should not move with the camera. Layer index > 0 renders above the game world.

### 5. SubViewport (3D projection)
Render a TextureProgressBar into a SubViewport, project the viewport texture onto a Sprite3D with billboard mode. Only needed for 3D games. Irrelevant for 2D.

### 6. Shader-based
A custom shader on a ColorRect or Sprite2D that clips based on a float uniform. Enables visual effects (wave, bubble, glitch, segment flash) but requires shader expertise. Overkill for basic health bars but useful for stylized/elaborate bars.

## Code Snippet Examples

### Pattern 1: TextureProgressBar as child of character

```gdscript
# health_bar.gd — attached to TextureProgressBar node
extends TextureProgressBar

@export var max_health: float = 100.0
@export var tint_green: Color = Color(0.2, 0.8, 0.2)
@export var tint_yellow: Color = Color(0.8, 0.8, 0.2)
@export var tint_red: Color = Color(0.8, 0.2, 0.2)

func _ready() -> void:
    min_value = 0.0
    max_value = max_health
    value = max_health

func update_health(current: float) -> void:
    value = current
    var ratio: float = current / max_health
    if ratio > 0.6:
        tint_progress = tint_green
    elif ratio > 0.3:
        tint_progress = tint_yellow
    else:
        tint_progress = tint_red
```

```gdscript
# unit.gd — the parent character
extends Node2D
@onready var health_bar: TextureProgressBar = %HealthBar

func take_damage(amount: float) -> void:
    health -= amount
    health_bar.update_health(health)
```

### Pattern 2: Signal-based decoupled bar

```gdscript
# health_component.gd — attached to character
extends Node
signal health_changed(current: float, max_val: float)

@export var max_health: float = 100.0
var health: float : set = set_health

func set_health(value: float) -> void:
    health = clampf(value, 0.0, max_health)
    health_changed.emit(health, max_health)
```

```gdscript
# health_bar.gd
extends TextureProgressBar

func _ready() -> void:
    var parent: Node = get_parent()
    if parent.has_signal("health_changed"):
        parent.health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max_val: float) -> void:
    max_value = max_val
    value = current
```

### Pattern 3: Custom _draw() bar for scale

```gdscript
# bar_2d.gd — lightweight Node2D health bar
extends Node2D
@export var bar_width: float = 32.0
@export var bar_height: float = 4.0
@export var color_fill: Color = Color.GREEN
@export var color_bg: Color = Color(0.2, 0.2, 0.2, 0.8)

var ratio: float = 1.0 : set = _set_ratio

func _set_ratio(value: float) -> void:
    ratio = clampf(value, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    var bg_rect := Rect2(Vector2.ZERO, Vector2(bar_width, bar_height))
    draw_rect(bg_rect, color_bg)
    var fill_rect := Rect2(Vector2.ZERO, Vector2(bar_width * ratio, bar_height))
    draw_rect(fill_rect, color_fill)
```

### Pattern 4: Screen-space HUD bar

```gdscript
# hud.gd — attached to CanvasLayer
extends CanvasLayer
@onready var health_bar: TextureProgressBar = %HealthBar

func _ready() -> void:
    # Anchor to bottom-center of screen
    health_bar.anchors_preset = Control.PRESET_CENTER_BOTTOM

func update_hud(current: float, max_val: float) -> void:
    health_bar.max_value = max_val
    health_bar.value = current
```

## Limitations

### TextureProgressBar child-of-character
- **Control node overhead**: Each TextureProgressBar is a full Control node with layout calculations. Beyond ~50-100 visible bars, frame time may increase on low-end hardware.
- **World-space attachment**: The bar inherits the character's transform (rotation, scale). You must compensate if the character flips or has non-uniform scale.
- **CanvasItem culling**: Bars off-screen are not rendered (Godot culls by Rect2), but their _process calls still run unless you manually check is_visible().
- **z-index ordering**: Control nodes draw on top of 2D nodes by default. You may need to manage draw order manually.

### ProgressBar (theme-based)
- **Limited fill modes**: Only 4 directions (left-to-right, right-to-left, top-to-bottom, bottom-to-top). No radial fill.
- **No texture support**: Styling is limited to StyleBox (solid colors, borders). Cannot use pixel-art textures without workarounds.
- **Heavier style computation**: StyleBoxFlat involves live border/radius calculations that can be costlier than a simple texture blit.

### Custom _draw() bar
- **No built-in Range features**: No min/max/value clamping, no step rounding, no value_changed signal. You implement everything.
- **Manual redraw management**: Must call queue_redraw() explicitly. Forgetting it produces stale visuals.
- **No theme inheritance**: Must hardcode colors/sizes or implement your own Resource-based config.
- **No accessibility**: Screen readers and UI navigation tools cannot interact with drawn shapes.

### CanvasLayer HUD bars
- **Fixed screen position**: Not suitable for per-entity floating bars. Boss/player bars only.
- **Multiple viewports**: In split-screen, each viewport needs its own CanvasLayer instance.

### Shader-based bars
- **No built-in interaction**: Cannot handle click events or mouse hover.
- **GPU cost**: Each unique shader material breaks the 2D batch. Complex fragment shaders on many entities hurt fill rate.
- **Maintenance**: Harder to debug, no visual editor support.

## Alternatives

- **SubViewport-per-bar**: Used in 3D games to project 2D UI into 3D space. For a pure 2D game this adds unnecessary complexity (extra viewport, texture copy per frame) with no benefit.
- **Single shared CanvasLayer with manual positioning**: Place one TextureProgressBar in a CanvasLayer and manually reposition it each frame to follow the selected unit. Works for a single selection indicator but breaks down when multiple entities need simultaneous bars.
- **MultiMeshInstance2D bar**: Render all identical bars as GPU-instanced sprites. Extremely fast but requires per-instance data (position, fill ratio) to be packed into a float array and uploaded each frame. Only practical when all bars share the same texture and you have many (200+) identical bars.
- **Third-party addon (health-bar-x)**: Uses _draw() with vector shapes (no textures required), provides both Control and Node2D variants, supports threshold colors, label, icon, tween animation. Good middle-ground between built-in nodes and custom _draw(). Adds a dependency.
- **Third-party addon (godot_health_bar_2d)**: Extends TextureProgressBar, signal-based initialization pattern. Simple but Godot 3-era codebase with limited updates.
