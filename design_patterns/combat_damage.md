# Combat Damage System — Design Patterns & Research

## References

- **AoE2 Damage Formula**: `Damage = max(1, sum(max(0, Attack_i - Armor_i)) * elevation)` — additive flat armor classes with per-class attack bonuses. 36 damage classes (melee, pierce, cavalry, infantry, etc.). Units have multiple armor classes; each attack class is subtracted against its matching armor. Base armor = 1000 for unmatched classes. Source: ageofempires.fandom.com, aoe2database.com
- **Warcraft 3**: Normal/Pierce/Siege/Magic/Chaos damage vs. Unarmed/Light/Medium/Heavy/Fortitude/Hero armor. Multiplier table (e.g., Magic vs. Heavy = 2.0x, Pierce vs. Heavy = 1.0x, Siege vs. Fortitude = 1.5x). Each unit has one armor class.
- **Bestia (Ragnarok Online-derived)**: `Damage = floor(BASE_ATK * ATK_MOD * HARD_DEF_MOD * CRIT_MOD - SOFT_DEF)`. Multi-stage pipeline: base attack → weapon → size/race/element modifiers → hard defense % cap (0-95%) → crit → soft defense flat subtraction.
- **Last Epoch / PoE stacking model**: `(Base + Added) * (1 + sum(Increased)) * (1 + More_1) * (1 + More_2) * ...`. "Increased" = additive within category. "More" = multiplicative. Penetration = negative resistance.
- **Godot Combat Systems (the.divergent.ai)**: DamageData (RefCounted) + HealthComponent + Hitbox/Hurtbox Area2D pattern. Signals for decoupling. DamageData carries amount, source, damage_type, knockback, is_critical.
- **Hyperscape (OSRS-style)**: Tick-based (600ms), `MAX_HIT = floor((EFFECTIVE_LEVEL * (EQUIPMENT_BONUS + 64) + 320) / 640)`. Constants-driven formula. Equipment stats added to base skill levels.

## Recommended Pattern: Layered Damage Pipeline

For an RTS/tower-defense hybrid with RPS modifiers, use a **multiplicative modifier chain** with **data-driven type tables**. The pipeline should be:

```
1. Base Damage (unit weapon stat)
2. × RPS Type Multiplier   (attacker type vs. defender armor class)
3. × Buff/Debuff Multiplier (additive bucket: sum(all "increased damage" effects))
4. × "More" Multipliers     (separate multiplicative effects: crit, conditional bonuses)
5. - Flat Reduction         (armor as flat subtraction, minimum 0)
6. = Final Damage           (clamped to minimum 1)
```

### Data-Driven Type Advantage Table (RPS)

Use a Godot `Resource` subclass to hold the multiplier matrix:

```gdscript
# damage_table.gd
class_name DamageTable extends Resource

@export var entries: Array[TypeEntry] = []

func get_multiplier(attack_type: StringName, armor_class: StringName) -> float:
    for e in entries:
        if e.attack_type == attack_type and e.armor_class == armor_class:
            return e.multiplier
    return 1.0

# type_entry.gd
class_name TypeEntry extends Resource

@export var attack_type: StringName
@export var armor_class: StringName
@export var multiplier: float = 1.0
```

### AoE2-Inspired Armor Class System (Alternative)

Units have multiple armor classes (melee, pierce, cavalry, infantry, etc.). Attackers have attack values per class. Damage = sum of `max(0, attack_value_i - armor_value_i)` across all matching classes. This is **additive across classes**, not multiplicative.

```
Damage = max(1, sum over i of max(0, Attack_i - Armor_i))
```

Where `i` iterates every damage class the attacker has. If defender lacks an armor class, use a high default (1000). This naturally handles bonus damage (e.g., +15 cavalry attack vs. cavalry armor).

## Implementation Patterns

### Pattern 1: Pipeline with DamageData Object

