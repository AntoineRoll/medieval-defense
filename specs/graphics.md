# Graphics

## Art Style
- **Aesthetic**: Minimalist pixel art
- **Color Palette**: Slate, icy blues, muted earth tones
- **Sprite Size**: Multiples of 16x16 pixels (minimum 16x16)
- **Current Adjustment**: Existing 128x132 sergeant sprites must resize to 128x128 (8×16) to comply with grid rules

## Sprites

### Current Sprites
- `infantry_sergeant.png` — Infantry Sergeant unit
- `archery_sergeant.png` — Archery Sergeant unit
- `cavalry_sergeant.png` — Cavalry Sergeant unit
- `grass_1.png` through `grass_16.png` — Grass patch variations (16x16, decorative)
- `rock_1.png` through `rock_16.png` — Rock variations (16x16, decorative)

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
- Snap to 16px grid in editor
- All sprites must be multiples of 16x16 (resize non-compliant assets like 128x132 → 128x128)
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
- **Action Bar**: Bottom bar (60px), 6 PanelContainers
- **Sergeant Bonus Icon**: Shield icon (top-right)
- **Selection Indicator**: Yellow highlight (Color(1, 1, 0, 0.3))
- **HP Bars**: Visible when HP < 100%, auto-shown on damage
- **Detection/Attack Radius**: Yellow (detection) and red (attack) circles via `_draw()` (measured in grid units)
