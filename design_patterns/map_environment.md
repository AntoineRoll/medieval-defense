# Map Environment / Decoration — Godot 4 Research

## References

- Godot 4.6 TileMapLayer docs: `Using TileSets`, `Using TileMaps`
- Godot 4.6 Parallax2D docs: `2D Parallax`, `Parallax2D` class reference
- Godot 4.6 Optimization: `GPU optimization`, `Optimization using MultiMeshes`
- `I Love Sprites` — "Working With Sprites in Godot 4: Nuances, Pitfalls, and Best Practices" (2026), "Reducing Draw Calls with Texture Atlases" (2025)
- `1342Drumbum/game-mechanics-optimizations` — 2D sprite batching reference with real-game benchmarks (Celeste, Dead Cells, Hollow Knight, Terraria, Stardew Valley)
- `TNTGuerrilla/RapidWorldGen` — Godot 4 infinite world gen with FastNoiseLite + smart decoration
- `anonomity/Godot4Tilemaps` — `proc_gen_world.gd` noise-based tile + tree placement
- `udit/poisson-disc-sampling` — GDScript Poisson Disk Sampling (Asset Library)
- `Minoqi` — Poisson Disc Sampling Algorithm in Godot 4 tutorial
- `alex9978/scatter2d` — Godot 4 scatter add-on (Poisson, grid, random, edge placement)
- `statico/godot-roguelike-example` — Dungeon generation with decoration chance tables
- `HungryProton/scatter` — Godot scatter plugin issues (Poisson performance)

---

## Recommended Pattern

For a **medieval-defense 2D game** (top-down, pixel art, 64px grid units):

| Layer | Technique | Why |
|---|---|---|
| Background / Sky / Far terrain | `Parallax2D` (one per depth layer) with tiled `Sprite2D` | Godot 4.3+ recommended over old `ParallaxBackground`/`ParallaxLayer`. Single draw batch per layer with `repeat_size` for infinite scroll. |
| Ground terrain tiles | `TileMapLayer` with `TileSet` atlas | Grid-aligned, massively batchable, supports autotiling/terrain sets. Single draw call for entire visible area. |
| Decorative props (grass, rocks, flowers) — sparse (<500) | Individual `Sprite2D` children of a container `Node2D` | Acceptable at this count. Use `AtlasTexture` pointing to a shared atlas PNG so Godot batches them. Gives full per-instance scripting (sway animation, removal). |
| Decorative props — dense (500–10000) | `MultiMeshInstance2D` with `MultiMesh` + custom shader for UV atlas | GPU-instanced: 1 draw call regardless of instance count. No per-node overhead. Best for static visual-only decoration. Can set `transform_format = Transform2D` and `instance_count` at runtime. |
| Foreground / alpha-blended overlay | `TileMapLayer` (opaque) or `MultiMeshInstance2D` (transparent) | Separate layer for occlusion sorting. |

**Decision flow**: Tile-aligned + needs collision/navigation? → `TileMapLayer`. Free-form placement, <500 items, needs scripting? → `Sprite2D` with atlas. Free-form, 500–10000 items, static visuals? → `MultiMeshInstance2D`.

---

## Implementation Patterns

### A. Procedural Decoration Placement

Three strategies for placing decorations on a tile map, in order of increasing quality:

| Strategy | Description | Best For |
|---|---|---|
| **Per-tile random chance** | After terrain generation, iterate every tile cell. If cell is valid (grass, not water/building), roll `randf() < density`. Place decoration at tile center. | Quick grass tufts, random variation tiles on `TileMapLayer` |
| **Noise-threshold placement** | Use `FastNoiseLite` to get a value at each position. Place decoration only where noise is within a band (e.g., 0.3–0.7). Produces natural-looking clusters. | Trees, bushes, rocks — organic distribution |
| **Poisson Disk Sampling** | Generate sample points with a minimum separation distance. Produces blue-noise distribution: evenly spaced with no overlap. Use for non-grid, free-form placement. | Large rocks, props that must not overlap each other or buildings |

All three share a validation step: check each candidate position against **exclusion zones** (building footprints, path tiles, water, other decorations) before accepting.

### B. Seasonality / Variation (future-proofing)

