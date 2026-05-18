# Data-Driven Design with Godot 4 Resources

## References

- Godot 4.6 Resource docs: https://docs.godotengine.org/en/4.6/classes/class_resource.html
- Godot Resources tutorial: https://docs.godotengine.org/en/4.6/tutorials/scripting/resources.html
- ResourceLoader: https://docs.godotengine.org/en/4.6/classes/class_resourceloader.html
- ResourceSaver: https://docs.godotengine.org/en/4.6/classes/class_resourcesaver.html
- Logic preferences (preload vs load): https://docs.godotengine.org/en/4.6/tutorials/best_practices/logic_preferences.html
- Localization via CSV: https://docs.godotengine.org/en/4.6/tutorials/i18n/localization_using_spreadsheets.html
- GDScript Resources Cheat Sheet: https://www.syntaxcache.com/gdscript/cheatsheet/resources
- uhiyama-lab custom resource guide: https://uhiyama-lab.com/en/notes/godot/custom-resource-data-driven
- KidsCanCode guide: https://kidscancode.org/godot_recipes/4.x/basics/file_io
- Pandora (RPG data management): https://github.com/bitbrain/pandora
- DarthPapalo/ResourceDatabases: https://github.com/DarthPapalo/ResourceDatabases
- Gnumaru's static data importer: https://github.com/Gnumaru/GnumarusStaticDataImporter
- godot-gspreadsheet-importer: https://github.com/DanielSnd/godot-gspreadsheet-importer
- Shaggy Dev custom resources: https://shaggydev.com/2026/04/08/godot-custom-resources
- Snoeyz custom resources: https://godot.snoeyz.com/custom-resources
- Simon Dalvai custom resources: https://simondalvai.org/blog/godot-custom-resources

---

## Recommended Pattern: Custom Resources as Primary Data Container

Use Godot's built-in `Resource` system (`.tres` files) as the primary mechanism for data-driven configuration. It provides editor integration, type safety, automatic serialization, nested sub-resources, and reference counting — all out of the box.

### Decision Matrix

| Data Type | Format | Rationale |
|---|---|---|
| Unit stats, building configs, wave definitions | `.tres` custom Resources | Editor-inspector editable, type-safe, nested sub-resources |
| Game save data at runtime | `.res` (binary) via ResourceSaver | Faster load, smaller files, full Variant support |
| User-editable settings | ConfigFile | Simple INI-style, human-readable, supports defaults |
| External integration, web APIs, modding | JSON | Industry standard, portable, tools-friendly |
| Large tables (1000+ entries) | CSV → scripted import | Spreadsheet-native editing, bulk operations |
| Translation strings | CSV → Translation resource | Godot's built-in localization pipeline |
| Procedural/runtime-generated data | Dictionaries/JSON in `user://` | Lightweight, no Resource boilerplate needed |

---

## 1. Creating Custom Resource Scripts

Define a Resource subclass with `class_name` and `@export` fields:

```gdscript
# unit_stats.gd
extends Resource
class_name UnitStats

@export var display_name: String = ""
@export var max_hp: int = 100
@export var move_speed: float = 3.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 8.0
@export var detection_radius: float = 8.0
```

Create instances via `FileSystem → Create New → Resource → UnitStats`, save as `.tres`.

### Key Rules

- Use `class_name` to register the type globally
- Set default values at declaration, not in `_init()` — inspector values overwrite `_init()` defaults
- Every `_init()` parameter must have a default value
- Only `@export`ed properties are serialized by ResourceSaver
- Inner classes (`class` keyword) do NOT serialize as Resources — use separate files

---

## 2. Sub-Resource / Nested Resource Pattern

Compose complex data hierarchies by nesting typed Resource references:

```gdscript
# attack_stats.gd
extends Resource
class_name AttackStats

@export var damage: int = 10
@export var damage_type: String = "physical"
@export var attack_rate: float = 1.0
@export var projectile_scene: PackedScene

# unit_stats.gd
extends Resource
class_name UnitStats

@export var display_name: String = ""
@export var max_hp: int = 100
@export var move_speed: float = 3.0
@export var attack: AttackStats
@export var detection_radius: float = 8.0
@export var hitbox_radius: float = 8.0
```

Using typed `@export` ensures the inspector only accepts compatible Resource types. Nested Resources can be created inline as sub-resources or saved as separate `.tres` files and referenced.

---

## 3. Resource Inheritance

Create base Resource scripts and extend them for variants:

```gdscript
# base_unit_stats.gd
extends Resource
class_name BaseUnitStats

@export var display_name: String = "Unit"
@export var max_hp: int = 100
@export var move_speed: float = 3.0

# foot_soldier_stats.gd
extends BaseUnitStats
class_name FootSoldierStats

@export var shield_block_chance: float = 0.1
@export var melee_damage: int = 10

# archer_stats.gd
extends BaseUnitStats
class_name ArcherStats

@export var arrow_speed: float = 16.0
@export var ranged_damage: int = 8
```

