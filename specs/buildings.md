# Buildings

## Overview
Buildings have HP, never move, and can deal damage. They use a single attack radius (no separate detection radius) to auto-target enemies in range.

## Building Types

### Town Center (Base)
- **HP**: 200
- **Type**: Static at map center, non-attacking (attack range = 0)
- **Grid footprint**: 2×2 tiles (128×128px square, occupies tiles (8,4),(9,4),(8,5),(9,5))
- **Position**: (704, 392) — center of 4-tile block
- **Hitbox**: RectangleShape2D 128×128 (half-size 64px)
- **Click radius**: 64px (half of 128, rectangular AABB check)
- **Behavior**: Default target for enemies, clickable (shows selection highlight and action bar). Selection shows hover indicator as tile-grid squares.
- **Damage**: Enemies deal 10 damage each on contact
- **Group**: "base"
- **Script**: `scripts/buildings/base.gd`

### Wood Tower
- **HP**: 80
- **Type**: Offensive building, auto-targets nearest enemy within range
- **Attack**: 8 damage, 1 attack/s, 4 units (256px) range
- **Grid footprint**: 1×1 tile (64×64px square)
- **Hitbox**: RectangleShape2D 64×64 (half-size 32px)
- **Click radius**: 32px (rectangular AABB check)
- **Cost**: 25 gold
- **Behavior**: Purchased from Town Center action bar when selected. Selection shows attack range as tile-grid squares (red, Minecraft-style circle) and click radius (yellow tile-grid highlight). Self-destructs when HP reaches 0. Grid tile vacated via `GridManager.vacate_entity()` on `tree_exited`.
- **Group**: "buildings"
- **Sprite**: `assets/sprites/tower_wood.png` (64×64, resized from 128×128)
- **Scene**: `scenes/buildings/tower.tscn`

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
- Clickable via AABB rectangular check: `abs(diff.x) < click_radius and abs(diff.y) < click_radius`
- `set_selected()` shows action bar with name and HP
- SelectionIndicator: Sprite with `modulate = Color(1, 1, 0, 0.3)` for yellow highlight
- Range indicators drawn via `_draw_tile_circle()` as tile-grid squares (Minecraft-style circle)

## Scene Structure
- **Base** (embedded in `scenes/ui/main.tscn` as `TownCenter/Base`): Node2D + Script: base.gd, clickable
  - Hurtbox (Area2D, group "buildings" and "base", detects enemy hitboxes)
- Buildings added to appropriate groups for targeting

## Building Scripts
`scripts/base.gd` — Building base script: clickable, `set_selected()` shows action bar, HP tracking, `take_damage()`
