# Combat

## Overview
Combat is omnidirectional with two entity types: **Units** (mobile, detection + attack radius) and **Buildings** (static, single attack radius). Enemies prioritize targets by type, and a Rock-Paper-Scissors (RPS) system modifies damage between unit types.

## Targeting Priority

### Enemy Targeting
Enemies use `find_best_target()` with `global_position` distance checks, switching immediately to higher priority targets:
1. **Military Units** (highest priority): Attack if within enemy detection radius (19 units)
2. **Buildings** (lower priority): Attack if no military units in range and building is within detection radius
3. **Town Center** (default): Move to and attack if no valid targets in range

### Unit Targeting
Military units scan their **detection radius** for enemies:
- Foot Soldier: 8 units
- Archer: 22 units
- Cavalry: 1 unit (melee)
- When enemy enters detection radius, unit moves toward enemy to engage
- Unit deals damage when enemy is within **attack range**:
  - Foot Soldier: 1 unit (melee)
  - Archer: 12 units (ranged)
  - Cavalry: 1 unit
- After combat or when no targets exist, unit returns to its **base position** (initial spawn point)
- Manual right-click overrides auto-engage and return-to-base until new enemy enters radius or movement completes

## Damage System

### Base Stats
- **Units**: Deal damage at 1 attack per second (10dmg/s for Foot Soldier, 8dmg/s Archer, 15dmg/s Cavalry)
- **Enemies**: Deal 10 damage per second to units/base on contact
- **Buildings**: Auto-target enemies in attack radius, deal damage at 1 attack per second

### Speed
- **Foot Soldier**: 5 units (80px)
- **Archer**: 4.375 units (70px)
- **Cavalry**: 10 units (160px)
- **Enemies**: 5 units (80px)

### Damage Calculation
Final damage = Base Damage × (1 + Sergeant Bonus) × (1 + RPS Modifier)
- Sergeant Bonus: +20% damage (applied to all player units via `apply_sergeant_bonus()`)
- RPS Modifier: See Rock-Paper-Scissors section below

### Death Handling
- Entities die when HP reaches 0
- Dead units/enemies are removed from scene
- Kill rewards: +10 gold per enemy killed

## Rock-Paper-Scissors (RPS)
Classic medieval unit counter system, +20% damage modifier when countering:
- **Infantry (Foot Soldier)** > Cavalry: +20% damage to Cavalry units
- **Cavalry** > Archers: +20% damage to Archer units
- **Archers** > Infantry (Foot Soldier): +20% damage to Foot Soldier units
- **Enemies**: BasicEnemy is treated as Infantry type (weak to Archers, strong against Infantry)
- **Buildings**: No RPS modifiers, take standard damage from all attackers

## Detection & Attack Radii

All radii measured in grid units (1 unit = 16px).

### Units
- **Detection Radius**: Scan range for enemies
  - Foot Soldier: 8 units (128px)
  - Archer: 22 units (352px)
  - Cavalry: 1 unit (16px, melee)
- **Attack Range**: Range at which damage is dealt
  - Foot Soldier: 1 unit (16px, melee)
  - Archer: 12 units (192px, ranged)
  - Cavalry: 1 unit (16px)
- Visual indicators via `_draw()`: Yellow circle (detection), Red circle (attack range)

### Enemies
- **Detection Radius**: 19 units (304px, scans for units > buildings > base)
- **Attack Range**: Melee only (contact damage)

### Buildings
- **Attack Radius**: Single radius for targeting and damage (no separate detection radius)
