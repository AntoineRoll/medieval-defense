# Buildings

## Overview
Buildings have HP, never move, and can deal damage. They use a single attack radius (no separate detection radius) to auto-target enemies in range.

## Building Types

### Town Center (Base)
- **HP**: 200
- **Type**: Static at map center
- **Behavior**: Default target for enemies, clickable (shows selection highlight and action bar)
- **Damage**: Enemies deal 10 damage each on contact
- **Group**: "base"
- **Script**: `scripts/base.gd`

### Post-MVP Buildings

#### Guild Buildings (Stage 2)
- **Architects' Guild**: Heavy siege weapons and defensive ballistics (Engineering)
- **Blacksmiths' Guild**: Faster resource generation, construction, growth (Industry)
- **Merchants' Guild**: Expanded borders, boosted gold flow (Trade)

## Building Mechanics

### Combat
- Buildings auto-target enemies in attack radius
- No separate detection radius (unlike units)
- `take_damage()` method handles damage from enemies
- Visual HP bar displays current health

### Interaction
- Clickable to show selection highlight
- `set_selected()` shows action bar with name and HP
- SelectionIndicator: Sprite with `modulate = Color(1, 1, 0, 0.3)` for yellow highlight

## Scene Structure
- **Base** (`scenes/base.tscn`): Node2D + Script: base.gd, clickable
  - `CollisionArea` (Area2D, "base" group, detects enemies)
- Buildings added to appropriate groups for targeting

## Building Scripts
`scripts/base.gd` — Building base script: clickable, `set_selected()` shows action bar, HP tracking, `take_damage()`
