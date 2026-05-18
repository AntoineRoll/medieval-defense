# Introduction

## Core Concept

- **Genre**: Medieval tower defense with town-building elements
- **Format**: 2D omnidirectional defense (enemies attack from all directions, not lanes)
- **Engine**: Godot 4.6
- **Language**: GDScript (Python-like syntax)
- **Aesthetic**: Minimalist pixel art (slate, icy blues, muted earth tones)

## Project Structure

```
medieval-defense/
├── assets/
│   └── sprites/      # Pixel art source files
├── resources/        # .tres data files (UnitStats, etc.)
├── scenes/           # .tscn files (Godot 4 format=3)
├── scripts/          # .gd files (GDScript)
├── specs/            # Design docs and decisions
└── project.godot     # Godot project config
```

### Autoload Singletons (load order)

- **EventBus** (`scripts/event_bus.gd`): Global typed signal bus for decoupled cross-node communication
- **Constants** (`scripts/systems/constants.gd`): Typed consts for groups, signals, paths
- **GameManager** (`scripts/managers/game_manager.gd`): Game state, gold/wave tracking, sergeant bonuses
- **StateMachine** (`scripts/systems/state_machine.gd`): Typed state machine (TITLE, PLAYING, PAUSED, WON, LOST)
- **InputHandler** (`scripts/systems/input_handler.gd`): Dispatches named input actions (select, reposition, pause, purchase)
- **GridManager** (`scripts/systems/grid_manager.gd`): 64px tile grid (16×9), occupancy tracking, world↔grid conversion, multi-tile support
- **ObjectPool** (`scripts/managers/object_pool.gd`): Entity pooling for enemies/projectiles

## Grid System
- Tile size: 64x64 pixels (1 grid unit = 64px)
- All game sprites/assets must be multiples of 64x64 (minimum size 64x64)
- All game measurements (radii, positions, speeds) specified in grid units
- UI/HUD elements measured in pixels (not grid units)
- Snap all game positions to grid in editor

## Technical Conventions

- `snake_case` for variables/functions, `PascalCase` for classes
- Godot 4.x: `format=3` in .tscn, `process_mode` (not `pause_mode`), `offset_*` (not `margin_*`)
- Signal methods: `_on_infantry_btn_pressed` (lowercase node names)
- Scripts attach to scene nodes (not standalone entrypoints)
- Pixel art: disable texture filtering, snap to 64px grid
- Use `@onready` with typed references instead of fragile `$` path chains
- Prefer `await` over `yield` (deprecated in Godot 4)
- Use `Callable`-based `.connect()` over string-based connections

## Architecture

### Manager Pattern

Game logic is split across focused autoloads rather than a single God-class:

- **EventBus** — All cross-component communication via typed signals
- **Constants** — Typed const references for groups, signals, paths
- **GameManager** — Game state, gold tracking, sergeant bonuses
- **StateMachine** — Typed state machine with enter/exit hooks
- **InputHandler** — Dispatches named input actions (select, reposition, pause, purchase)
- **GridManager** — Tile grid management with multi-tile occupancy (`occupy_rect`, `vacate_entity`), A* grid pathfinding (`find_path()`) on 16x9 grid with building-aware walkability
- **ObjectPool** — Entity pooling for performance
- **WaveManager** (child of Main) — Wave spawning, enemy tracking, inter-wave timing
- **main.gd** (scene root) — Thin coordinator: UI connections, unit placement, input handling

### Data-Driven Units

Unit stats are defined as Resources (`UnitStats` in `scripts/unit_stats.gd`):
- `.tres` files in `resources/` specify HP, speed, damage, cost per unit type
- Subclass scripts (FootSoldier, Archer, Cavalry) load their resource in `_ready()`
- `setup_stats()` legacy API retained for test overrides

## Dev Commands

- Open: `godot4 --editor --path /home/antoine/medieval-defense`
- Run: `godot4 --path /home/antoine/medieval-defense --scene res://scenes/main.tscn`
- Re-import assets: `timeout 10 godot4 --editor --path /home/antoine/medieval-defense`
