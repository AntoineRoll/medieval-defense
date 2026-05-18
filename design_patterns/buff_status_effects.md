# Buff / Status Effect System — Godot 4 Research

## References

- **OctoD/godot_gameplay_attributes** — C++ GDExtension addon (98 stars), attribute container with buff lifecycle (instant/timed/stacking/unique). Inspired by Unreal Engine's GAS.  
  https://github.com/OctoD/godot_gameplay_attributes

- **GDQuest Godot Open RPG** — Turn-based RPG demo. `StatusEffectContainer` node-based approach; effects are scene children with `expire()` cleanup.  
  https://github.com/gdquest-demos/godot-open-rpg

- **csprance/gecs** — Entity Component System for Godot 4 (506 stars). Queries entities by components, support for relationships and observers. Useful if building ECS-style effect architecture.  
  https://github.com/csprance/gecs

- **Pandora+ (trobugno/pandora_plus)** — RPG data management addon with `PPRuntimeStats`, `PPStatModifier` (percent/flat, temporary/permanent), serialization.  
  https://github.com/trobugno/pandora_plus

- **Minoqi — Modular Stat/Attribute System (Medium)** — Resource-based `Stat.gd` + `TempStatManager` Node with `_process` delta-tracking for duration. Clean additive/multiplicative modifier types.  
  https://medium.com/@minoqi/modular-stat-attribute-system-tutorial-for-godot-4-0bac1c5062ce

- **Godot Tactics RPG — 16. Status Effects (The Liquid Fire)** — Effect + Condition split architecture. `Status` manager node filters existing effects, adds conditions as children, auto-cleans when conditions empty.  
  https://theliquidfire.com/2025/07/21/godot-tactics-rpg-16-status-effects/

- **CodingDino — BuffList dirty-flag pattern (Gist)** — C# but pattern-agnostic: `BuffDuplicateAction` enum (DUPLICATE/STACK_AND_REFRESH/STACK/REFRESH/NO_DUPLICATES), `MarkDirty()` triggered recalculation, `OnEntityDeath` → `RemoveAllBuffs()`.  
  https://gist.github.com/CodingDino/200642f83f5bc51ab2146c7192cc2fe0

- **Godot 4 Timer docs** — Timer node: `one_shot`, `autostart`, `process_callback` (physics vs idle), `ignore_time_scale`, `timeout` signal.  
  https://docs.godotengine.org/en/4.5/classes/class_timer.html

- **Godot Sprite Flash / Shader visual feedback** — `modulate` property for quick tint, shader `hit_timer` uniform for GPU-based damage flash, hue-shift shaders for elemental status.  
  https://gamedevacademy.org/godot-sprite-flash-tutorial / https://gdshader.com/shaders/26

- **All-Projectiles Modifier system** — Stackable/refreshable/unique buff validation callbacks per modifier instance.  
  https://oscarvezz.github.io/all-projectiles/1.0/tutorials/10-using-modifiers-as-buffs-and-debuffs.html

---

## Recommended Pattern

**Effect-as-Node child of StatusEffectContainer** on the entity, paired with **Resource-based StatModifier** objects for data.

### Architecture layers

```
Entity (Unit/Enemy/Building)
  └─ StatusEffectContainer (Node)
       ├─ StatusEffect (Node) — "Poison" (duration, tick timer)
       │    └─ StatModifier (Resource) — { stat: "health_regen", value: -5, type: FLAT }
       ├─ StatusEffect (Node) — "SpeedBoost" (duration, no tick)
       │    └─ StatModifier (Resource) — { stat: "move_speed", value: 1.5, type: MULTIPLY }
       └─ StatusEffect (Node) — "Stun" (duration, crowd control flag)
            └─ (no modifier, uses effect's `is_crowd_control` flag)
```

### Why this pattern

| Concern | Choice | Rationale |
|---|---|---|
| Stat data | `Resource` subclass | Serializable, reusable, editor-inspectable, no scene tree cost |
| Effect lifecycle | `Node` children | `_ready()`/`_exit_tree()` cleanup, Timer nodes as children, scene tree pausing |
| Duration tracking | Timer node per effect | `timeout` signal, one-shot mode, auto-cleanup, `ignore_time_scale` option |
| Stat recalculation | Dirty flag | Recalculate only when buffs added/removed, not every frame |
| Cleanup on death | `_exit_tree()` on container | Emit `effect_removed` signals, modifiers revoked automatically |

