# Units

## Overview
Units are player-controlled entities that have HP, can move, and deal damage. Military units have a **detection radius** (scans for targets) and **attack radius** (range to deal damage).

Sergeant passive bonus: +20% HP, +20% attack damage applied via `apply_sergeant_bonus()` in `main.gd` after `add_child()`.

## Unit Types

### Foot Soldier
- **HP**: 100 (120 with sergeant bonus)
- **Damage**: 10 (12 with sergeant bonus)
- **Detection Radius**: 8 units (128px)
- **Attack Range**: 2 units (32px, melee)
- **Speed**: 5 units (80px)
- **Cost**: 50 gold
- **Script**: `scripts/foot_soldier.gd` (extends unit.gd)

### Archer
- **HP**: 60 (72 with sergeant bonus)
- **Damage**: 8 (9.6 with sergeant bonus)
- **Detection Radius**: 10 units (160px)
- **Attack Range**: 8 units (128px, ranged)
- **Speed**: 4.375 units (70px)
- **Cost**: 75 gold
- **Script**: `scripts/archer.gd` (extends unit.gd)

### Cavalry
- **HP**: 120 (144 with sergeant bonus)
- **Damage**: 15 (18 with sergeant bonus)
- **Detection Radius**: 10 units (160px, melee)
- **Attack Range**: 1 unit (16px)
- **Speed**: 10 units (160px)
- **Cost**: 100 gold
- **Script**: `scripts/cavalry.gd` (extends unit.gd)

## Unit Behavior

### Base Position
- Each unit has a **base position** set when placed (initial spawn position)
- When unit has no target and is not manually moved, it returns to its base position
- Units auto-return to base after: killing an enemy, losing target, or completing manual move
- Right-clicking to move temporarily overrides return-to-base behavior
- Base position persists until unit is destroyed or repositioned by player

### Auto-Engage
When enemy enters unit's detection radius, unit moves towards enemy to attack.

### Manual Control
- Left-click unit to select (toggles highlight per AGENTS.md)
- Right-click to move (overrides auto-engage and return-to-base until new enemy enters radius or movement completes)
- Selected units show detection radius (yellow) and attack range (red) circles via `_draw()`
- `update()` called in `set_selected()` to refresh visuals

### Combat
- Units deal damage when enemy is within attack range
- HP bar visible when unit HP < 100%
- Auto-shown on damage
- `take_damage()` method handles damage from enemies

## Scene Structure
- **Unit** (`scenes/unit.tscn`): Area2D with Sprite, SelectionIndicator, HealthBar
- `setup_stats()` called after `add_child()`
- Units added to "units" group
- SelectionIndicator: Sprite with `modulate = Color(1, 1, 0, 0.3)` for yellow highlight

## Base Script
`scripts/unit.gd` — Base unit: `is_clicked()`, `set_selected()` (calls `update()` for radius circles), `take_damage()`, detection radius (scan for enemies) and attack range (deal damage), HP bar shown when HP < 100%
