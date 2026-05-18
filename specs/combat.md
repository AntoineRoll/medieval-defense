# Combat

## Overview
Combat is omnidirectional with two entity types: **Units** (mobile, detection + attack radius) and **Buildings** (static, single attack radius). Enemies prioritize targets by type. Unit types (Foot Soldier, Archer, Cavalry) have distinct stats but no hidden damage modifiers.

## Targeting Priority

### Enemy Targeting
Enemies use `find_best_target()` with `global_position` distance checks, switching immediately to higher priority targets:
1. **Military Units** (highest priority): Attack if within enemy detection radius (19 units)
2. **Buildings** (lower priority): Attack if no military units in range and building is within detection radius
3. **Town Center** (default): Move to and attack if no valid targets in range

### Unit Targeting
Military units scan their **detection radius** (6 units / 384px, all types) for enemies:
- When enemy enters detection radius, unit moves toward the closest enemy to engage
- Unit deals damage when enemy is within **attack range**:
  - Foot Soldier: 2 units (128px, melee)
  - Archer: 3 units (192px, ranged)
  - Cavalry: 1 unit (64px, melee)
- After killing all enemies in attack range, unit re-scans detection radius before returning to base
- When no targets exist in either range, unit returns to its **base position**
- Right-click repositions base position (not a direct move command). Unit moves to new base only when idle (no target)

## Damage System

### Base Stats
- **Units**: Deal damage at 1 attack per second (10dmg/s for Foot Soldier, 8dmg/s Archer, 15dmg/s Cavalry)
- **Enemies**: Deal 10 damage per second to units/base on contact
- **Buildings**: Auto-target enemies in attack radius, deal damage at 1 attack per second

### Speed
- **Foot Soldier**: 1 tile/s (64px)
- **Archer**: 1 tile/s (64px)
- **Cavalry**: 2 tiles/s (128px)
- **Enemies**: 1 tile/s (64px)

### Damage Calculation
Final damage = Base Damage × (1 + Sergeant Bonus)

- Sergeant Bonus: +20% for units matching sergeant's class

### Death Handling
- Entities die when HP reaches 0
- Dead units/enemies are removed from scene
- Kill rewards: +10 gold per enemy killed

## Unit Types (No RPS Modifiers)
Three unit types exist (Foot Soldier, Archer, Cavalry) with different base stats (HP, damage, speed, range). No hidden damage modifiers — all units deal base damage regardless of target type. Tactical depth comes from stat diversity and positioning, not mathematical counters. The `DamageTable` resource was considered but removed — there are no RPS multipliers in the codebase.

## Detection & Attack Radii

All radii measured in grid units (1 unit = 64px).

### Units
- **Detection Radius**: Scan range for enemies (all unit types: 6 units / 384px)
- **Attack Range**: Range at which damage is dealt
  - Foot Soldier: 2 units (128px, melee)
  - Archer: 3 units (192px, ranged)
  - Cavalry: 1 unit (64px)
- Visual indicators via `_draw_tile_circle()`: Yellow tile-grid squares (detection), Red tile-grid squares (attack range), drawn as "Minecraft-style" circle of filled 64×64 tiles

### Enemies
- **Detection Radius**: 19 units (1216px, scans for units > buildings > base)
- **Attack Range**: Melee only (contact damage, 1 unit / 64px)

### Buildings
- **Attack Radius**: Single radius for targeting and damage (no separate detection radius)
- Wood Tower: 4 units (256px)
- Non-attacking buildings: attack radius = 0

## Hitbox System

All entities have square hitboxes matching their tile footprint. The hitbox uses `CollisionShape2D` (RectangleShape2D).

### Hitbox Sizes
- **Units** (Foot Soldier, Archer, Cavalry): 64×64 square (1 grid unit / 1 tile)
- **Enemies**: 64×64 square (1 grid unit / 1 tile)
- **Wood Towers**: 64×64 square (1 grid unit / 1 tile)
- **Town Center (Base)**: 128×128 square (2×2 grid units / 4 tiles)

### Physics Layers (project.godot)
- Layer 1 (1): world — terrain/collision geometry
- Layer 2 (2): units — player unit bodies
- Layer 3 (4): enemies — enemy bodies
- Layer 4 (8): buildings — building bodies
- Layer 5 (16): hurtboxes — Area2D nodes that receive damage (detect hitboxes)
- Layer 6 (32): hitboxes — Area2D nodes that deal damage (detect hurtboxes)
- Layer 7 (64): detection — Area2D nodes for range-finding (detect units/enemies)

### Push-Apart & Bump Behavior
- **Building separation**: Units push away from buildings when overlapping. Uses AABB overlap check (Chebyshev distance), not circular distance. Push factor: 0.5 in the overlap axis with least penetration.
- **Unit bump**: Currently disabled (units occupy disjoint grid tiles via GridManager occupancy).
- **Enemy push**: Enemies do not push apart from each other or from units (allows melee combat).
- **No cross-type push**: Units and enemies do not push apart from each other.

### Implementation
- `hitbox_radius` variable on each entity (unit.gd, enemy.gd, base.gd, tower.gd): stores half-size (32 for 64px tiles, 64 for 128px TC)
- `_check_base_push()` uses AABB overlap: compares axis-aligned half-extents, pushes on the least-overlapping axis
- `_is_base_position_valid()` validates via GridManager occupancy check (primary) + distance fallback
- `set_base_position()` validates before assigning
- `get_hitbox_radius()` accessor on Base and Tower for cross-entity queries
- `CollisionShape2D` uses `RectangleShape2D` with `size = Vector2(64, 64)` (or `Vector2(128, 128)` for TC)
- `is_clicked()` uses rectangular (AABB) check: `abs(diff.x) < click_radius and abs(diff.y) < click_radius`
- `click_radius` = half of tile size (32 for 1-tile entities, 64 for 2×2 TC)