---

## Implementation Patterns

### 1. StatModifier Resource

```
StatModifier (Resource)
  ├─ stat_name: String        (e.g. "damage", "move_speed", "attack_speed")
  ├─ value: float             (e.g. 10.0 for flat, 1.5 for multiply)
  ├─ modifier_type: enum      (FLAT, PERCENT_ADD, MULTIPLY, OVERRIDE)
  └─ source_id: String        (unique identifier for removal: "potion_health", "sergeant_aura")
```

### 2. StatusEffect Node

```
StatusEffect (Node)
  ├─ effect_id: String        (unique: "poison", "speed_boost")
  ├─ duration: float          (seconds, 0 = instant)
  ├─ stack_rule: enum         (EXCLUSIVE, STACK_AND_REFRESH, REFRESH, INDEPENDENT)
  ├─ max_stacks: int
  ├─ current_stacks: int
  ├─ modifiers: Array[StatModifier]
  ├─ visual_tint: Color       (applied to entity sprite while active)
  ├─ is_crowd_control: bool   (stun, root, silence)
  ├─ tick_interval: float     (>0 for damage-over-time or heal-over-time)
  │
  ├─ Timer (child) — "DurationTimer"  (one_shot, wait_time = duration)
  ├─ Timer (child) — "TickTimer"      (optional, wait_time = tick_interval)
  │
  ├─ apply(entity) → applies modifiers, starts timers, applies tint
  ├─ remove() → revokes modifiers, stops timers, reverts tint, queue_free()
  └─ refresh() → resets DurationTimer, increments stack if stackable
```

### 3. StatusEffectContainer Node

```
StatusEffectContainer (Node)
  ├─ active_effects: Dictionary[String, Array[StatusEffect]]  (effect_id → instances)
  ├─ stats_ref: Stats Resource
  ├─ modifier_dirty: bool
  │
  ├─ add_effect(effect_data: StatusEffectResource) → StatusEffect instance
  │   • Check stack rules against existing effects
  │   • Create effect node, add as child, call apply()
  │   • Mark modifier_dirty = true
  │   • Emit effect_applied(effect)
  │
  ├─ remove_effect(effect_id: String)
  │   • Find effect by ID, call remove()
  │   • Mark modifier_dirty = true
  │   • Emit effect_removed(effect_id)
  │
  ├─ remove_all_effects()  (called on entity death)
  │   • Iterate children, call remove() on each
  │
  ├─ recalculate_stats()
  │   • Reset stats to base values
  │   • For each active effect: apply its modifiers to stats
  │   • Set modifier_dirty = false
  │
  ├─ has_effect(effect_id: String) → bool
  ├─ get_effect(effect_id: String) → StatusEffect
  ├─ is_crowd_controlled() → bool  (checks any active effect with is_crowd_control)
  │
  └─ _exit_tree():
      • Remove all effects without signals (entity dying)
      • Clear modifier dirty state
```

### 4. Stat calculation with modifiers

```
get_stat(stat_name) → float:
    base = base_stats[stat_name]
    
    # 1. Apply FLAT modifiers
    for mod in flat_modifiers_for(stat_name):
        result += mod.value
    
    # 2. Apply PERCENT_ADD modifiers
    for mod in percent_add_modifiers_for(stat_name):
        result += result * (mod.value / 100.0)
    
    # 3. Apply MULTIPLY modifiers (compounded)
    for mod in multiply_modifiers_for(stat_name):
        result *= mod.value
    
    # 4. Check for OVERRIDE (highest priority wins)
    override = get_override_modifier_for(stat_name)
    if override:
        result = override.value
    
    return result
```

### 5. Stacking rules

| Rule | Behavior |
|---|---|
| `EXCLUSIVE` | Only one instance allowed; new application does nothing (paladin aura) |
| `REFRESH` | Resets duration timer to full (invulnerability shield) |
| `STACK` | Adds stack counter, effect intensity scales with stacks (increased damage per stack) |
| `STACK_AND_REFRESH` | Add stack + reset duration timer (debuff reapplied by same source) |
| `INDEPENDENT` | Each instance runs its own timer separately (multiple arrows each with own poison timer) |
| `MAX_STACKS` | Hard cap on stack count; once reached, oldest instance might be replaced |