Inheritance caveats:
- Resource files store the script path — inherited types resolve correctly at load time
- Dragging a child-type `.tres` onto a parent-type export slot works (verified in Godot 4.2+)
- Delete `.godot/global_script_class_cache.cfg` if inheritance breaks after script changes
- GDScript inner classes (`class` keyword) cannot be used as Resource types

### Godot 4 Resource State Inheritance (PR #86779)

Godot 4 has experimental resource inheritance (similar to scene inheritance) where a `.tres` file can reference a "base" resource and only store overridden properties. Available via `resource_inherits_state`. This is tracked but not yet stable — use script-level inheritance instead for production.

---

## 4. `.tres` vs `.res`

| | `.tres` (text) | `.res` (binary) |
|---|---|---|
| Human-readable | Yes | No |
| VCS-friendly diffs | Yes | No |
| Load speed | Slower | Faster |
| File size | Larger (~3-5x) | Smaller |
| Tamper resistance | Low | Low (but harder to edit) |
| Best use | Development, version control | Release builds, runtime saves |

Godot automatically converts `.tres` → `.res` on export if `ProjectSettings.editor/export/convert_text_resources_to_binary` is true (default). Use `.tres` during development and rely on export conversion for release.

---

## 5. ResourceSaver / ResourceLoader

### Saving at runtime

```gdscript
var stats := UnitStats.new()
stats.max_hp = 150
stats.move_speed = 4.0

var result := ResourceSaver.save(stats, "user://save_data/unit_01.tres")
if result != OK:
    push_error("Save failed: ", result)
```

### Loading at runtime

```gdscript
func load_unit_stats(path: String) -> UnitStats:
    if not ResourceLoader.exists(path):
        return null
    var stats := ResourceLoader.load(path) as UnitStats
    if stats == null:
        push_error("Failed to load UnitStats from: ", path)
    return stats
```

### Important caveats

- Runtime saving to `res://` is read-only — always use `user://` for runtime writes
- Resources can execute arbitrary code on load — do NOT use `ResourceLoader.load()` for untrusted external files. Use JSON or ConfigFile for user-generated content that crosses trust boundaries
- Only `@export`ed properties are saved by `ResourceSaver`
- The cache returns the same instance for repeated `load()` calls — use `.duplicate(true)` for per-instance copies at runtime
- `load()` is equivalent to `ResourceLoader.load()`; `preload()` loads at compile-time with constant paths only

### Threaded loading

```gdscript
ResourceLoader.load_threaded_request("res://levels/large_level.tscn")

func _process(_delta):
    var progress := []
    var status := ResourceLoader.load_threaded_get_status("res://levels/large_level.tscn", progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            $LoadingBar.value = progress[0] * 100
        ResourceLoader.THREAD_LOAD_LOADED:
            var scene := ResourceLoader.load_threaded_get("res://levels/large_level.tscn")
            get_tree().change_scene_to_packed(scene)
```

---

## 6. Preloading Resources vs Loading on Demand

```gdscript
# preload — compile-time, pinned for script lifetime
const SWORD_STATS := preload("res://resources/weapons/sword.tres")

# load — runtime, respects reference counting
var shield_stats := load("res://resources/weapons/shield.tres")

# @export — assigned via inspector, loaded with the scene
@export var armor_stats: ArmorStats

# Dynamic path — runtime variable path
func get_enemy_stats(type: String) -> UnitStats:
    return load("res://resources/enemies/%s.tres" % type)
```

### Guidelines

| Scenario | Method |
|---|---|
| Always-needed small assets (UI textures, core configs) | `preload()` as constant |
| Frequently instantiated scene templates | `preload()` for object pooling |
| Medium assets needed on a known screen | `@export` variable (loaded with scene) |
| Large levels, optional content | `load()` or `load_threaded_request()` |
| Runtime-dynamic paths (e.g., enemy type determined mid-game) | `load()` with string formatting |
| User-generated or external content | `ResourceLoader.load()` from `user://` |

**Important**: `preload()` pins the resource for the script's entire lifetime. Resources loaded via `preload()` are never unloaded until the script itself is freed. For large games, prefer `@export` or `load()` to avoid memory bloat. The `ResourceLoader` cache uses weak references — resources are freed when all external references are dropped (except for `preload()` which holds a strong reference).

---

## 7. Spreadsheet / Google Sheets → Godot Pipeline

### CSV → Resource (manual / scripted)

