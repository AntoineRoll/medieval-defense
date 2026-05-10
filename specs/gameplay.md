# Gameplay

## Goal
Survive 10 waves of omnidirectional enemy attacks using placed units. No towers in MVP (towers added later).

## Win / Lose
- **Win**: Survive all 10 waves
- **Lose**: Base HP reaches 0

## Progression System

### Stage 1: Village (Sergeant)
Starting combat specialty choice — gives a passive bonus to all units placed:
- **Infantry Sergeant**: +20% HP, +20% attack damage to all units
- **Archery Sergeant**: +20% HP, +20% attack damage to all units
- **Cavalry Sergeant**: +20% HP, +20% attack damage to all units

The chosen sergeant is displayed as a shield icon in the top-right corner during gameplay.

### Stage 2: Town (Guild)
Guild specialty unlocking unique mechanics:
- **Architects' Guild**: Heavy siege weapons and defensive ballistics (Engineering)
- **Blacksmiths' Guild**: Faster resource generation, construction, growth (Industry)
- **Merchants' Guild**: Expanded borders, boosted gold flow (Trade)

### Stage 3: City (Ruler)
Leadership type choice:
- **Prince Ruler**: Crown - Strength, nobility, military honor
- **Bishop Ruler**: Cross - Faith and science
- **Burgher Ruler**: Keys - Economy, wellbeing, civic wealth

## Combat System

### Overview
Two primary entity types with distinct combat rules:
- **Units**: Have HP, can move, always deal damage. Military units have a **detection radius** (scans for targets) and **attack radius** (range to deal damage).
- **Buildings**: Have HP, never move, can deal damage. Use a single attack radius (no separate detection radius) to auto-target enemies in range.

### Enemies
- 1 type in MVP: `BasicEnemy`
- Spawn from random positions around map edge, default target is Town Center (base)
- **Targeting Priority** (immediate switch to higher priority targets):
  1. Military units (highest priority): Attack if within enemy detection radius (19 units)
  2. Buildings (lower priority): Attack if no military units in range and building is within detection radius
  3. Default: Move to and attack Town Center if no valid targets in range
- Stats: 50 HP, 5 units speed (80px), 10 damage to base per hit, detection radius 19 units (304px)
- Targeting uses `find_best_target()` with `global_position` for distance checks

### Waves
- 10 waves total, each spawns `wave_num` enemies
- Enemies spawn at random edge positions around map edge
- **Timing**:
  - Intra-wave spawn interval: Configurable delay (1s default) between individual enemy spawns in a wave
  - Inter-wave cooldown: Next wave starts immediately after all current wave enemies are dead or reached base (no additional delay)
- Auto-placing units is disabled (`auto_place_units = false` in main.gd)

### Currency (Gold)
- Start with 200 gold
- Kill enemy → +10 gold
- Foot Soldier cost: 50 gold, Archer 75, Cavalry 100
- No passive gold generation (MVP simplification)

## Input Handling
- Unit selection: `is_clicked(event)` with `get_global_mouse_position().distance_to(global_position) < click_radius`
- Left-click: toggle selection, click nothing = deselect all
- Right-click: move selected unit (overrides auto-engage and return-to-base), close pause menu if open
- ESC: toggle pause menu
- Units auto-return to base position when idle (no target, no manual move)

## UI Structure
(UI elements measured in pixels, not grid units)
- `UI/UIRoot`: Top-left HUD (HP bar, gold, wave, unit buttons)
- `UI/SergeantBonus`: Top-right shield icon + label showing active sergeant bonus
- `UI/ActionBar`: Bottom bar (60px), shows selected unit/building name + HP in HBoxContainer with 6 PanelContainers
- `UI/PauseMenu`: Centered popup with dark overlay (pause_mode=2 for PROCESS)