Store decoration type as an enum or string (e.g., `"grass_tuft_01"`, `"summer_flower"`) in a data structure alongside position. A `DecorationManager` can swap sprites by season/biome without regenerating positions. Use a `Resource` array (`Array[DecorationDef]`) for data-driven variation.

### C. Parallax Background Layers (Parallax2D)

- `scroll_scale`: < 1 for far layers (slow scroll = distant), > 1 for near layers (fast scroll = close), 0 for static sky.
- `repeat_size`: set to sprite pixel width/height. Texture must start at `(0,0)` in local space.
- `repeat_times`: increase when camera zooming out to prevent visible edges.
- Autoscroll (`autoscroll`) for ambient effects (clouds drifting).

### D. Texture Atlas Strategy

- Single PNG atlas (2048×2048 or 4096×4096) containing all decoration sprites.
- Use `AtlasTexture` resources (`.tres`) pointing to atlas + region rect for each decoration variant.
- For `MultiMeshInstance2D`: use a custom shader that reads UV offset from `INSTANCE_CUSTOM` to select the correct atlas region.
- For `Sprite2D`: assign `AtlasTexture` directly or use `region_enabled = true` + `region_rect`.

---

## Code Snippet Examples

### Poisson Disk Sampling for decoration placement
```gdscript
# Returns Array[Vector2] of positions with min_distance separation within bounds
func generate_poisson_positions(bounds: Rect2, min_distance: float, attempts: int = 30) -> Array:
    var rng = RandomNumberGenerator.new()
    var cell_size = min_distance / sqrt(2.0)
    var grid: Dictionary = {}
    var active: Array[Vector2] = []
    var points: Array[Vector2] = []

    var first = Vector2(rng.randf_range(bounds.position.x, bounds.end.x),
                        rng.randf_range(bounds.position.y, bounds.end.y))
    points.append(first)
    active.append(first)
    var grid_coords = Vector2i(floor(first.x / cell_size), floor(first.y / cell_size))
    grid[grid_coords] = first

    while active.size() > 0:
        var idx = rng.randi_range(0, active.size() - 1)
        var point = active[idx]
        var found = false
        for i in attempts:
            var angle = rng.randf() * TAU
            var radius = rng.randf_range(min_distance, min_distance * 2.0)
            var candidate = point + Vector2(cos(angle), sin(angle)) * radius
            if not bounds.has_point(candidate):
                continue
            var gx = int(floor(candidate.x / cell_size))
            var gy = int(floor(candidate.y / cell_size))
            var valid = true
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    var neighbor = grid.get(Vector2i(gx + dx, gy + dy))
                    if neighbor != null and neighbor.distance_squared_to(candidate) < min_distance * min_distance:
                        valid = false
                        break
                if not valid:
                    break
            if valid:
                found = true
                points.append(candidate)
                active.append(candidate)
                grid[Vector2i(gx, gy)] = candidate
                break
        if not found:
            active.remove_at(idx)
    return points
```

### MultiMeshInstance2D with atlas texture regions (custom shader)
```gdscript
# Setup: decoration_multimesh.gd
# Attached to MultiMeshInstance2D node
@export var atlas_texture: Texture2D
@export var sprite_uvs: Array[Rect2]  # UV rects for each decoration variant
@export var density: float = 0.1

func _ready() -> void:
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_2D
    mm.use_colors = false
    mm.custom_data_format = MultiMesh.CUSTOM_DATA_8BIT  # store UV index per instance

    var positions = generate_poisson_positions(place_bounds, 32.0)
    mm.instance_count = positions.size()
    mm.visible_instance_count = positions.size()

    for i in positions.size():
        var t = Transform2D()
        t.origin = positions[i]
        mm.set_instance_transform_2d(i, t)
        var uv_idx = randi() % sprite_uvs.size()
        mm.set_instance_custom_data(i, Color(uv_idx, 0, 0, 0))

    multimesh = mm
    texture = atlas_texture
```
```glsl
// shader for above: selects UV region via custom data
shader_type canvas_item;
uniform vec4 sprite_uvs[64]; // MAX_VARIANTS

void fragment() {
    int idx = int(INSTANCE_CUSTOM.r);
    vec2 uv_origin = sprite_uvs[idx].xy;
    vec2 uv_size = sprite_uvs[idx].zw;
    UV = uv_origin + UV * uv_size;
    COLOR = texture(TEXTURE, UV);
}
```

