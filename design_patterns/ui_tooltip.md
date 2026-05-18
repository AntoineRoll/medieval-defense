# UI Tooltip System — Godot 4

## References

- [Godot Control docs: `tooltip_text`, `_get_tooltip()`, `_make_custom_tooltip()`](https://docs.godotengine.org/en/stable/classes/class_control.html)
- [Godot 4.4+ `_make_custom_tooltip()` called even when tooltip text is empty](https://github.com/godotengine/godot/pull/97961) (merged in 4.4)
- [TooltipPanel / TooltipLabel theme types](https://github.com/godotengine/godot/pull/43280)
- [RichTextLabel BBCode reference — `[color]`, `[img]`, `[hint]`, etc.](https://docs.godotengine.org/en/stable/tutorials/gui/bbcode_in_richtextlabel.html)
- [Custom tooltip project setting proposal (Godot 4.5+)](https://github.com/godotengine/godot/pull/111232)
- [tooltips-pro: Advanced Godot 4.4+ tooltip plugin](https://github.com/hewplayfair/tooltips-pro)
- [Control signals: `mouse_entered`, `mouse_exited`, `NOTIFICATION_MOUSE_ENTER`](https://docs.godotengine.org/en/stable/classes/class_control.html#signal-mouse_entered)
- [`gui/timers/tooltip_delay_sec` project setting](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)
- [Known limitation: RichTextLabel `fit_content` sizing in tooltips](https://github.com/godotengine/godot/issues/79429)
- [Known issue: tooltip flickers/reappears when `tooltip_text` changes](https://github.com/godotengine/godot/issues/90604)

---

## Recommended Pattern

**Use `_make_custom_tooltip(for_text: String)` with a pre-made tooltip scene loaded via `preload()`.**

This is the official, built-in approach and handles show/hide timing, delay, and automatic cleanup. The project setting `gui/timers/tooltip_delay_sec` controls the hover delay globally.

For richer tooltips (icons, colored text, stat blocks) return a packed scene instance whose root is a `Control` (e.g. `VBoxContainer`, `MarginContainer`) containing child `RichTextLabel`, `TextureRect`, etc.

**Avoid manual `mouse_entered`/`mouse_exited` + `Popup` for simple UI tooltips** — that duplicates engine logic and requires manual positioning, sizing, and lifecycle management. Reserve manual approach for world-space entities (hovering over a unit in the game world, not UI).

---

## Implementation Patterns

### Pattern A: Engine-default with theme styling (simplest)

Set `tooltip_text` on any Control. Theme the `TooltipPanel` (StyleBox) and `TooltipLabel` (Font/Color) via a Theme resource to change appearance globally.

### Pattern B: `_make_custom_tooltip()` returning a packed scene (recommended)

1. Create a scene (e.g. `ui/tooltip.tscn`) with a `Control` root and child nodes for content.
2. `preload()` it in the Control script; override `_make_custom_tooltip()`.
3. Instantiate, configure, return with `visible = true`.

```gdscript
# Attached to the button/icon that shows the tooltip
extends TextureButton

const TooltipScene = preload("res://ui/tooltip.tscn")

func _make_custom_tooltip(for_text: String) -> Control:
    if for_text.is_empty():
        return null  # don't show empty tooltip (for < 4.4 compat)
    var tip := TooltipScene.instantiate()
    tip.get_node("%NameLabel").text = for_text
    return tip
```

### Pattern C: Encapsulated tooltip scene with a setup method

Same as B but the tooltip scene's root script has a `setup(data: Dictionary)` method, keeping the calling node clean.

```gdscript
# ui/unit_tooltip.gd (root script of tooltip scene)
extends VBoxContainer

@onready var name_label: Label = %NameLabel
@onready var icon: TextureRect = %Icon
@onready var desc: RichTextLabel = %Description

func setup(data: Dictionary) -> void:
    name_label.text = data.get("name", "")
    icon.texture = data.get("icon", null)
    desc.text = data.get("description", "")
```

### Pattern D: Manual tooltip for world-space / 2D entities

Use a single `PopupPanel` (or `Control` with high Z-index) managed by a singleton or dedicated node. Show/hide via `mouse_entered`/`mouse_exited` on `Area2D` or `CollisionObject2D`. Position using `get_global_mouse_position()` each frame.

---

## Code Snippet Examples

### Rich tooltip with BBCode and icon

```gdscript
# ui/unit_tooltip.gd
extends VBoxContainer

@onready var icon: TextureRect = %Icon
@onready var rtl: RichTextLabel = %RichTextLabel

func setup(data: Dictionary) -> void:
    icon.texture = data.get("icon")
    # "HP: [color=green]100[/color]\nDMG: [color=red]10[/color]"
    rtl.text = data.get("bbcode_text")
```

### Delayed tooltip via engine (no code needed)

Set `ProjectSettings > gui > timers > tooltip_delay_sec` to desired seconds (default 0.5). The engine handles the timer — `_make_custom_tooltip()` is called automatically after the delay.

### Clamping to screen edge

Engine does this automatically for default tooltips (fixed in Godot 4.0+, PR #67046). For manual implementations, clamp manually:

```gdscript
var viewport_size := get_viewport_rect().size
popup.position = mouse_pos
popup.position.x = clamp(popup.position.x, 0, viewport_size.x - popup.size.x)
popup.position.y = clamp(popup.position.y, 0, viewport_size.y - popup.size.y)
```

### World-space entity tooltip (2D)

```gdscript
extends Area2D  # attach to unit root

@onready var tooltip_layer: Control = get_node("/root/Main/TooltipLayer")
@onready var tooltip_scene: PackedScene = preload("res://ui/unit_tooltip.tscn")

var _current_tip: Control = null

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
    _current_tip = tooltip_scene.instantiate()
    _current_tip.setup({"name": "Foot Soldier", "hp": 100, "dmg": 10})
    tooltip_layer.add_child(_current_tip)
    # start a Timer for delay if desired

func _process(_delta: float) -> void:
    if _current_tip and _current_tip.visible:
        var mpos := get_global_mouse_position()
        _current_tip.position = mpos + Vector2(16, 16)

func _on_mouse_exited() -> void:
    if is_instance_valid(_current_tip):
        _current_tip.queue_free()
        _current_tip = null
```

### Tooltip with RichTextLabel sizing fix

RichTextLabel in tooltips often returns `(0,0)` for `get_content_width/height` at construction time. Fix by setting a minimum width or turning off autowrap:

```gdscript
func _make_custom_tooltip(for_text: String) -> Control:
    var rtl := RichTextLabel.new()
    rtl.fit_content = true
    rtl.custom_minimum_size.x = 200      # constrains width, grows height
    rtl.text = for_text
    return rtl
```

Or for dynamic sizing, connect to `finished` signal:

```gdscript
var _rtl: RichTextLabel

func _make_custom_tooltip(for_text: String) -> Control:
    _rtl = RichTextLabel.new()
    _rtl.fit_content = true
    _rtl.finished.connect(_on_tooltip_finished)
    _rtl.text = for_text
    return _rtl

func _on_tooltip_finished() -> void:
    if is_instance_valid(_rtl):
        _rtl.custom_minimum_size = Vector2(_rtl.get_content_width(), _rtl.get_content_height())
```

---

## Limitations

| Limitation | Detail |
|---|---|
| `_make_custom_tooltip()` returns a new instance each call | Node is freed on hide — no reusing. Use `duplicate()` of a template if performance matters. |
| RichTextLabel sizing at construction | `get_content_width()` returns 0 until the label processes its text. Must use `finished` signal or set fixed `custom_minimum_size.x`. |
| Tooltip disappears when `tooltip_text` changes | Engine resets the tooltip if `tooltip_text` is modified mid-hover (intended). Workaround: use `_make_custom_tooltip` and ignore `for_text`, updating the returned node directly. |
| No per-node delay | `gui/timers/tooltip_delay_sec` is global; a manual timer per node is needed for per-node delays. |
| `TooltipPanel` fixed as `PopupPanel` | Custom tooltip root is always wrapped in a `PopupPanel` — you cannot return a `Window`-derived node. |
| Transparent background | `TooltipPanel` background may not be transparent in multi-window mode unless `transparent_bg` is enabled on the popup. |
| Godot < 4.4: empty `tooltip_text` skips `_make_custom_tooltip()` | In 4.4+, the custom method is always called. For earlier versions, set a non-empty `tooltip_text`. |
| No nesting without manual system | Default tooltips disappear when mouse leaves the source Control. For nested/recursive tooltips, a plugin like tooltips-pro is needed. |

---

## Alternatives

| Alternative | When to use |
|---|---|
| **Theme styling (TooltipPanel/TooltipLabel)** | Simple text-only tooltips with consistent appearance across the project. Zero script needed. |
| **`_make_custom_tooltip()` + PackedScene** (Pattern B/C) | Rich tooltips with icons, colored text, multiple fields. Best balance of engine integration and customization. |
| **Manual `Popup` + `mouse_entered`/`mouse_exited`** | World-space entities (2D/3D) where the source is not a Control node. Full positioning control. |
| **CanvasLayer overlay singleton** | Game-wide tooltips that must appear above all UI layers regardless of scene tree. |
| **tooltips-pro plugin** | Nested tooltips, pinning, 2D/3D support, animations, rich templating. Use when requirements exceed what `_make_custom_tooltip()` can provide. |
| **`[hint]` BBCode tag in RichTextLabel** | Inline tooltips on specific text spans within a RichTextLabel (e.g. glossary terms). No custom scripting needed. |
