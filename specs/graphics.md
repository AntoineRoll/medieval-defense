# Graphics

## Art Style
- **Aesthetic**: Minimalist pixel art
- **Color Palette**: Slate, icy blues, muted earth tones
- **Sprite Size**: Multiples of 64x64 pixels (minimum 64x64)

## Sprites

### Current Sprites (resized to 64×64 tile size)
- `infantry_sergeant.png` — Foot Soldier unit (64×64, 1×1 tile)
- `archery_sergeant.png` — Archer unit (64×64, 1×1 tile)
- `cavalry_sergeant.png` — Cavalry unit (64×64, 1×1 tile)
- `tower_wood.png` — Wood Tower (64×64, 1×1 tile, resized from 128×128)
- `town_center.png` — Town Center (128×128, 2×2 tiles)
- `arrow.png` — Projectile sprite
- `shield.png` — Sergeant bonus shield icon
- `gold_res_128.png` — Gold resource icon (128×128)
- `Grass-pattern_1.png` through `Grass-pattern_5.png` — Grass tiling patterns (64×64, used by map.gd for background generation)

### Sprite Processing
Remove white backgrounds:
```bash
convert sprite.png -fuzz 8% -transparent white sprite.png
```

Remove anti-aliased white edges:
```bash
convert sprite.png -channel A -morphology Erode Diamond:1 sprite.png
```

Check near-white pixels:
```bash
convert sprite.png -format %c histogram:info:- | grep -E "srgba\(25[0-9].*1\)"
```

### Import Settings
- Disable texture filtering per sprite (import flags)
- Snap to 64px grid in editor
- All sprites must be multiples of 64x64
- After updating assets (sprites, textures): delete `.import` files and run `timeout 10 godot --editor --path /home/antoine/medieval-defense` to re-import

## Moodboards
Located in `specs/moodboards/`:
- `evolutions.jpeg` — Evolution/progression visual reference
- `grass_rock.jpeg` — Terrain textures
- `hero_shield.jpeg` — Hero/sergeant shield designs
- `theme.jpeg` — Overall theme and color palette
- `town_center.jpeg` — Town center building reference

## UI Graphics
(UI elements measured in pixels, game entities use grid units)
- **Pause Menu**: Centered popup with dark overlay
- **Action Bar**: Bottom bar (120px), two rows — units (top row) + buildings (bottom row)
- **Sergeant Bonus Icon**: Shield icon (top-right)
- **Selection Indicator**: Yellow highlight (Color(1, 1, 0, 0.3))
- **HP Bars**: Visible when HP < 100%, auto-shown on damage
- **Detection/Attack Radius**: Yellow (detection) and red (attack) tile-grid squares via `_draw_tile_circle()` — Minecraft-style circle drawn as filled 64×64 tiles (measured in grid units)