---

## Code Snippet Examples

### StatModifier resource

```gdscript
class_name StatModifier
extends Resource

enum Type { FLAT, PERCENT_ADD, MULTIPLY, OVERRIDE }

@export var stat_name: String
@export var value: float
@export var modifier_type: Type = Type.FLAT
@export var source_id: String
```

### StatusEffect node

```gdscript
class_name StatusEffect
extends Node

signal expired(effect_id: String)
signal ticked(effect_id: String, value: float)

enum StackRule { EXCLUSIVE, REFRESH, STACK, STACK_AND_REFRESH, INDEPENDENT }

@export var effect_id: String
@export var duration: float = 0.0
@export var stack_rule: StackRule = StackRule.EXCLUSIVE
@export var max_stacks: int = 1
@export var modifiers: Array[StatModifier]
@export var visual_tint: Color = Color.TRANSPARENT
@export var is_crowd_control: bool = false
@export var tick_interval: float = 0.0

var current_stacks: int = 1
var _entity: Node
var _duration_timer: Timer
var _tick_timer: Timer


func apply(entity: Node) -> void:
    _entity = entity
    _setup_duration_timer()
    if tick_interval > 0.0:
        _setup_tick_timer()
    _apply_visual()
    for mod in modifiers:
        _apply_modifier(mod)


func remove() -> void:
    _revert_visual()
    for mod in modifiers:
        _remove_modifier(mod)
    expired.emit(effect_id)
    queue_free()


func refresh() -> void:
    if _duration_timer:
        _duration_timer.start(duration)


func _setup_duration_timer() -> void:
    if duration <= 0.0:
        return
    _duration_timer = Timer.new()
    _duration_timer.one_shot = true
    _duration_timer.wait_time = duration
    _duration_timer.timeout.connect(_on_duration_end)
    add_child(_duration_timer)
    _duration_timer.start()


func _setup_tick_timer() -> void:
    _tick_timer = Timer.new()
    _tick_timer.wait_time = tick_interval
    _tick_timer.timeout.connect(_on_tick)
    add_child(_tick_timer)
    _tick_timer.start()


func _on_duration_end() -> void:
    remove()


func _on_tick() -> void:
    ticked.emit(effect_id, _get_tick_value())
    _process_tick_effect()


func _get_tick_value() -> float:
    var total: float = 0.0
    for mod in modifiers:
        if mod.modifier_type == StatModifier.Type.FLAT:
            total += mod.value
    return total


func _process_tick_effect() -> void:
    pass


func _apply_modifier(mod: StatModifier) -> void:
    var container: StatusEffectContainer = _get_container()
    if container:
        container.add_modifier(mod)


func _remove_modifier(mod: StatModifier) -> void:
    var container: StatusEffectContainer = _get_container()
    if container:
        container.remove_modifier(mod.source_id)


func _apply_visual() -> void:
    if visual_tint == Color.TRANSPARENT or not _entity.has_node("Sprite2D"):
        return
    var sprite: Sprite2D = _entity.get_node("Sprite2D")
    sprite.modulate = visual_tint


func _revert_visual() -> void:
    if visual_tint == Color.TRANSPARENT or not _entity.has_node("Sprite2D"):
        return
    var sprite: Sprite2D = _entity.get_node("Sprite2D")
    sprite.modulate = Color.WHITE


func _get_container() -> StatusEffectContainer:
    var parent = get_parent()
    while parent:
        if parent is StatusEffectContainer:
            return parent
        parent = parent.get_parent()
    return null
```

### StatusEffectContainer node