```
1. Author data in Google Sheets / LibreOffice Calc
2. Export as CSV
3. Write a GDScript import tool that:
   - Reads CSV via FileAccess.get_csv_line()
   - Maps columns to Resource fields
   - Saves .tres files via ResourceSaver
```

```gdscript
func import_units_from_csv(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    var headers := file.get_csv_line()  # First row: column names
    while not file.eof_reached():
        var row := file.get_csv_line()
        if row.is_empty():
            continue
        var stats := UnitStats.new()
        stats.display_name = row[headers.find("name")]
        stats.max_hp = int(row[headers.find("hp")])
        stats.move_speed = float(row[headers.find("speed")])
        stats.damage = int(row[headers.find("damage")])
        var save_path := "res://resources/units/%s.tres" % stats.display_name.to_lower().replace(" ", "_")
        stats.take_over_path(save_path)
        ResourceSaver.save(stats, save_path)
```

### Existing addons

| Addon | Description |
|---|---|
| Gnumaru's Static Data Importer | Imports YAML, TOML, XML, CSV, XLSX, ODS, SQLite as JSON Resources |
| godot-gspreadsheet-importer | Direct Google Sheets → .tres via editor plugin |
| Godot Sync Spreadsheets | Google Sheets ↔ CSV sync within editor |
| Pandora | RPG data management (items, spells, mobs) with editor UI |
| ResourceDatabases | Database-style collections of Resources with categories and expressions |

### XLSX/ODS advantage

Spreadsheet files (XLSX/ODS) support formulas, conditional formatting, and data validation in the authoring tool. Import tools like Gnumaru's importer can process these directly, including `str_to_var` interpretation (e.g., `Vector2(3, 4)` in a cell becomes an actual Vector2).

---

## 8. Localization Using Resources

Godot's localization pipeline uses CSV → Translation resources natively. The flow:

```
1. Create CSV: keys | en | fr | de | ...
2. Place in project → auto-imported as .translation resources
3. Add to Project Settings → Localization → Translations
4. Use tr("KEY") in scripts or set text directly in UI nodes
```

### Resource remaps for localized assets

In Project Settings → Localization → Remaps, you can swap resources per locale (e.g., different billboard textures, voice-over audio). This uses Godot's built-in resource remapping system and works with any Resource type.

```gdscript
# In code, resource remaps work transparently:
var texture := preload("res://assets/sign_post.tres")
# When locale = "fr", Godot returns the French variant automatically
```

For CSV-driven translations, the CSV importer supports:
- Context columns (`?context`) for ambiguous strings
- Plural forms (`?plural` column) — though gettext PO files are recommended for complex plurals
- Compression (OptimizedTranslation for smaller files)
- Custom delimiters (comma, tab, etc.)

---

## 9. Resource as Static Database (Registry Pattern)

```gdscript
# unit_database.gd
extends Resource
class_name UnitDatabase

@export var units: Array[UnitStats] = []

# Lookup table built at ready time
var _unit_map: Dictionary = {}

func build_index() -> void:
    _unit_map.clear()
    for unit in units:
        _unit_map[unit.display_name.to_lower()] = unit

func get_unit(name: String) -> UnitStats:
    return _unit_map.get(name.to_lower())
```

Use an Autoload to hold the database:

```gdscript
# GameData.gd (autoload)
extends Node

@export var unit_db: UnitDatabase

func _ready() -> void:
    unit_db = preload("res://resources/databases/unit_database.tres")
    unit_db.build_index()
```

Access from anywhere:

```gdscript
var goblin := GameData.unit_db.get_unit("goblin")
```

---

## 10. How Godot RTS/TD Games Structure Data

Based on research of open-source Godot RTS/TD projects:

| System | Data Pattern |
|---|---|
| Unit definitions | Per-type `.tres` with UnitStats (or inherited variants) |
| Wave definitions | WaveResource with Array of GroupResource (delay, count, enemy type, interval) |
| Tower definitions | TowerStats Resource with nested AttackStats, targeting priority enum |
| Ability/action system | Action Resource (data container) + Effect Resource (logic container), both typed |
| Building stats | BuildingStats Resource with hitbox_radius enum, build_cost Dictionary, armor |
| Tech tree / upgrades | Resource per upgrade node with prerequisites Array[Resource] |
| Projectile definitions | ProjectileStats Resource with speed, damage, splash_radius, pierce |
| Controller / state | StateMachine using Resources for state configuration (not state logic) |

### Common folder structure

```
res://data/
    units/
        foot_soldier.tres
        archer.tres
        cavalry.tres
    buildings/
        town_center.tres
        barracks.tres
    waves/
        wave_01.tres
        wave_02.tres
    databases/
        unit_database.tres
        wave_database.tres
resources/
    scripts/
        unit_stats.gd
        building_stats.gd
        wave_data.gd
```

