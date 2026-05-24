# Character sprite sheets

## Alex (`alex.png`)

Place a PNG at **`alex.png`** in this folder (deployed as `assets/characters/alex.png`).

The game expects a **6 column × 6 row** grid of equal-sized cells (no padding between cells). Each row is one animation strip:

| Row | Animation | Frames used (0-based columns) |
|-----|-----------|--------------------------------|
| 0   | Idle      | 0–3 (4 frames) |
| 1   | Walk      | 0–5 |
| 2   | Run       | 0–5 |
| 3   | Jump      | 0–3 |
| 4   | Attack    | 0–2 |
| 5   | Interact  | 0–1 (optional; not driven by gameplay yet) |

If the file is missing or fails to load, Alex falls back to the built-in procedural side-view sprite (same geometry as the **Boy** shape).

**Note:** If your exported sheet includes logos, margins, or a non-uniform grid, either crop the PNG to the grid above or adjust the constants `ALEX_SPRITESHEET_*` near `drawAlexSpritesheetOrProcedural` in `index.html`.