```gdscript
class_name StatusEffectContainer
extends Node

signal effect_applied(effect: StatusEffect)
signal effect_removed(effect_id: String)
signal stats_changed


@export var stats: Resource  # Your Stats resource

var modifier_dirty: bool = false
var _flat_modifiers: Dictionary = {}       # stat_name → Array[{value, source_id}]
var _percent_modifiers: Dictionary = {}    # stat_name → Array[{value, source_id}]
var _multiply_modifiers: Dictionary = {}   # stat_name → Array[{value, source_id}]


func add_effect(effect_data: StatusEffect) -> StatusEffect:
    var existing: Array[StatusEffect] = _find_effects(effect_data.effect_id)

    if not existing.is_empty():
        match existing[0].stack_rule:
            StatusEffect.StackRule.EXCLUSIVE:
                return existing[0]
            StatusEffect.StackRule.REFRESH:
                existing[0].refresh()
                return existing[0]
            StatusEffect.StackRule.STACK:
                if existing[0].current_stacks < existing[0].max_stacks:
                    existing[0].current_stacks += 1
                return existing[0]
            StatusEffect.StackRule.STACK_AND_REFRESH:
                if existing[0].current_stacks < existing[0].max_stacks:
                    existing[0].current_stacks += 1
                existing[0].refresh()
                return existing[0]
            StatusEffect.StackRule.INDEPENDENT:
                pass  # fall through to create new instance

    var effect := effect_data.duplicate()
    effect.apply(get_parent())
    add_child(effect)
    mark_dirty()
    effect_applied.emit(effect)
    return effect


func remove_effect(effect_id: String) -> void:
    var effects: Array[StatusEffect] = _find_effects(effect_id)
    for effect in effects:
        effect.remove()
    if not effects.is_empty():
        mark_dirty()
        effect_removed.emit(effect_id)


func remove_all_effects() -> void:
    for child in get_children():
        if child is StatusEffect:
            child.remove()
    clear_modifiers()
    mark_dirty()


func has_effect(effect_id: String) -> bool:
    return not _find_effects(effect_id).is_empty()


func get_effect(effect_id: String) -> StatusEffect:
    var effects := _find_effects(effect_id)
    return effects[0] if not effects.is_empty() else null


func is_crowd_controlled() -> bool:
    for child in get_children():
        if child is StatusEffect and child.is_crowd_control:
            return true
    return false


func add_modifier(mod: StatModifier) -> void:
    match mod.modifier_type:
        StatModifier.Type.FLAT:
            _add_to_dict(_flat_modifiers, mod.stat_name, {"value": mod.value, "source_id": mod.source_id})
        StatModifier.Type.PERCENT_ADD:
            _add_to_dict(_percent_modifiers, mod.stat_name, {"value": mod.value, "source_id": mod.source_id})
        StatModifier.Type.MULTIPLY:
            _add_to_dict(_multiply_modifiers, mod.stat_name, {"value": mod.value, "source_id": mod.source_id})
    mark_dirty()


func remove_modifier(source_id: String) -> void:
    var removed := false
    for dict in [_flat_modifiers, _percent_modifiers, _multiply_modifiers]:
        for stat_name in dict.keys():
            var arr: Array = dict[stat_name]
            arr = arr.filter(func(entry): return entry.source_id != source_id)
            if arr.is_empty():
                dict.erase(stat_name)
            else:
                dict[stat_name] = arr
            removed = true
    if removed:
        mark_dirty()


func clear_modifiers() -> void:
    _flat_modifiers.clear()
    _percent_modifiers.clear()
    _multiply_modifiers.clear()


func mark_dirty() -> void:
    modifier_dirty = true
    stats_changed.emit()


func get_modified_value(stat_name: String, base_value: float) -> float:
    var result := base_value

    if _flat_modifiers.has(stat_name):
        for entry in _flat_modifiers[stat_name]:
            result += entry.value

    if _percent_modifiers.has(stat_name):
        for entry in _percent_modifiers[stat_name]:
            result += result * (entry.value / 100.0)

    if _multiply_modifiers.has(stat_name):
        for entry in _multiply_modifiers[stat_name]:
            result *= entry.value

    return result


func _find_effects(effect_id: String) -> Array[StatusEffect]:
    var result: Array[StatusEffect] = []
    for child in get_children():
        if child is StatusEffect and child.effect_id == effect_id:
            result.append(child)
    return result


func _add_to_dict(dict: Dictionary, key: String, entry: Dictionary) -> void:
    if not dict.has(key):
        dict[key] = []
    dict[key].append(entry)
```

### Entity death cleanup

