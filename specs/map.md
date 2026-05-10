# Map

## Overview
The map is the game world where units, buildings, and enemies exist. It is centered on the player's original Town Center (TC) at world origin (0, 0).

## Current Implementation (MVP)
- **Size**: Fixed map area (640x360 viewport, centered on Town Center)
- **Terrain**: Green background with decorative elements
- **Decorative Items** (Implemented):
  - `grass_1.png` through `grass_16.png` — Grass patch variations (16x16 pixels)
  - `rock_1.png` through `rock_16.png` — Rock variations (16x16 pixels)
  - 50 grass + 30 rocks spawned randomly within 40 units (640px) radius
  - Random sprite variation selected per decoration instance
  - No hitbox/collision
  - No gameplay behavior (purely visual)
  - Sprites are 16x16 pixels (compliant with grid system)
- **Map Node**: `scenes/map.tscn` with `scripts/map.gd` (visible after sergeant selection)

## Map Rules
- Town Center spawns at center (0, 0)
- Units/buildings placed on open ground
- Enemies spawn at map edges and pathfind toward targets
- All game entities snap to 16px grid
- Decorative items do not affect pathfinding or combat

## Future Vision (See roadmap-idea.md)
Ideally, the map should be infinite and procedurally generated, allowing exploration and expansion beyond the initial spawn area.