---

## Implementation Patterns

### Pattern A: Pure Data Container (Read-only config)

```gdscript
class_name UnitStats extends Resource
@export var max_hp: int = 100
@export var damage: int = 10
```

Use: reference `.tres` files directly. Never modify at runtime — `duplicate()` first if changes needed.

### Pattern B: Data + Logic (Encapsulated)

```gdscript
class_name AttackStats extends Resource
@export var base_damage: int = 10
@export var damage_type: String = "physical"

func calculate_damage(target_armor: int) -> int:
    var reduction := min(target_armor, base_damage * 0.5)
    return max(1, base_damage - int(reduction))
```

Use: when data has associated read-only computations. Keep logic free of scene-tree dependencies.

### Pattern C: Resource Registry (Database)

```gdscript
class_name ItemDatabase extends Resource
@export var items: Array[ItemData] = []
var _by_id: Dictionary = {}

func _ready() -> void:
    for item in items:
        _by_id[item.id] = item

func get_item(id: String) -> ItemData:
    return _by_id.get(id)
```

Use: central catalog of Resources, loaded once via Autoload.

### Pattern D: Shared Resource + Per-instance Duplicate

```gdscript
# When instantiating a unit at runtime
var template := preload("res://data/units/foot_soldier.tres")
var instance_stats := template.duplicate(true)  # Deep copy
instance_stats.max_hp += 20  # Per-instance buff
```

Use: when you need per-instance mutable data derived from a base template.

---

## Limitations

| Limitation | Impact | Mitigation |
|---|---|---|
| Resource loading executes code | Security risk for untrusted external files | Never `ResourceLoader.load()` user-provided files; use JSON/ConfigFile instead |
| Shared by default — mutations affect all references | Unexpected cross-talk when modifying Resource fields | Use `duplicate()` for per-instance data, or mark `resource_local_to_scene = true` |
| `preload()` never unloads | Memory permanently allocated for preloaded Resources | Use `@export` or `load()` for large/optional assets |
| Only `@export`ed properties serialize | Non-exported fields lost on save/load | Ensure all persistable data uses `@export` |
| No `_process()`, `_physics_process()`, `_ready()` | Cannot use scene-tree callbacks directly | Call Resource methods from a Node that has tree access |
| Inner classes can't be Resource types | No file-per-class for small sub-types | Use separate script files for each Resource type |
| `.godot/global_script_class_cache.cfg` can stale | Inherited Resource types not recognized | Delete cache and restart editor |
| Deep nesting is UI-unfriendly | Inspector becomes unwieldy | Favor flatter structures; store sub-Resources as separate files |
| C# `preload()` not available | C# must use `ResourceLoader.load()` | Match performance via `GD.Load()` |
| Binary `.res` not VCS-friendly | Merge conflicts in binary blobs | Keep `.tres` in version control; rely on export conversion for release |
| Resource format tracks script path | Renaming/moving script files breaks `.tres` references | Use UIDs (Godot 4) or update paths after refactors |

---

## Alternatives

### JSON
- **Pros**: Industry standard, portable, tools-ecosystem, safe for untrusted data
- **Cons**: No type safety, no editor inspector integration, manual serialization of Godot types (Vector2, Color, etc.), no built-in caching
- **Best for**: Modding, web APIs, external tool pipelines, save data in multi-engine environments

### ConfigFile (INI-style)
- **Pros**: Simple, human-readable, supports all Variant types, built-in default values per key
- **Cons**: No nested structures, flat key-value per section, no type enforcement, clunky for complex data
- **Best for**: User-facing settings (audio, video, keybinds), small configuration files

### CSV (via import)
- **Pros**: Spreadsheet-native editing, bulk operations, translator-friendly, diff-friendly
- **Cons**: No type safety, flat table structure, requires import script or plugin, no editor inspector integration
- **Best for**: Large homogeneous data sets (100+ rows), localization strings, balance tables

### Binary via `var_to_bytes()` / `bytes_to_var()`
- **Pros**: Fastest serialization, smallest files, supports all Variant types
- **Cons**: Not human-readable, Godot-specific format, no editor integration
- **Best for**: Performance-critical save data, network replication

### Autoload (Singleton) with Dictionary data
- **Pros**: Simple, no file I/O at design time, accessible everywhere
- **Cons**: Data hardcoded in scripts, no editor visual editing, no serialization built-in, no reuse across projects
- **Best for**: Small prototypes, global state that rarely changes

### SQLite (via GDNative/GDExtension)
- **Pros**: Queryable, relational, large-dataset optimized, concurrent access
- **Cons**: External dependency, no editor integration, more complex setup
- **Best for**: Games with user-generated content, persistent worlds, multiplayer backends