```gdscript
# In entity base class (unit.gd, enemy.gd, etc.)
func _on_health_depleted() -> void:
    var container: StatusEffectContainer = $StatusEffectContainer
    if container:
        container.remove_all_effects()
    queue_free()
```

### Visual feedback with shader material

```gdshader
// flash_tint_2d.gdshader
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 0.5);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = mix(tex, flash_color, flash_amount);
}
```

```gdscript
# Controlled from StatusEffect:
func _apply_visual_shader(color: Color) -> void:
    var material: ShaderMaterial = sprite.material
    if not material:
        material = ShaderMaterial.new()
        material.shader = preload("res://shaders/flash_tint_2d.gdshader")
        sprite.material = material
    material.set_shader_parameter("flash_color", color)
    material.set_shader_parameter("flash_amount", 1.0)
```

---

## Limitations

| Limitation | Detail | Mitigation |
|---|---|---|
| Node overhead per effect | Each StatusEffect is a Node; hundreds of simultaneous effects could slow scene tree | Pool effect nodes; use `RESOURCE` + manual timer tracking for high-volume effects (DoT tick per arrow) |
| Resource `duplicate()` sharing | `Resource.duplicate()` creates independent copies; forgetting it mutates shared data | Always `duplicate()` before applying; or make StatModifier immutable |
| Timer node accuracy | Timer may miss frames at very low FPS or very short wait times (<0.05s) | Use `_process(delta)` accumulation for sub-50ms effects; `Engine.time_scale` affects timers |
| No built-in effect priority | Multiple crowd-control effects could each think they control the entity | `is_crowd_controlled()` returns bool; hard-coded priority per CC type (stun > root > slow) |
| Serialization complexity | Saving/loading active effects with remaining durations requires manual tracking | Store `{effect_id, remaining_time, stacks}` in save data; reconstruct on load |
| Network replication | No built-in RPC for effect state across peers | Add `rpc("apply_effect", ...)` / `rpc("remove_effect", ...)` on the container |
| Modifier order dependence | FLAT → PERCENT_ADD → MULTIPLY order changes final value | Document order; consider priority system like Unreal GAS (override > multiply > add > base) |

---

## Alternatives

### A. Godot Gameplay Attributes (GDExtension)
- **When to use**: Large project, need for editor-inspected attribute sets, C++ performance
- **Trade-off**: Requires compiled GDExtension, couples to C++ extension ecosystem
- **Source**: https://github.com/OctoD/godot_gameplay_attributes

### B. Pandora+ (addon)
- **When to use**: Need full RPG data management (stats + items + abilities) in one system
- **Trade-off**: Heavier dependency, Pandora+ specific API
- **Source**: https://github.com/trobugno/pandora_plus

### C. ECS approach (gecs / godot-ecs)
- **When to use**: Many entity types with complex cross-cutting effect queries; data-oriented design
- **Trade-off**: Overhead of ECS framework, less intuitive for small/medium projects
- **Source**: https://github.com/csprance/gecs

### D. No container — direct stat modification in scripts
- **When to use**: Simple project with few effects, no stacking needed
- **Trade-off**: Manual tracking, no reuse, no visual feedback system, bugs from forgotten removal
- **Pattern**: `entity.stats.damage += 10` + `await get_tree().create_timer(5.0).timeout` + `entity.stats.damage -= 10`

### E. Effect-as-signal (event-driven, no nodes)
- **When to use**: Effects that don't need timers (instant modifiers like equipment)
- **Trade-off**: No duration management, no visual feedback tie-in
- **Pattern**: `EventBus.effect_applied.emit(source_id, stat_modifiers)` → stats recalculate via signals

### F. Effect-as-Resource with manual Timer Node tracking
- **When to use**: Minimize scene tree node count while keeping duration logic
- **Trade-off**: Must manually update timers in `_process`, no auto `_exit_tree()` cleanup
- **Pattern**: Single Timer + array of active effect resources, `_process(delta)` decrements remaining times

### G. Dirty flag with lazy recalculation (CodingDino pattern)
- **When to use**: Stat recalculation is expensive (many derived stats)
- **Trade-off**: Extra complexity; need to ensure dirty flag consumed before next stat read
- **Pattern**: `mark_dirty()` sets bool → `_process` or getter checks dirty → rebuild modifiers → clear dirty