### Noise-based tile decoration (TileMapLayer)
```gdscript
func place_decorations(terrain_layer: TileMapLayer, decor_layer: TileMapLayer, noise: FastNoiseLite) -> void:
    var grass_tiles: Array[Vector2i] = [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)]
    var used_cells = terrain_layer.get_used_cells()
    for cell in used_cells:
        var world_pos = terrain_layer.map_to_local(cell)
        var noise_val = noise.get_noise_2d(world_pos.x, world_pos.y)
        if noise_val > 0.3 and noise_val < 0.7:
            if randf() < 0.15:
                decor_layer.set_cell(cell, 0, grass_tiles.pick_random())
```

### Parallax2D setup
```gdscript
# Attach to Parallax2D node with Sprite2D child
func _ready() -> void:
    scroll_scale = Vector2(0.3, 0.3)       # slow scroll = far background
    repeat_size = Vector2(512, 0)          # repeat horizontally every 512px
    repeat_times = 3                       # extra repeats for zoom-out safety
    $Sprite2D.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    $Sprite2D.region_enabled = true
    $Sprite2D.region_rect = Rect2(0, 0, 1024, 512)
```

---

## Limitations

- **MultiMeshInstance2D has no per-instance frustum culling.** All instances are drawn or none. Workaround: split the world into grid chunks, each with its own `MultiMeshInstance2D`. Only activate chunks near the camera.
- **MultiMeshInstance2D cannot use `AnimatedSprite2D`** or per-instance scripts. For animated decorations (torches, swaying grass), either: (a) use a small number of `Sprite2D` with shared `AnimationPlayer` tweens, or (b) animate in the vertex shader via `INSTANCE_ID` / custom data.
- **`TileMapLayer.set_cell()` is not free for massive maps during generation.** For a 300×300 grid (90k cells), generation is fine. For 1000×1000+, batch updates by populating an array of `Dictionary` cell data and using `TileMapLayer.set_cells_terrain_connect()` for connected terrain, or disable the `TileMapLayer` during generation and re-enable after.
- **Poisson Disk Sampling in GDScript is single-threaded.** For large areas (spawning radius > 500 units) the initial generation can cause a frame hitch. Pre-generate at scene load or use a loading screen. Consider chunked generation.
- **`AtlasTexture` cannot tile in `Sprite2D.region_rect`** — it needs `region_enabled` directly on the sprite instead.
- **`Parallax2D` repeat snaps the child node position**, not the texture UVs. The child CanvasItem must have its origin at `(0,0)` and the texture must fill from `(0,0)` to `(repeat_size)` for correct looping.
- **`Parallax2D` `repeat_size` does not account for child node scale.** If a sprite is scaled up, manually calculate repeat_size = texture_size * scale.

---

## Alternatives

| Approach | When to use | Trade-off |
|---|---|---|
| **`Scatter2D` add-on** (alex9978/scatter2d) | Prototyping or non-programmer level design. Inspector-driven modifier stack (Random, Poisson, Grid, Edge). | Dependency on third-party plugin. Less control than code. Overkill for simple decoration. |
| **`HungryProton/scatter`** (Godot 3 version, community forks for 4) | Similar to Scatter2D, more mature codebase. | Unstable 4.x support. Heavy. |
| **`GPUParticles2D`** for ambient floating particles (leaves, dust, fireflies) | Animated particle effects that don't need precise placement. | Particles lack collision by default, no persistent per-particle data beyond lifetime/texture. |
| **`TileSet` scene tiles** (place entire scenes as tiles) | Complex interactive decorations (a crackable pot, a harvestable bush). | Each instance is a full scene node — high overhead. Only for sparse, interactive props. |
| **RenderingServer direct draw** (`RenderingServer.canvas_item_create`) | Maximum performance for 100k+ static sprites with custom update loop. | No node tree, no `_process`, manual transform management. Not recommended unless proven necessary by profiling. |
| **Manual sprite atlasing with `Sprite2D.region_rect`** (no `AtlasTexture`) | Quick prototyping, no .tres file management overhead. | Per-Sprite2D region_rect lives in the scene file, not reusable. Harder to maintain across multiple scenes. |
