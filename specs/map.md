# Map

## Overview
The map is the game world where units, buildings, and enemies exist. It is centered on the player's original Town Center (TC) at world origin (0, 0).

## Current Implementation (MVP)
- **Size**: Fixed map area (1280x720 viewport, centered on Town Center)
- **Terrain**: Tiled grass background with green ColorRect fallback
- **Background** (Implemented):
  - `Grass-pattern_1.png` through `Grass-pattern_5.png` — 64x64 pixel tiling patterns
  - 64x64 grid of randomly-selected grass pattern tiles (4096x4096 px total area)
  - Single centered Sprite2D with `z_index = -10` (behind all game objects) and `texture_filter = NEAREST`
  - Generated at runtime in `map.gd:_ready()` via `Image.blit_rect()`
  - Green `ColorRect` on `BackgroundLayer` (layer -10) as fallback
- **Map Node**: `scenes/map.tscn` with `scripts/map.gd` (visible after sergeant selection)

## Map Rules
- Town Center spawns at center (0, 0)
- Units/buildings placed on open ground
- Enemies spawn at map edges and pathfind toward targets
- All game entities snap to 64px grid
- Decorative items do not affect pathfinding or combat

## Pathfinding
- **Grid-based A***: All movement uses `GridManager.find_path()` which runs A* on the 16×9 tile grid with proper closed-set tracking for optimality
- **Cardinal movement only**: Paths use 4-directional steps (up/down/left/right), no diagonals
- **Building obstacles**: Building-occupied tiles are blocked; pathfinder routes around them
- **Start/end validation**: Both `from` and `to` grid positions are validated; if either is unwalkable, the nearest walkable tile is found via BFS
- **Dynamic recomputation**: Chasing entities recompute path when target changes tile; moving entities compute once per destination
- **Fallback**: If no grid path exists, entities move directly toward target (line-of-sight fallback)
- **Grid occupancy tracking**: `_entity_tiles` cache enables O(1) entity-to-grid lookups; `update_entity_position()` syncs grid occupancy during movement
- **Placement validation**: AABB overlap check (per-axis) for buildings and unit base positions, replacing circular-distance checks
- Pathfinding is purely grid-based via GridManager (NavigationAgent2D removed)

## Future Vision (See roadmap-idea.md)
Ideally, the map should be infinite and procedurally generated, allowing exploration and expansion beyond the initial spawn area.
