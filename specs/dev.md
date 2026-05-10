# Development Guide

## Agent Workflow
1. **Understand task**: Review specs/ files relevant to the request
2. **Check conventions**: Follow Godot 3.1 and project conventions (see introduction.md)
3. **Implement changes**: Edit existing files first; avoid new files unless required
4. **Verify**: Run relevant test scenes to confirm behavior
5. **Document**: Update specs/ if adding new features or changing mechanics

## Project Conventions
- Godot 3.1: `format=2` in .tscn, `rect_position` not `position`
- `snake_case` for variables/functions, `PascalCase` for classes
- Signal methods: `_on_InfantryBtn_pressed` (Godot 3 naming)
- Scripts attach to scene nodes (not standalone entrypoints)
- Pixel art: Disable texture filtering, snap to 16px grid
- All sprites/assets must be multiples of 16x16 (minimum 16x16)
- No comments unless explicitly requested

## Dev Commands
### Editor & Run
- Open project: `godot --editor --path /home/antoine/medieval-defense`
- Run main scene: `godot --path /home/antoine/medieval-defense --scene res://scenes/main.tscn`

### Asset Processing
- Remove white backgrounds: `convert sprite.png -fuzz 8% -transparent white sprite.png`
- Remove anti-aliased edges: `convert sprite.png -channel A -morphology Erode Diamond:1 sprite.png`
- Re-import assets: Delete `.import` files, run `timeout 10 godot --editor --path /home/antoine/medieval-defense`

## Testing Strategy
All test scenes are in `scenes/` with matching scripts in `scripts/`. Run headless with `timeout` to limit execution.

### Targeting Test
- Scene: `scenes/test_combat.tscn`, Script: `scripts/test_combat.gd`
- Run: `timeout 15 godot --path /home/antoine/medieval-defense --scene res://scenes/test_combat.tscn 2>&1 | grep -E "(COMBAT TEST|Foot Soldier|Enemy|targeting|Unit attacked|WARNING|SCRIPT ERROR)"`
- Verifies enemy targeting priority (units > buildings > base)

### Damage Test
- Scene: `scenes/test_damage.tscn`, Script: `scripts/test_damage.gd`
- Run: `timeout 15 godot --path /home/antoine/medieval-defense --scene res://scenes/test_damage.tscn 2>&1 | grep -E "(DAMAGE TEST|Enemy|Foot Soldier|attacked|took damage|REPORT|✓|✗|SCRIPT ERROR)"`
- Verifies damage intervals, HP tracking, death on 0 HP

### Unit-Enemy Attack Test
- Scene: `scenes/test_unit_enemy.tscn`, Script: `scripts/test_unit_enemy.gd`
- Run: `timeout 15 godot --path /home/antoine/medieval-defense --scene res://scenes/test_unit_enemy.tscn 2>&1 | grep -E "(UNIT ATTACK|Enemy|TEST|SCRIPT ERROR)"`
- Verifies unit damages enemy until death (50HP ÷ 10dmg = 5 hits)

### Building Damage Test
- Scene: `scenes/test_building_damage.tscn`, Script: `scripts/test_building_damage.gd`
- Run: `timeout 20 godot --path /home/antoine/medieval-defense --scene res://scenes/test_building_damage.tscn 2>&1 | grep -E "(BUILDING|Base HP|TEST|SCRIPT ERROR)"`
- Verifies 10 enemies × 10dmg = 100 HP loss to base

### Wave Survival Test
- Scene: `scenes/test_auto.tscn`, Script: `scripts/test_auto.gd`
- Run: `timeout 120 godot --path /home/antoine/medieval-defense --scene res://scenes/test_auto.tscn 2>&1 | grep -E "(AUTO-PLACE|died|TEST|SCRIPT ERROR)"`
- Verifies 8 units defend against 4 wave 4 enemies, base survives

### Game Survival Test
- Scene: `scenes/test_minimal.tscn`, Script: `scripts/test_minimal.gd`
- Run: `timeout 20 godot --path /home/antoine/medieval-defense --scene res://scenes/test_minimal.tscn 2>&1 | grep -E "(MINIMAL|Enemy|TEST|SCRIPT ERROR)"`
- Verifies 1 unit kills 1 enemy in ~5s
