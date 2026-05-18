# Units

## Overview
Units are player-controlled entities that have HP, can move, and deal damage. Military units have a **detection radius** (scans for targets) and **attack radius** (range to deal damage).

Sergeant passive bonus: +20% HP, +20% attack damage applied via `apply_sergeant_bonus()` in `main.gd` after `add_child()`.

## Unit Types

### Foot Soldier
- **HP**: 100 (120 with sergeant bonus)
- **Damage**: 10 (12 with sergeant bonus)
- **Detection Radius**: 6 units (384px)
- **Attack Range**: 2 units (128px, melee)
- **Speed**: 1 tile/s (64px)
- **Hitbox**: 64×64 square (1 tile, half-size 32px)
- **Cost**: 50 gold
- **Script**: `scripts/units/foot_soldier.gd` (extends unit.gd)

### Archer
- **HP**: 60 (72 with sergeant bonus)
- **Damage**: 8 (9.6 with sergeant bonus)
- **Detection Radius**: 6 units (384px)
- **Attack Range**: 3 units (192px, ranged)
- **Speed**: 1 tile/s (64px)
- **Hitbox**: 64×64 square (1 tile, half-size 32px)
- **Cost**: 75 gold
- **Script**: `scripts/units/archer.gd` (extends unit.gd)

### Cavalry
- **HP**: 120 (144 with sergeant bonus)
- **Damage**: 15 (18 with sergeant bonus)
- **Detection Radius**: 6 units (384px)
- **Attack Range**: 1 unit (64px)
- **Speed**: 2 tiles/s (128px)
- **Hitbox**: 64×64 square (1 tile, half-size 32px)
- **Cost**: 100 gold
- **Script**: `scripts/units/cavalry.gd` (extends unit.gd)

## Unit Behavior

### Base Position
- Each unit has a **base position** set when placed (initial spawn position)
- When unit has no target (idle), it returns to its base position
- Units auto-return to base after: killing all enemies in range, losing target, or completing manual move
- **After killing or losing a target, unit re-scans detection range first** before returning to base
- Right-clicking a selected unit **repositions** (updates base position), not a move command
  - Base position is validated against buildings and other unit base positions (rejected if overlapping)
  - If unit is idle (no target), it immediately moves to the new base position
  - If unit is in combat, it stays engaged and will return to the new base position after combat ends
- Base position persists until unit is destroyed or repositioned by player
- Multi-select (future): right-click repositions all selected units to the same point

### Overlap & Bump
- **Grid prevents overlap**: GridManager occupancy prevents two entities from occupying the same tile
- **Building push-apart**: Units use AABB (square) overlap check against buildings, pushed away on least-overlapping axis
- No unit-unit or enemy-enemy push-apart

### Auto-Engage
When enemy enters unit's detection radius, unit moves towards the closest enemy to attack. Stops and attacks when within attack range.

### Manual Control
- Left-click unit to select: AABB rectangular check (`abs(diff.x) < click_radius and abs(diff.y) < click_radius`)
- Right-click repositions selected unit's base position (grid-snapped, GridManager occupancy updated)
- Selected units show detection radius (yellow) and attack range (red) as tile-grid squares via `_draw_tile_circle()`
- `queue_redraw()` called in `set_selected()` to refresh visuals

### Combat
- Units deal damage when enemy is within attack range
- No hidden damage modifiers: all units deal base damage regardless of target type
- HP bar visible when unit HP < 100%
- Auto-shown on damage
- `take_damage()` method handles damage from enemies

## Scene Structure
- **Unit** (`scenes/units/foot_soldier.tscn`, `scenes/units/archer.tscn`, `scenes/units/cavalry.tscn`): CharacterBody2D with Sprite (64×64), SelectionIndicator, HealthBar, CollisionShape2D (RectangleShape2D 64×64)
- `setup_stats()` called after `add_child()`
- Units added to "units" group
- SelectionIndicator: Sprite with `modulate = Color(1, 1, 0, 0.3)` for yellow highlight

## Base Script
`scripts/units/unit.gd` — Base unit: `is_clicked()` (rectangular AABB check), `set_selected()` (calls `queue_redraw()` for range tile-grid squares), `take_damage()`, detection radius (scan for enemies) and attack range (deal damage), HP bar shown when HP < 100%. Hitbox: `RectangleShape2D` 64×64, `hitbox_radius = 32.0` (half-size for push-apart).