```gdscript
# damage_pipeline.gd
class_name DamagePipeline extends RefCounted

static func resolve(
    attacker: Node,
    defender: Node,
    base_damage: float,
    attack_type: StringName
) -> DamageResult:
    var result := DamageResult.new()

    # Step 1: Base damage
    var damage := base_damage

    # Step 2: RPS type multiplier
    var armor_class := _get_armor_class(defender)
    var table := _load_damage_table()
    damage *= table.get_multiplier(attack_type, armor_class)

    # Step 3: Pre-damage event (buffs modify damage)
    var ctx := DamageContext.new(attacker, defender, damage, attack_type)
    EventBus.pre_damage.emit(ctx)
    damage = ctx.damage

    # Step 4: Flat armor reduction
    var armor := _get_armor(defender, attack_type)
    damage = maxf(damage - armor, 1.0)

    # Step 5: Critical hit
    var crit_chance := _get_crit_chance(attacker)
    if randf() < crit_chance:
        result.is_critical = true
        damage *= _get_crit_multiplier(attacker)

    result.final_damage = damage
    result.attack_type = attack_type

    # Step 6: Post-damage event
    EventBus.post_damage.emit(result)

    return result
```

### Pattern 2: Event-Driven Damage Bus

```gdscript
# event_bus.gd (Autoload singleton)
extends Node

signal pre_damage(ctx: DamageContext)
signal damage_dealt(result: DamageResult)
signal entity_died(entity: Node)

# damage_context.gd
class_name DamageContext extends RefCounted

var attacker: Node
var defender: Node
var damage: float
var attack_type: StringName

func _init(a: Node, d: Node, dmg: float, at: StringName) -> void:
    attacker = a; defender = d; damage = dmg; attack_type = at

# damage_result.gd
class_name DamageResult extends RefCounted

var final_damage: float
var attack_type: StringName
var is_critical: bool = false
var is_kill: bool = false
```

### Pattern 3: Data-Driven UnitStats with Modifiers

```gdscript
# unit_stats.gd (existing pattern extension)
extends Resource
class_name UnitStats

@export var base_damage: float = 10.0
@export var attack_type: StringName = &"melee"
@export var armor_class: StringName = &"light"
@export var armor: float = 0.0

# Runtime modifiers (not serialized)
var damage_mods: Array[DamageMod] = []

func get_effective_damage() -> float:
    var dmg := base_damage
    var increased_sum := 0.0
    var more_product := 1.0
    for mod in damage_mods:
        match mod.type:
            ModType.FLAT: dmg += mod.value
            ModType.INCREASED: increased_sum += mod.value
            ModType.MORE: more_product *= mod.value
    return dmg * (1.0 + increased_sum) * more_product
```

### Pattern 4: AoE2-Style Attack/Armor Class System

```gdscript
# attack_profile.gd
class_name AttackProfile extends Resource

@export var melee: float = 0.0
@export var pierce: float = 0.0
@export var bonus: Dictionary = {}  # armor_class_name: bonus_amount

# armor_profile.gd
class_name ArmorProfile extends Resource

@export var melee: float = 0.0
@export var pierce: float = 0.0
@export var armor_classes: Dictionary = {}  # class_name: armor_value

static func calculate(attack: AttackProfile, armor: ArmorProfile) -> float:
    var total := 0.0
    total += maxf(attack.melee - armor.melee, 0.0)
    total += maxf(attack.pierce - armor.pierce, 0.0)
    for class_name in attack.bonus:
        var a_val := armor.armor_classes.get(class_name, 1000.0)
        total += maxf(attack.bonus[class_name] - a_val, 0.0)
    return maxf(total, 1.0)
```

### Pattern 5: Damage Over Time (DoT)

```gdscript
# damage_over_time.gd
class_name DamageOverTime extends RefCounted

var total_damage: float
var duration: float
var tick_interval: float = 1.0
var damage_type: StringName
var owner: Node

var _elapsed: float = 0.0
var _ticks_done: int = 0

func _init(dmg: float, dur: float, type: StringName, source: Node) -> void:
    total_damage = dmg; duration = dur; damage_type = type; owner = source

func process(delta: float, target: Node) -> bool:
    _elapsed += delta
    var ticks_needed := int(_elapsed / tick_interval)
    var new_ticks := ticks_needed - _ticks_done
    if new_ticks > 0:
        var tick_damage := (total_damage / duration) * tick_interval * new_ticks
        var data := DamageData.new(tick_damage, owner)
        data.damage_type = damage_type
        target.take_damage(data)
        _ticks_done = ticks_needed
    return _elapsed < duration
```

