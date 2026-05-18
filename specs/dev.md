# Development Guide

## Agent Workflow
1. **Understand task**: Review specs/ files relevant to the request
2. **Check conventions**: Follow Godot 4.6 and project conventions (see introduction.md)
3. **Implement changes**: Edit existing files first; avoid new files unless required
4. **Verify**: Run relevant test scenes to confirm behavior
5. **Document**: Update specs/ if adding new features or changing mechanics

## Project Conventions
- Godot 4.x: `format=3` in .tscn, `process_mode` property, `offset_*` not `margin_*`
- `snake_case` for variables/functions, `PascalCase` for classes
- Signal methods: `_on_node_name_pressed` (lowercase node names)
- Scripts attach to scene nodes (not standalone entrypoints)
- Pixel art: Disable texture filtering, snap to 64px grid
- All sprites/assets must be multiples of 64x64 (minimum 64x64)
- No comments unless explicitly requested
- Use `@onready` with `%UniqueName` for node references (avoid fragile `$A/B/C/D` paths)
- Use typed signals: `signal_name.emit()` not `emit_signal("signal_name")`
- Use `Resource`-based data (UnitStats) over hardcoded values

## Architecture

### Autoload Singletons
- **EventBus** (`scripts/event_bus.gd`): Global signal bus, loaded first via `*` autoload prefix
- **GameManager** (`scripts/game_manager.gd`): Game state (enum), gold, wave tracking, sergeant bonuses

### Scene-based Managers
- **WaveManager**: Child of Main scene, handles enemy spawning and wave lifecycle
- **main.gd**: Thin coordinator; connects UI, handles input/placement, delegates to autoloads

### Data Resources
- Unit stats defined in `scripts/unit_stats.gd` (extends Resource)
- Per-unit `.tres` files in `resources/` (foot_soldier_stats, archer_stats, cavalry_stats)
- Scene `.tscn` files reference their stats resource via `@export var unit_stats: Resource`

## Dev Commands
### Editor & Run
- Open project: `godot4 --editor --path /home/antoine/medieval-defense`
- Run main scene: `godot4 --path /home/antoine/medieval-defense --scene res://scenes/main.tscn`

### Asset Processing
- Remove white backgrounds: `convert sprite.png -fuzz 8% -transparent white sprite.png`
- Remove anti-aliased edges: `convert sprite.png -channel A -morphology Erode Diamond:1 sprite.png`
- Re-import assets: Delete `.import` files, run `timeout 10 godot4 --editor --path /home/antoine/medieval-defense`

## Testing Strategy

Two-tier approach: **GUT (Godot Unit Test)** for isolated unit tests, **scene-based auto-run scripts** for integration/system tests.

All tests run headless with `timeout` to limit execution.

### GUT Unit Tests

- Framework: [GUT 9.6.0](https://github.com/bitwes/Gut) (Godot Unit Test)
- Location: `res://test/unit/` — files extend `GutTest`
- Run all: `timeout 30 /home/antoine/.local/bin/godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -glog=2 -gexit 2>&1 | grep -E "(PASS|FAIL|ERROR|SCRIPT ERROR)"`
- Run single: `timeout 15 /home/antoine/.local/bin/godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/test_enemy.gd -glog=2 -gexit 2>&1 | grep -E "(PASS|FAIL|ERROR|SCRIPT ERROR)"`
- Available tests:
  - `test/unit/test_enemy.gd` — Enemy HP tracking, death signal, base position
  - `test/unit/test_unit.gd` — Unit setup_stats, take_damage, RPS multipliers, selection signal
  - `test/unit/test_base.gd` — Base HP, damage signals, destroyed behavior

### Scene-Based Integration Tests

Auto-run `.tscn` files in `scenes/`, scripts extend `Node2D`, use `print()` + `grep` for pass/fail patterns.

#### Targeting Test
- Scene: `scenes/test_combat.tscn`, Script: `scripts/test_combat.gd`
- Run: `timeout 15 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_combat.tscn 2>&1 | grep -E "(COMBAT TEST|Enemy|targeting|SCRIPT ERROR)"`
- Verifies enemy targeting priority (units > buildings > base)

#### Damage Test
- Scene: `scenes/test_damage.tscn`, Script: `scripts/test_damage.gd`
- Run: `timeout 15 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_damage.tscn 2>&1 | grep -E "(DAMAGE TEST|Enemy|Foot Soldier|attacked|REPORT|SCRIPT ERROR)"`
- Verifies damage intervals, HP tracking, death on 0 HP

#### Unit-Enemy Attack Test
- Scene: `scenes/test_unit_enemy.tscn`, Script: `scripts/test_unit_enemy.gd`
- Run: `timeout 15 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_unit_enemy.tscn 2>&1 | grep -E "(UNIT ATTACK|Enemy|TEST|SCRIPT ERROR)"`
- Verifies unit damages enemy until death (50HP ÷ 10dmg = 5 hits)

#### Building Damage Test
- Scene: `scenes/test_building_damage.tscn`, Script: `scripts/test_building_damage.gd`
- Run: `timeout 20 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_building_damage.tscn 2>&1 | grep -E "(BUILDING|Base HP|TEST|SCRIPT ERROR)"`
- Verifies 10 enemies × 10dmg = 100 HP loss (base eventually destroyed)

#### Wave Survival Test
- Scene: `scenes/test_auto.tscn`, Script: `scripts/test_auto.gd`
- Run: `timeout 120 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_auto.tscn 2>&1 | grep -E "(AUTO-PLACE|died|TEST|SCRIPT ERROR)"`
- Verifies 8 units defend against 4 enemies, base survives

#### Game Survival Test
- Scene: `scenes/test_minimal.tscn`, Script: `scripts/test_minimal.gd`
- Run: `timeout 20 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_minimal.tscn 2>&1 | grep -E "(MINIMAL|Enemy|TEST|SCRIPT ERROR)"`
- Verifies 1 unit kills 1 enemy in ~5s

#### Full Game Test
- Scene: `scenes/test_full_game.tscn`, Script: `scripts/test_full_game.gd`
- Run: `timeout 120 /home/antoine/.local/bin/godot --headless --path /home/antoine/medieval-defense --scene res://scenes/test_full_game.tscn 2>&1 | grep -E "(FULL GAME|Wave|TEST|SCRIPT ERROR)"`
- Integration test: auto-places units, survives waves
