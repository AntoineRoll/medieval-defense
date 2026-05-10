# AGENTS.md

## Source of Truth
- `specs/` is the single source of truth for all game design, mechanics, and requirements
- When handling new user requests, first reference relevant `specs/` files
- If user requests or existing implementation conflict with `specs/`, clarify with the user before proceeding
- New or changed mechanics must be documented in `specs/` after implementation

## Grid System
- Tile size: 16x16 pixels (1 grid unit = 16px)
- All game sprites/assets must be multiples of 16x16 (minimum size 16x16)
- All game measurements (radii, positions, speeds) specified in grid units
- UI/HUD elements measured in pixels (not grid units)
- Snap all game positions to grid in editor

## Dev Commands

- Open project: `godot --editor --path /home/antoine/medieval-defense`
- Run scene: `godot --path /home/antoine/medieval-defense --scene res://scenes/main.tscn`
- After updating assets (sprites, textures): delete `.import` files and run `timeout 10 godot --editor --path /home/antoine/medieval-defense` to re-import (use timeout for headless)
- Export: use Godot editor (Editor → Export), no CI/CD configured yet

## Sprite Processing

- Remove white backgrounds: `convert sprite.png -fuzz 8% -transparent white sprite.png`
- Remove anti-aliased white edges: `convert sprite.png -channel A -morphology Erode Diamond:1 sprite.png`
- Check near-white pixels: `convert sprite.png -format %c histogram:info:- | grep -E "srgba\(25[0-9].*1\)"`

## Unit Selection Pattern

- Use click radius detection (`get_global_mouse_position().distance_to(global_position) < click_radius`) via `is_clicked(event)` method
- Toggle selection: left-click on unit/building toggles highlight, left-click on nothing deselects all
- Right-click on selected unit moves it; right-click elsewhere closes pause menu
- SelectionIndicator: Sprite with `modulate = Color(1, 1, 0, 0.3)` for yellow highlight
- Action bar (bottom) shows selected unit/building name and HP; auto-hides when nothing selected

## Architecture

```
scenes/     # .tscn files (Godot 3.1 format=2)
scripts/    # .gd files (GDScript, Python-like)
assets/
  sprites/  # Pixel art (multiples of 16x16, e.g. 128x128 sergeant units)
specs/      # Design documentation (source of truth):
            # - introduction.md: Core concept, project structure, grid system, technical conventions
            # - gameplay.md: Goal, win/lose conditions, progression, combat system, currency, input, UI
            # - units.md: Unit types, stats, behavior, scripts, scene structure
            # - buildings.md: Building types, mechanics, interaction, scripts
            # - combat.md: Targeting, damage system, RPS, detection/attack radii
            # - graphics.md: Art style, sprite guidelines
            # - map.md: Map structure, spawn rules
            # - dev.md: Development workflow, conventions, dev commands, testing strategy
            # - roadmap-idea.md: Future feature roadmap and ideas
```

## Conventions

- Godot 3.1: `format=2` in .tscn, `PoolStringArray` in project.godot
- GDScript uses Python-like syntax: `snake_case` for variables/functions, `PascalCase` for classes
- Signal methods use Godot 3 naming: `_on_InfantryBtn_pressed` (not `_on_infantry_pressed`)
- Attach scripts to scene nodes; don't treat scripts as standalone entrypoints
- Pixel art: disable texture filtering per sprite (import flags), snap to 16px grid in editor
- Grid units: 1 unit = 16px, all measurements in units (e.g., detection radius: 8 units = 128px)

## Testing

### Targeting Test
- Test scene: `scenes/test_combat.tscn` with script `scripts/test_combat.gd`
- Runs without user interaction, auto-places units/enemies, logs targeting behavior
- Run: `timeout 15 godot --path /home/antoine/medieval-defense --scene res://scenes/test_combat.tscn 2>&1 | grep -E "(COMBAT TEST|Foot Soldier|Enemy|targeting|Unit attacked|WARNING|SCRIPT ERROR)"`
- Expected behavior:
  - Enemy within 19 units (304px) detection of military unit → targets unit (PRIORITY)
  - Enemy within 19 units (304px) detection of building (no unit) → targets building
  - Enemy outside detection range → moves to base (default)
  - Military units have detection radius (8 units/128px Foot Soldier) to auto-engage enemies

### Damage Test
- Test scene: `scenes/test_damage.tscn` with script `scripts/test_damage.gd`
- Tests HP tracking, damage dealt/taken, combat duration
- Run: `timeout 15 godot --path /home/antoine/medieval-defense --scene res://scenes/test_damage.tscn 2>&1 | grep -E "(DAMAGE TEST|Enemy|Foot Soldier|attacked|took damage|REPORT|✓|✗|SCRIPT ERROR)"`
- Expected behavior:
  - Unit (10dmg/1s) and Enemies (10dmg/1s) deal damage at correct intervals
  - Damage events logged with timestamps and HP changes
  - Final report shows HP remaining for all combatants
  - Enemies die when HP reaches 0

### Unit-Enemy Attack Test
- Test scene: `scenes/test_unit_enemy.tscn` with script `scripts/test_unit_enemy.gd`
- Verifies unit damages enemy until death
- Run: `timeout 15 godot --path /home/antoine/medieval-defense --scene res://scenes/test_unit_enemy.tscn 2>&1 | grep -E "(UNIT ATTACK|Enemy|TEST|SCRIPT ERROR)"`
- Expected: Enemy HP 50→0 in 5 attacks (10dmg × 5)

### Building Damage Test
- Test scene: `scenes/test_building_damage.tscn` with script `scripts/test_building_damage.gd`
- Verifies enemies damage base (building) on contact: 10 dmg per hit
- Run: `timeout 20 godot --path /home/antoine/medieval-defense --scene res://scenes/test_building_damage.tscn 2>&1 | grep -E "(BUILDING|Base HP|TEST|SCRIPT ERROR)"`
- Expected: 10 enemies × 10 dmg = 100 HP loss → Base destroyed ✓

### Wave Survival Test
- Test scene: `scenes/test_auto.tscn` with script `scripts/test_auto.gd`
- Auto-places 8 units to defend against 4 enemies (wave 4)
- Run: `timeout 120 godot --path /home/antoine/medieval-defense --scene res://scenes/test_auto.tscn 2>&1 | grep -E "(AUTO-PLACE|died|TEST|SCRIPT ERROR)"`
- Expected: All enemies killed by units, base survives ✓

### Game Survival Test
- Test scene: `scenes/test_minimal.tscn` with script `scripts/test_minimal.gd`
- Minimal test: 1 unit kills 1 enemy in ~5s
- Run: `timeout 20 godot --path /home/antoine/medieval-defense --scene res://scenes/test_minimal.tscn 2>&1 | grep -E "(MINIMAL|Enemy|TEST|SCRIPT ERROR)"`
- Expected: Enemy dies in 5 hits (50HP ÷ 10dmg) ✓