### Pattern 6: Crit / Armor Penetration

```gdscript
static func apply_crit(damage: float, crit_chance: float, crit_mult: float) -> Dictionary:
    var is_crit := randf() < crit_chance
    return {
        "damage": damage * (crit_mult if is_crit else 1.0),
        "is_crit": is_crit
    }

static func apply_armor_pen(damage: float, armor: float, penetration: float) -> float:
    var effective_armor := maxf(armor - penetration, 0.0)
    return maxf(damage - effective_armor, 1.0)

# Diminishing returns formula (for %-based armor)
static func armor_to_multiplier(armor: float) -> float:
    return 1.0 - (armor / (armor + 100.0))

static func apply_percent_armor(damage: float, armor: float, pen_pct: float) -> float:
    var effective := maxf(armor * (1.0 - pen_pct), 0.0)
    return damage * (1.0 - effective / (effective + 100.0))
```

## Modifier Stacking Rules

| Category | Stacking | Example |
|----------|----------|---------|
| Flat (+X damage) | Additive within category | +5 damage from aura + +3 from banner = +8 |
| Increased % | Additive (summed) within category | +20% from buff + +15% from perk = +35% |
| More % | Multiplicative (each multiplies independently) | 1.5x × 1.3x = 1.95x |
| Resistances | Multiplicative with other layers | 100 damage × (1 - 0.3 armor) × (1 - 0.2 magic resist) |
| Armor Pen | Subtractive from armor before calculation | 30 pen vs 50 armor = effective 20 armor |

**Rule of thumb**: Increased bonuses saturate (diminishing returns per point). More bonuses are always full value. Mix categories to maximize.

## Limitations

- **AoE2 flat subtraction** can produce 0-damage edge cases (mitigated with `max(1, ...)`) and has no diminishing returns curve.
- **Pure multiplier tables (Warcraft 3)** give binary matchups — if your RPS ratio is too high (3x+), non-counter units feel worthless.
- **Multiplicative stacking** can lead to exponential damage scaling if too many "more" modifiers exist — requires discipline in design.
- **Damage pipeline complexity** grows with each new modifier type. Too many event listeners on pre_damage/post_damage makes debugging difficult.
- **RefCounted DamageData** cannot be serialized (save/load). Use Resource if persistence needed.
- **Resource-based damage tables** are shared instances — modifying at runtime affects all users. Use `duplicate()` for per-instance overrides.

## Alternatives

1. **Single flat formula** (`ATK - DEF`): Simplest, but breaks when ATK < DEF (0 damage) and has sharp scaling thresholds.
2. **Single multiplier formula** (`ATK / DEF * base`): Smooth scaling, weak attackers always deal some damage, but harder to balance.
3. **Damage threshold / stagger system**: Instead of HP reduction, use hit-count or stagger-state (e.g., 3 hits → staggered → 5 hits → defeated). No damage math, used in some action games.
4. **Dice-roll (D&D style)**: `(d20 + ATK mod) vs AC` → hit/miss then damage roll. More variance, less deterministic. Good for tactical games, poor for RTS simulations.
5. **PoE-style stat converter**: Nested stat pipeline (base → local mods → global mods → conversion → final). Most flexible but highest complexity.
6. **Scriptable per-ability formula (Strategy pattern)**: Each ability defines its own damage function. Maximum flexibility, minimum reuse.

For this project (medieval defense RTS with RPS between foot soldier/archer/cavalry), the **multiplicative modifier chain with data-driven RPS table** (Pattern 1) is recommended — it balances simplicity with extensibility, integrates naturally with the existing `UnitStats` Resource pattern, and supports buff/debuff effects through the event bus.
