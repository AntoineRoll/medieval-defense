# Introduction

## Core Concept

- **Genre**: Medieval tower defense with town-building elements
- **Format**: 2D omnidirectional defense (enemies attack from all directions, not lanes)
- **Engine**: Godot 3.1
- **Language**: GDScript (Python-like syntax)
- **Aesthetic**: Minimalist pixel art (slate, icy blues, muted earth tones)

## Project Structure

```
medieval-defense/
├── assets/
│   └── sprites/      # Pixel art source files
├── scenes/           # .tscn files (Godot 3.1 format=2)
├── scripts/          # .gd files (GDScript)
├── specs/            # Design docs and decisions
└── project.godot     # Godot project config
```

## Grid System
- Tile size: 16x16 pixels (1 grid unit = 16px)
- All game sprites/assets must be multiples of 16x16 (minimum size 16x16)
- All game measurements (radii, positions, speeds) specified in grid units
- UI/HUD elements measured in pixels (not grid units)
- Snap all game positions to grid in editor

## Technical Conventions

- `snake_case` for variables/functions, `PascalCase` for classes
- Godot 3.1: `rect_position` not `position`, `format=2` in .tscn
- Signal methods: `_on_InfantryBtn_pressed` (Godot 3 naming)
- Scripts attach to scene nodes (not standalone entrypoints)
- Pixel art: disable texture filtering, snap to 16px grid
- UI nodes need `pause_mode = 2` to process when game is paused

## Dev Commands

- Open: `godot --editor --path /home/antoine/medieval-defense`
- Run: `godot --path /home/antoine/medieval-defense --scene res://scenes/main.tscn`
- Re-import assets: `timeout 10 godot --editor --path /home/antoine/medieval-defense`
